# Application Gateway Deployment Module
# File: modules/ApplicationGateway-Deployment.psm1

Import-Module "$PSScriptRoot\Common-Functions.psm1" -Force
Import-Module "$PSScriptRoot\Networking.psm1" -Force
Import-Module "$PSScriptRoot\ApplicationGateway-Config.psm1" -Force

function New-ApplicationGatewayDeployment {
    <#
    .SYNOPSIS
    Creates a complete Application Gateway deployment
    .PARAMETER Config
    Configuration object from environment config file
    .PARAMETER LogFile
    Path to log file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = ""
    )
    
    try {
        $startTime = Get-Date
        Write-Log "Starting Application Gateway deployment for environment: $($Config.Environment)" -Level "Info" -LogFile $LogFile
        
        # Test Azure connection
        if (-not (Test-AzureConnection)) {
            throw "Azure connection test failed"
        }
        
        # Convert tags to hashtable
        $tags = ConvertTo-Hashtable -InputObject $Config.Tags

        # Validate existence of required resources
        if (-not (Check-ResourceGroup -ResourceGroupName $Config.ResourceGroup.Name)) {
            Write-Log "Resource group not found: $($Config.ResourceGroup.Name)" -Level "Error" -LogFile $LogFile
            throw "Resource group '$($Config.ResourceGroup.Name)' does not exist."
        }
        if (-not (Check-VirtualNetwork -VNetName $Config.VirtualNetwork.Name -ResourceGroupName $Config.ResourceGroup.Name)) {
            Write-Log "Virtual network not found: $($Config.VirtualNetwork.Name)" -Level "Error" -LogFile $LogFile
            throw "Virtual network '$($Config.VirtualNetwork.Name)' does not exist."
        }
        if (-not (Check-PublicIP -PublicIPName $Config.PublicIP.Name -ResourceGroupName $Config.ResourceGroup.Name)) {
            Write-Log "Public IP not found: $($Config.PublicIP.Name)" -Level "Error" -LogFile $LogFile
            throw "Public IP '$($Config.PublicIP.Name)' does not exist."
        }

        # Get existing resources
        $resourceGroup = Get-AzResourceGroup -Name $Config.ResourceGroup.Name
        $virtualNetwork = Get-AzVirtualNetwork -Name $Config.VirtualNetwork.Name -ResourceGroupName $Config.ResourceGroup.Name
        $gatewaySubnet = Get-ApplicationGatewaySubnet -VirtualNetwork $virtualNetwork -SubnetName $Config.VirtualNetwork.SubnetName
        $publicIP = Get-AzPublicIpAddress -Name $Config.PublicIP.Name -ResourceGroupName $Config.ResourceGroup.Name

        # Validate NSG rules for Application Gateway
        Test-NetworkSecurityGroupRules -SubnetId $gatewaySubnet.Id
        
        # Check if Application Gateway already exists
        if (Test-ApplicationGateway -ApplicationGatewayName $Config.ApplicationGateway.Name -ResourceGroupName $Config.ResourceGroup.Name) {
            Write-Log "Application Gateway already exists: $($Config.ApplicationGateway.Name)" -Level "Warning" -LogFile $LogFile
            $existingAppGw = Get-AzApplicationGateway -Name $Config.ApplicationGateway.Name -ResourceGroupName $Config.ResourceGroup.Name
            Write-Log "Application Gateway deployment completed (existing resource)" -Level "Info" -LogFile $LogFile
            return $existingAppGw
        }
        
        # Create Application Gateway configuration components
        Write-Log "Creating Application Gateway configuration components..." -Level "Info" -LogFile $LogFile
        
        # Frontend IP configuration
        $frontendIPConfig = New-ApplicationGatewayFrontendIPConfiguration -FrontendIPConfig $Config.FrontendIPConfiguration `
            -PublicIP $publicIP
        
        # Frontend ports
        $frontendPorts = New-ApplicationGatewayFrontendPorts -FrontendPortConfigs $Config.FrontendPort
        
        # Backend address pools
        $backendAddressPools = New-ApplicationGatewayBackendAddressPools -BackendPoolConfigs $Config.BackendAddressPools
        
        # Health probes
        $healthProbes = New-ApplicationGatewayHealthProbes -ProbeConfigs $Config.HealthProbes
        
        # Backend HTTP settings
        $backendHttpSettings = New-ApplicationGatewayBackendHttpSettings -BackendHttpSettingsConfigs $Config.BackendHttpSettings `
            -Probes $healthProbes
        
        # HTTP listeners
        $httpListeners = New-ApplicationGatewayHttpListeners -ListenerConfigs $Config.HttpListeners `
            -FrontendIPConfig $frontendIPConfig `
            -FrontendPorts $frontendPorts
        
        # Request routing rules
        $requestRoutingRules = New-ApplicationGatewayRequestRoutingRules -RuleConfigs $Config.RequestRoutingRules `
            -HttpListeners $httpListeners `
            -BackendAddressPools $backendAddressPools `
            -BackendHttpSettings $backendHttpSettings
        
        # SKU configuration
        $sku = New-ApplicationGatewaySku -SkuConfig $Config.ApplicationGateway.Sku
        
        # Autoscale configuration
        $autoscaleConfig = New-ApplicationGatewayAutoscaleConfiguration -AutoscaleConfig $Config.ApplicationGateway.AutoscaleConfiguration
        
        # Create Application Gateway
        Write-Log "Creating Application Gateway: $($Config.ApplicationGateway.Name)" -Level "Info" -LogFile $LogFile
        
        $appGatewayParams = @{
            Name = $Config.ApplicationGateway.Name
            ResourceGroupName = $Config.ResourceGroup.Name
            Location = $Config.ResourceGroup.Location
            BackendAddressPools = $backendAddressPools
            BackendHttpSettingsCollection = $backendHttpSettings
            FrontendIpConfigurations = $frontendIPConfig
            GatewayIpConfigurations = (New-AzApplicationGatewayIPConfiguration -Name "gateway-ip-config" -Subnet $gatewaySubnet)
            FrontendPorts = $frontendPorts
            HttpListeners = $httpListeners
            RequestRoutingRules = $requestRoutingRules
            Sku = $sku
            Tag = $tags
            Probes = $healthProbes
        }
        if ($autoscaleConfig) {
            $appGatewayParams.AutoscaleConfiguration = $autoscaleConfig
        }

        # Diagnostics settings: Only Event Hub supported, disabled by default
        $enableDiagnostics = $false
        $eventHubName = $null
        if ($Config.Diagnostics -and $Config.Diagnostics.EventHubName) {
            $eventHubName = $Config.Diagnostics.EventHubName
            if ($eventHubName -ne "") {
                $enableDiagnostics = $true
            }
        }

        $applicationGateway = New-AzApplicationGateway @appGatewayParams

        # Configure diagnostics if Event Hub is provided
        if ($enableDiagnostics) {
            Write-Log "Enabling diagnostics with Event Hub: $eventHubName" -Level "Info" -LogFile $LogFile
            $diagParams = @{
                ResourceId = $applicationGateway.Id
                WorkspaceId = $null
                EventHubName = $eventHubName
                Enabled = $true
            }
            # Only Event Hub diagnostics supported
            Set-AzDiagnosticSetting -ResourceId $applicationGateway.Id -EventHubName $eventHubName -Enabled $true -Name "AppGwEventHubDiag"
        } else {
            Write-Log "Diagnostics not enabled (Event Hub not specified)" -Level "Info" -LogFile $LogFile
        }

        # Wait for deployment to complete
        Wait-ForResourceDeployment -ResourceName $Config.ApplicationGateway.Name -ResourceType "ApplicationGateway" -ResourceGroupName $Config.ResourceGroup.Name

        $endTime = Get-Date
        $duration = $endTime - $startTime

        Write-Log "Application Gateway deployment completed successfully!" -Level "Info" -LogFile $LogFile
        Write-Log "Deployment duration: $($duration.TotalMinutes.ToString('0.00')) minutes" -Level "Info" -LogFile $LogFile
        Write-Log "Application Gateway Name: $($applicationGateway.Name)" -Level "Info" -LogFile $LogFile
        Write-Log "Frontend IP Address: $($publicIP.IpAddress)" -Level "Info" -LogFile $LogFile

        return $applicationGateway
    }
    catch {
        Write-Log "Application Gateway deployment failed: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "Error" -LogFile $LogFile
        throw
    }
}


function Get-ApplicationGatewayStatus {
    <#
    .SYNOPSIS
    Gets Application Gateway deployment status and health information
    .PARAMETER Config
    Configuration object from environment config file
    .PARAMETER LogFile
    Path to log file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = ""
    )
    
    try {
        Write-Log "Checking Application Gateway status for environment: $($Config.Environment)" -Level "Info" -LogFile $LogFile
        
        # Test Azure connection
        if (-not (Test-AzureConnection)) {
            throw "Azure connection test failed"
        }
        
        if (-not (Test-ApplicationGateway -ApplicationGatewayName $Config.ApplicationGateway.Name -ResourceGroupName $Config.ResourceGroup.Name)) {
            Write-Log "Application Gateway not found: $($Config.ApplicationGateway.Name)" -Level "Warning" -LogFile $LogFile
            return $null
        }
        
        $appGateway = Get-AzApplicationGateway -Name $Config.ApplicationGateway.Name -ResourceGroupName $Config.ResourceGroup.Name
        
        # Get backend health
        $backendHealth = Get-AzApplicationGatewayBackendHealth -ApplicationGateway $appGateway
        
        # Create status report
        $statusReport = @{
            Name = $appGateway.Name
            ResourceGroup = $appGateway.ResourceGroupName
            Location = $appGateway.Location
            ProvisioningState = $appGateway.ProvisioningState
            OperationalState = $appGateway.OperationalState
            FrontendIPAddress = (Get-AzPublicIpAddress -Name $Config.PublicIP.Name -ResourceGroupName $Config.ResourceGroup.Name).IpAddress
            BackendHealth = @()
        }
        
        foreach ($pool in $backendHealth.BackendAddressPools) {
            $poolHealth = @{
                PoolName = $pool.BackendAddressPool.Name
                HealthyServers = ($pool.BackendHttpSettingsCollection.Servers | Where-Object { $_.Health -eq "Healthy" }).Count
                UnhealthyServers = ($pool.BackendHttpSettingsCollection.Servers | Where-Object { $_.Health -ne "Healthy" }).Count
                Servers = @()
            }
            
            foreach ($httpSetting in $pool.BackendHttpSettingsCollection) {
                foreach ($server in $httpSetting.Servers) {
                    $poolHealth.Servers += @{
                        Address = $server.Address
                        Health = $server.Health
                        HttpSetting = $httpSetting.BackendHttpSettings.Name
                    }
                }
            }
            
            $statusReport.BackendHealth += $poolHealth
        }
        
        Write-Log "Application Gateway Status:" -Level "Info" -LogFile $LogFile
        Write-Log "  Name: $($statusReport.Name)" -Level "Info" -LogFile $LogFile
        Write-Log "  Provisioning State: $($statusReport.ProvisioningState)" -Level "Info" -LogFile $LogFile
        Write-Log "  Operational State: $($statusReport.OperationalState)" -Level "Info" -LogFile $LogFile
        Write-Log "  Frontend IP: $($statusReport.FrontendIPAddress)" -Level "Info" -LogFile $LogFile
        
        foreach ($pool in $statusReport.BackendHealth) {
            Write-Log "  Backend Pool '$($pool.PoolName)': $($pool.HealthyServers) healthy, $($pool.UnhealthyServers) unhealthy" -Level "Info" -LogFile $LogFile
        }
        
        return $statusReport
    }
    catch {
        Write-Log "Failed to get Application Gateway status: $($_.Exception.Message)" -Level "Error" -LogFile $LogFile
        throw
    }
}

Export-ModuleMember -Function @(
    'New-ApplicationGatewayDeployment',
    'Get-ApplicationGatewayStatus'
)
