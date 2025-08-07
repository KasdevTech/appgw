# Application Gateway Configuration Module
# File: modules/ApplicationGateway-Config.psm1

Import-Module "$PSScriptRoot\Common-Functions.psm1" -Force

function New-ApplicationGatewayFrontendIPConfiguration {
    <#
    .SYNOPSIS
    Creates frontend IP configuration for Application Gateway (supports public or private IP)
    .PARAMETER FrontendIPConfig
    Frontend IP configuration from config file
    .PARAMETER PublicIP
    Public IP address object (optional)
    .PARAMETER Subnet
    Subnet object for private frontend IP (optional)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FrontendIPConfig,
        [Parameter(Mandatory = $false)]
        [object]$PublicIP,
        [Parameter(Mandatory = $false)]
        [object]$Subnet
    )
    try {
        Write-Log "Creating frontend IP configuration: $($FrontendIPConfig.Name)" -Level "Info"
        if ($PublicIP -and $Subnet) {
            throw "A single frontend IP configuration cannot have both PublicIP and Subnet. Create two separate frontend IP configs for both."
        }
        elseif ($PublicIP) {
            $frontendIPConfig = New-AzApplicationGatewayFrontendIPConfig -Name $FrontendIPConfig.Name -PublicIPAddress $PublicIP
        }
        elseif ($Subnet) {
            $frontendIPConfig = New-AzApplicationGatewayFrontendIPConfig -Name $FrontendIPConfig.Name -Subnet $Subnet
        }
        else {
            throw "Either PublicIP or Subnet must be provided for frontend IP configuration."
        }
        Write-Log "Frontend IP configuration created successfully" -Level "Info"
        return $frontendIPConfig
    }
    catch {
        Write-Log "Failed to create frontend IP configuration: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function New-ApplicationGatewayFrontendPorts {
    <#
    .SYNOPSIS
    Creates frontend port configurations for Application Gateway
    .PARAMETER FrontendPortConfigs
    Frontend port configurations from config file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$FrontendPortConfigs
    )
    
    try {
        Write-Log "Creating frontend port configurations..." -Level "Info"
        $frontendPorts = @()
        
        # Handle single port configuration (nonprod)
        if ($FrontendPortConfigs -is [PSCustomObject]) {
            Write-Log "Creating frontend port: $($FrontendPortConfigs.Name) (Port: $($FrontendPortConfigs.Port))" -Level "Info"
            $frontendPort = New-AzApplicationGatewayFrontendPort -Name $FrontendPortConfigs.Name `
                -Port $FrontendPortConfigs.Port
            $frontendPorts += $frontendPort
        }
        # Handle multiple port configurations (prod)
        else {
            foreach ($portConfig in $FrontendPortConfigs) {
                Write-Log "Creating frontend port: $($portConfig.Name) (Port: $($portConfig.Port))" -Level "Info"
                $frontendPort = New-AzApplicationGatewayFrontendPort -Name $portConfig.Name `
                    -Port $portConfig.Port
                $frontendPorts += $frontendPort
            }
        }
        
        Write-Log "Frontend port configurations created successfully" -Level "Info"
        return $frontendPorts
    }
    catch {
        Write-Log "Failed to create frontend port configurations: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function New-ApplicationGatewayBackendAddressPools {
    <#
    .SYNOPSIS
    Creates backend address pools for Application Gateway
    .PARAMETER BackendPoolConfigs
    Backend pool configurations from config file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$BackendPoolConfigs
    )
    
    try {
        Write-Log "Creating backend address pools..." -Level "Info"
        $backendPools = @()
        
        foreach ($poolConfig in $BackendPoolConfigs) {
            Write-Log "Creating backend pool: $($poolConfig.Name)" -Level "Info"
            
            $backendAddresses = @()
            foreach ($address in $poolConfig.BackendAddresses) {
                if ($address.IpAddress) {
                    $backendAddresses += New-AzApplicationGatewayBackendAddress -IpAddress $address.IpAddress
                }
                elseif ($address.Fqdn) {
                    $backendAddresses += New-AzApplicationGatewayBackendAddress -Fqdn $address.Fqdn
                }
            }
            
            $backendPool = New-AzApplicationGatewayBackendAddressPool -Name $poolConfig.Name `
                -BackendIPAddresses $backendAddresses
            $backendPools += $backendPool
        }
        
        Write-Log "Backend address pools created successfully" -Level "Info"
        return $backendPools
    }
    catch {
        Write-Log "Failed to create backend address pools: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function New-ApplicationGatewayHealthProbes {
    <#
    .SYNOPSIS
    Creates health probes for Application Gateway
    .PARAMETER ProbeConfigs
    Health probe configurations from config file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$ProbeConfigs
    )
    
    try {
        Write-Log "Creating health probes..." -Level "Info"
        $probes = @()
        
        foreach ($probeConfig in $ProbeConfigs) {
            Write-Log "Creating health probe: $($probeConfig.Name)" -Level "Info"
            
            $matchCondition = $null
            if ($probeConfig.Match -and $probeConfig.Match.StatusCodes) {
                $matchCondition = New-AzApplicationGatewayProbeHealthResponseMatch -StatusCode $probeConfig.Match.StatusCodes
            }
            
            $probeParams = @{
                Name = $probeConfig.Name
                Protocol = $probeConfig.Protocol
                HostName = $probeConfig.Host
                Path = $probeConfig.Path
                Interval = $probeConfig.Interval
                Timeout = $probeConfig.Timeout
                UnhealthyThreshold = $probeConfig.UnhealthyThreshold
                MinServers = $probeConfig.MinServers
            }
            
            if ($matchCondition) {
                $probeParams.Match = $matchCondition
            }
            
            $probe = New-AzApplicationGatewayProbeConfig @probeParams
            $probes += $probe
        }
        
        Write-Log "Health probes created successfully" -Level "Info"
        return $probes
    }
    catch {
        Write-Log "Failed to create health probes: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function New-ApplicationGatewayBackendHttpSettings {
    <#
    .SYNOPSIS
    Creates backend HTTP settings for Application Gateway
    .PARAMETER BackendHttpSettingsConfigs
    Backend HTTP settings configurations from config file
    .PARAMETER Probes
    Health probe objects
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$BackendHttpSettingsConfigs,
        
        [Parameter(Mandatory = $true)]
        [array]$Probes
    )
    
    try {
        Write-Log "Creating backend HTTP settings..." -Level "Info"
        $backendHttpSettings = @()
        
        foreach ($settingConfig in $BackendHttpSettingsConfigs) {
            Write-Log "Creating backend HTTP setting: $($settingConfig.Name)" -Level "Info"
            
            $probe = $null
            if ($settingConfig.ProbeConfiguration) {
                $probe = $Probes | Where-Object { $_.Name -eq $settingConfig.ProbeConfiguration }
                if ($null -eq $probe) {
                    Write-Log "Warning: Probe '$($settingConfig.ProbeConfiguration)' not found for backend HTTP setting '$($settingConfig.Name)'" -Level "Warning"
                }
            }
            
            $settingParams = @{
                Name = $settingConfig.Name
                Port = $settingConfig.Port
                Protocol = $settingConfig.Protocol
                CookieBasedAffinity = $settingConfig.CookieBasedAffinity
                RequestTimeout = $settingConfig.RequestTimeout
            }
            
            if ($probe) {
                $settingParams.Probe = $probe
            }
            
            $backendHttpSetting = New-AzApplicationGatewayBackendHttpSetting @settingParams
            $backendHttpSettings += $backendHttpSetting
        }
        
        Write-Log "Backend HTTP settings created successfully" -Level "Info"
        return $backendHttpSettings
    }
    catch {
        Write-Log "Failed to create backend HTTP settings: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function New-ApplicationGatewayHttpListeners {
    <#
    .SYNOPSIS
    Creates HTTP listeners for Application Gateway
    .PARAMETER ListenerConfigs
    HTTP listener configurations from config file
    .PARAMETER FrontendIPConfig
    Frontend IP configuration object
    .PARAMETER FrontendPorts
    Frontend port objects
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$ListenerConfigs,
        
        [Parameter(Mandatory = $true)]
        [object]$FrontendIPConfig,
        
        [Parameter(Mandatory = $true)]
        [array]$FrontendPorts
    )
    
    try {
        Write-Log "Creating HTTP listeners..." -Level "Info"
        $listeners = @()
        
        foreach ($listenerConfig in $ListenerConfigs) {
            Write-Log "Creating HTTP listener: $($listenerConfig.Name)" -Level "Info"
            
            $frontendPort = $FrontendPorts | Where-Object { $_.Name -eq $listenerConfig.FrontendPort }
            if ($null -eq $frontendPort) {
                throw "Frontend port '$($listenerConfig.FrontendPort)' not found for listener '$($listenerConfig.Name)'"
            }
            
            $listenerParams = @{
                Name = $listenerConfig.Name
                FrontendIPConfiguration = $FrontendIPConfig
                FrontendPort = $frontendPort
                Protocol = $listenerConfig.Protocol
            }
            
            if ($listenerConfig.HostName) {
                $listenerParams.HostName = $listenerConfig.HostName
            }
            
            $listener = New-AzApplicationGatewayHttpListener @listenerParams
            $listeners += $listener
        }
        
        Write-Log "HTTP listeners created successfully" -Level "Info"
        return $listeners
    }
    catch {
        Write-Log "Failed to create HTTP listeners: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function New-ApplicationGatewayRequestRoutingRules {
    <#
    .SYNOPSIS
    Creates request routing rules for Application Gateway
    .PARAMETER RuleConfigs
    Request routing rule configurations from config file
    .PARAMETER HttpListeners
    HTTP listener objects
    .PARAMETER BackendAddressPools
    Backend address pool objects
    .PARAMETER BackendHttpSettings
    Backend HTTP settings objects
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$RuleConfigs,
        
        [Parameter(Mandatory = $true)]
        [array]$HttpListeners,
        
        [Parameter(Mandatory = $true)]
        [array]$BackendAddressPools,
        
        [Parameter(Mandatory = $true)]
        [array]$BackendHttpSettings
    )
    
    try {
        Write-Log "Creating request routing rules..." -Level "Info"
        $rules = @()
        
        foreach ($ruleConfig in $RuleConfigs) {
            Write-Log "Creating request routing rule: $($ruleConfig.Name)" -Level "Info"
            
            $httpListener = $HttpListeners | Where-Object { $_.Name -eq $ruleConfig.HttpListener }
            if ($null -eq $httpListener) {
                throw "HTTP listener '$($ruleConfig.HttpListener)' not found for rule '$($ruleConfig.Name)'"
            }
            
            $backendAddressPool = $BackendAddressPools | Where-Object { $_.Name -eq $ruleConfig.BackendAddressPool }
            if ($null -eq $backendAddressPool) {
                throw "Backend address pool '$($ruleConfig.BackendAddressPool)' not found for rule '$($ruleConfig.Name)'"
            }
            
            $backendHttpSetting = $BackendHttpSettings | Where-Object { $_.Name -eq $ruleConfig.BackendHttpSettings }
            if ($null -eq $backendHttpSetting) {
                throw "Backend HTTP settings '$($ruleConfig.BackendHttpSettings)' not found for rule '$($ruleConfig.Name)'"
            }
            
            $ruleParams = @{
                Name = $ruleConfig.Name
                RuleType = $ruleConfig.RuleType
                HttpListener = $httpListener
                BackendAddressPool = $backendAddressPool
                BackendHttpSettings = $backendHttpSetting
            }
            
            if ($ruleConfig.Priority) {
                $ruleParams.Priority = $ruleConfig.Priority
            }
            
            $rule = New-AzApplicationGatewayRequestRoutingRule @ruleParams
            $rules += $rule
        }
        
        Write-Log "Request routing rules created successfully" -Level "Info"
        return $rules
    }
    catch {
        Write-Log "Failed to create request routing rules: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function New-ApplicationGatewaySku {
    <#
    .SYNOPSIS
    Creates SKU configuration for Application Gateway
    .PARAMETER SkuConfig
    SKU configuration from config file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SkuConfig
    )
    
    try {
        Write-Log "Creating Application Gateway SKU configuration..." -Level "Info"
        
        $sku = New-AzApplicationGatewaySku -Name $SkuConfig.Name `
            -Tier $SkuConfig.Tier `
            -Capacity $SkuConfig.Capacity
        
        Write-Log "SKU configuration created successfully" -Level "Info"
        return $sku
    }
    catch {
        Write-Log "Failed to create SKU configuration: $($_.Exception.Message)" -Level "Error"
        throw
    }
}


Export-ModuleMember -Function @(
    'New-ApplicationGatewayFrontendIPConfiguration',
    'New-ApplicationGatewayFrontendPorts',
    'New-ApplicationGatewayBackendAddressPools',
    'New-ApplicationGatewayHealthProbes',
    'New-ApplicationGatewayBackendHttpSettings',
    'New-ApplicationGatewayHttpListeners',
    'New-ApplicationGatewayRequestRoutingRules',
    'New-ApplicationGatewaySku',
    'New-ApplicationGatewayAutoscaleConfiguration'
)
