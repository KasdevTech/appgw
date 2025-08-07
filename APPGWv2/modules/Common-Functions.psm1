# Common Functions Module for Azure Application Gateway v2 Deployment
# File: modules/Common-Functions.psm1

function Write-Log {
    <#
    .SYNOPSIS
    Writes log messages to console and file
    .PARAMETER Message
    The message to log
    .PARAMETER Level
    The log level (Info, Warning, Error)
    .PARAMETER LogFile
    Path to log file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = ""
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with color coding
    switch ($Level) {
        "Info" { Write-Host $logEntry -ForegroundColor Green }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error" { Write-Host $logEntry -ForegroundColor Red }
    }
    
    # Write to log file if specified
    if ($LogFile -ne "") {
        try {
            Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

function Test-AzureConnection {
    <#
    .SYNOPSIS
    Tests Azure PowerShell connection and subscription access with user-friendly output
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Step = "CONN"
    )
    try {
        $context = Get-AzContext
        if ($null -eq $context) {
            $errcode = "$($Step)-001A"
            $errtext = "ERROR $($errcode): No Azure context found. Please run Connect-AzAccount."
            Write-Output "`u{274C} $($errtext)"
            Write-Log $errtext -Level "Error"
            Exit 1
        }
        Write-Output "`u{2705} Connected to Azure Subscription: $($context.Subscription.Name)"
        Write-Log "Connected to Azure Subscription: $($context.Subscription.Name)" -Level "Info"
        return $true
    }
    catch {
        $errcode = "$($Step)-001B"
        $errtext = "ERROR $($errcode): Failed to get Azure context: $($_.Exception.Message)"
        Write-Output "`u{274C} $($errtext)"
        Write-Log $errtext -Level "Error"
        Exit 1
    }
}

function Test-ResourceGroup {
    <#
    .SYNOPSIS
    Tests if a resource group exists with user-friendly output
    .PARAMETER ResourceGroupName
    Name of the resource group
    .PARAMETER Step
    Step or context for error code
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]$Step = "RG"
    )
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -eq $rg) {
            $errcode = "$($Step)-002A"
            $errtext = "ERROR $($errcode): Resource Group '$($ResourceGroupName)' was not found."
            Write-Output "`u{274C} $($errtext)"
            Write-Log $errtext -Level "Error"
            Exit 1
        } else {
            Write-Output "`u{2705} Resource Group '$($ResourceGroupName)' was found."
            Write-Log "Resource Group '$($ResourceGroupName)' was found." -Level "Info"
            return $true
        }
    }
    catch {
        $errcode = "$($Step)-002B"
        $errtext = "ERROR $($errcode): Exception while checking Resource Group: $($_.Exception.Message)"
        Write-Output "`u{274C} $($errtext)"
        Write-Log $errtext -Level "Error"
        Exit 1
    }
}


function Test-VirtualNetwork {
    <#
    .SYNOPSIS
    Tests if a virtual network exists with user-friendly output
    .PARAMETER VNetName
    Name of the virtual network
    .PARAMETER ResourceGroupName
    Name of the resource group
    .PARAMETER Step
    Step or context for error code
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$VNetName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]$Step = "VNET"
    )
    try {
        $vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -eq $vnet) {
            $errcode = "$($Step)-003A"
            $errtext = "ERROR $($errcode): Virtual Network '$($VNetName)' was not found in Resource Group '$($ResourceGroupName)'."
            Write-Output "`u{274C} $($errtext)"
            Write-Log $errtext -Level "Error"
            Exit 1
        } else {
            Write-Output "`u{2705} Virtual Network '$($VNetName)' was found in Resource Group '$($ResourceGroupName)'."
            Write-Log "Virtual Network '$($VNetName)' was found in Resource Group '$($ResourceGroupName)'." -Level "Info"
            return $true
        }
    }
    catch {
        $errcode = "$($Step)-003B"
        $errtext = "ERROR $($errcode): Exception while checking Virtual Network: $($_.Exception.Message)"
        Write-Output "`u{274C} $($errtext)"
        Write-Log $errtext -Level "Error"
        Exit 1
    }
}

function Test-PublicIP {
    <#
    .SYNOPSIS
    Tests if a public IP exists with user-friendly output
    .PARAMETER PublicIPName
    Name of the public IP
    .PARAMETER ResourceGroupName
    Name of the resource group
    .PARAMETER Step
    Step or context for error code
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublicIPName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]$Step = "PIP"
    )
    try {
        $pip = Get-AzPublicIpAddress -Name $PublicIPName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -eq $pip) {
            $errcode = "$($Step)-004A"
            $errtext = "ERROR $($errcode): Public IP '$($PublicIPName)' was not found in Resource Group '$($ResourceGroupName)'."
            Write-Output "`u{274C} $($errtext)"
            Write-Log $errtext -Level "Error"
            Exit 1
        } else {
            Write-Output "`u{2705} Public IP '$($PublicIPName)' was found in Resource Group '$($ResourceGroupName)'."
            Write-Log "Public IP '$($PublicIPName)' was found in Resource Group '$($ResourceGroupName)'." -Level "Info"
            return $true
        }
    }
    catch {
        $errcode = "$($Step)-004B"
        $errtext = "ERROR $($errcode): Exception while checking Public IP: $($_.Exception.Message)"
        Write-Output "`u{274C} $($errtext)"
        Write-Log $errtext -Level "Error"
        Exit 1
    }
}

function Test-ApplicationGateway {
    <#
    .SYNOPSIS
    Tests if an Application Gateway exists with user-friendly output
    .PARAMETER ApplicationGatewayName
    Name of the Application Gateway
    .PARAMETER ResourceGroupName
    Name of the resource group
    .PARAMETER Step
    Step or context for error code
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationGatewayName,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]$Step = "APPGW"
    )
    try {
        $appgw = Get-AzApplicationGateway -Name $ApplicationGatewayName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        if ($null -eq $appgw) {
            $errcode = "$($Step)-005A"
            $errtext = "ERROR $($errcode): Application Gateway '$($ApplicationGatewayName)' was not found in Resource Group '$($ResourceGroupName)'."
            Write-Output "`u{274C} $($errtext)"
            Write-Log $errtext -Level "Error"
            Exit 1
        } else {
            Write-Output "`u{2705} Application Gateway '$($ApplicationGatewayName)' was found in Resource Group '$($ResourceGroupName)'."
            Write-Log "Application Gateway '$($ApplicationGatewayName)' was found in Resource Group '$($ResourceGroupName)'." -Level "Info"
            return $true
        }
    }
    catch {
        $errcode = "$($Step)-005B"
        $errtext = "ERROR $($errcode): Exception while checking Application Gateway: $($_.Exception.Message)"
        Write-Output "`u{274C} $($errtext)"
        Write-Log $errtext -Level "Error"
        Exit 1
    }
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
    Converts PSCustomObject to Hashtable
    .PARAMETER InputObject
    The object to convert
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )
    
    $hashtable = @{}
    
    if ($InputObject -is [PSCustomObject]) {
        $InputObject.PSObject.Properties | ForEach-Object {
            $hashtable[$_.Name] = $_.Value
        }
    }
    elseif ($InputObject -is [hashtable]) {
        return $InputObject
    }
    else {
        throw "Input object must be PSCustomObject or Hashtable"
    }
    
    return $hashtable
}

function Wait-ForResourceDeployment {
    <#
    .SYNOPSIS
    Waits for a resource deployment to complete
    .PARAMETER ResourceName
    Name of the resource
    .PARAMETER ResourceType
    Type of the resource
    .PARAMETER ResourceGroupName
    Name of the resource group
    .PARAMETER TimeoutMinutes
    Timeout in minutes
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceName,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 30
    )
    
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    $deployed = $false
    
    Write-Log "Waiting for $ResourceType '$ResourceName' deployment to complete..." -Level "Info"
    
    while ((Get-Date) -lt $timeout -and -not $deployed) {
        try {
            switch ($ResourceType) {
                "VirtualNetwork" {
                    $resource = Get-AzVirtualNetwork -Name $ResourceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
                }
                "PublicIP" {
                    $resource = Get-AzPublicIpAddress -Name $ResourceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
                }
                "ApplicationGateway" {
                    $resource = Get-AzApplicationGateway -Name $ResourceName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
                }
                default {
                    throw "Unsupported resource type: $ResourceType"
                }
            }
            
            if ($null -ne $resource) {
                if ($resource.ProvisioningState -eq "Succeeded") {
                    $deployed = $true
                    Write-Log "$ResourceType '$ResourceName' deployed successfully" -Level "Info"
                }
                elseif ($resource.ProvisioningState -eq "Failed") {
                    throw "$ResourceType '$ResourceName' deployment failed"
                }
            }
            
            if (-not $deployed) {
                Start-Sleep -Seconds 30
            }
        }
        catch {
            Write-Log "Error checking deployment status: $($_.Exception.Message)" -Level "Warning"
            Start-Sleep -Seconds 30
        }
    }
    
    if (-not $deployed) {
        throw "Timeout waiting for $ResourceType '$ResourceName' deployment"
    }
}

Export-ModuleMember -Function @(
    'Write-Log',
    'Test-AzureConnection',
    'Test-ResourceGroup',
    'Test-VirtualNetwork',
    'Test-PublicIP',
    'Test-ApplicationGateway',
    'ConvertTo-Hashtable',
    'Wait-ForResourceDeployment'
)
