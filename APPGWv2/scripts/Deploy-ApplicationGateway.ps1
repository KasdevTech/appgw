# Azure Application Gateway v2 Deployment Script
# File: scripts/Deploy-ApplicationGateway.ps1

<#
.SYNOPSIS
Deploys Azure Application Gateway v2 using modular PowerShell approach

.DESCRIPTION
This script deploys Azure Application Gateway v2 with support for multiple environments.
It uses a modular approach where each configuration section is defined separately for clarity and reusability.

.PARAMETER Environment
The target environment (nonprod, prod)

.PARAMETER ConfigPath
Path to the configuration directory (optional, defaults to ../config)

.PARAMETER LogPath
Path to the log directory (optional, defaults to ../logs)

.PARAMETER Action
Action to perform: Deploy, Status (default: Deploy)

.PARAMETER WhatIf
Show what would be deployed without actually deploying

.EXAMPLE
.\Deploy-ApplicationGateway.ps1 -Environment nonprod

.EXAMPLE
.\Deploy-ApplicationGateway.ps1 -Environment prod -Action Deploy

.EXAMPLE
.\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Status

.EXAMPLE
.\Deploy-ApplicationGateway.ps1 -Environment nonprod -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("nonprod", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Deploy", "Status")]
    [string]$Action = "Deploy",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Get script directory and set paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

if ([string]::IsNullOrEmpty($ConfigPath)) {
    $ConfigPath = Join-Path $rootDir "config"
}

if ([string]::IsNullOrEmpty($LogPath)) {
    $LogPath = Join-Path $rootDir "logs"
}

$modulePath = Join-Path $rootDir "modules"

# Ensure log directory exists
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Set up logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $LogPath "appgw-deployment-$Environment-$timestamp.log"

# Import required modules
try {
    Write-Host "Loading PowerShell modules..." -ForegroundColor Cyan
    
    # Import Azure PowerShell modules
    $azModules = @('Az.Accounts', 'Az.Resources', 'Az.Network')
    foreach ($module in $azModules) {
        if (-not (Get-Module -Name $module -ListAvailable)) {
            Write-Host "Installing Azure PowerShell module: $module" -ForegroundColor Yellow
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
        }
        Import-Module -Name $module -Force
    }
    
    # Import custom modules
    $customModules = @(
        'Common-Functions.psm1',
        'Networking.psm1',
        'ApplicationGateway-Config.psm1',
        'ApplicationGateway-Deployment.psm1'
    )
    
    foreach ($module in $customModules) {
        $modulePath = Join-Path $modulePath $module
        if (Test-Path $modulePath) {
            Import-Module $modulePath -Force
        }
        else {
            throw "Required module not found: $modulePath"
        }
    }
    
    Write-Host "All modules loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load required modules: $($_.Exception.Message)"
    exit 1
}

# Main execution
try {
    Write-Log "=== Azure Application Gateway v2 Deployment ===" -Level "Info" -LogFile $logFile
    Write-Log "Environment: $Environment" -Level "Info" -LogFile $logFile
    Write-Log "Action: $Action" -Level "Info" -LogFile $logFile
    Write-Log "Config Path: $ConfigPath" -Level "Info" -LogFile $logFile
    Write-Log "Log File: $logFile" -Level "Info" -LogFile $logFile
    
    if ($WhatIf) {
        Write-Log "WhatIf mode enabled - no actual deployment will occur" -Level "Info" -LogFile $logFile
    }
    
    # Load configuration
    $configFile = Join-Path $ConfigPath "$Environment.json"
    if (-not (Test-Path $configFile)) {
        throw "Configuration file not found: $configFile"
    }
    
    Write-Log "Loading configuration from: $configFile" -Level "Info" -LogFile $logFile
    $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
    
    # Validate configuration
    if ($config.Environment -ne $Environment) {
        Write-Log "Warning: Configuration environment '$($config.Environment)' does not match specified environment '$Environment'" -Level "Warning" -LogFile $logFile
    }
    
    # Test Azure connection
    if (-not (Test-AzureConnection)) {
        Write-Log "Please connect to Azure first using Connect-AzAccount" -Level "Error" -LogFile $logFile
        exit 1
    }
    
    # Execute action
    switch ($Action) {
        "Deploy" {
            if ($WhatIf) {
                Write-Log "WhatIf: Would deploy Application Gateway with the following configuration:" -Level "Info" -LogFile $logFile
                Write-Log "  Resource Group: $($config.ResourceGroup.Name) in $($config.ResourceGroup.Location)" -Level "Info" -LogFile $logFile
                Write-Log "  Virtual Network: $($config.VirtualNetwork.Name) ($($config.VirtualNetwork.AddressPrefix))" -Level "Info" -LogFile $logFile
                Write-Log "  Application Gateway: $($config.ApplicationGateway.Name)" -Level "Info" -LogFile $logFile
                Write-Log "  SKU: $($config.ApplicationGateway.Sku.Name) ($($config.ApplicationGateway.Sku.Tier))" -Level "Info" -LogFile $logFile
                Write-Log "  Backend Pools: $($config.BackendAddressPools.Count)" -Level "Info" -LogFile $logFile
                Write-Log "  Listeners: $($config.HttpListeners.Count)" -Level "Info" -LogFile $logFile
                Write-Log "  Rules: $($config.RequestRoutingRules.Count)" -Level "Info" -LogFile $logFile
            }
            else {
                $result = New-ApplicationGatewayDeployment -Config $config -LogFile $logFile
                Write-Log "Deployment completed successfully!" -Level "Info" -LogFile $logFile
                
                # Display summary
                Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
                Write-Host "Environment: $Environment" -ForegroundColor White
                Write-Host "Application Gateway: $($result.Name)" -ForegroundColor White
                Write-Host "Resource Group: $($result.ResourceGroupName)" -ForegroundColor White
                Write-Host "Location: $($result.Location)" -ForegroundColor White
                Write-Host "Provisioning State: $($result.ProvisioningState)" -ForegroundColor White
                Write-Host "Log File: $logFile" -ForegroundColor White
            }
        }
        
        # Remove action removed; only Deploy and Status are supported
        "Status" {
            $status = Get-ApplicationGatewayStatus -Config $config -LogFile $logFile
            if ($null -ne $status) {
                Write-Host "`n=== Application Gateway Status ===" -ForegroundColor Cyan
                Write-Host "Name: $($status.Name)" -ForegroundColor White
                Write-Host "Resource Group: $($status.ResourceGroup)" -ForegroundColor White
                Write-Host "Location: $($status.Location)" -ForegroundColor White
                Write-Host "Provisioning State: $($status.ProvisioningState)" -ForegroundColor White
                Write-Host "Operational State: $($status.OperationalState)" -ForegroundColor White
                Write-Host "Frontend IP: $($status.FrontendIPAddress)" -ForegroundColor White
                
                Write-Host "`nBackend Health:" -ForegroundColor Cyan
                foreach ($pool in $status.BackendHealth) {
                    $healthColor = if ($pool.UnhealthyServers -eq 0) { "Green" } else { "Red" }
                    Write-Host "  $($pool.PoolName): $($pool.HealthyServers) healthy, $($pool.UnhealthyServers) unhealthy" -ForegroundColor $healthColor
                    
                    foreach ($server in $pool.Servers) {
                        $serverColor = if ($server.Health -eq "Healthy") { "Green" } else { "Red" }
                        Write-Host "    $($server.Address): $($server.Health)" -ForegroundColor $serverColor
                    }
                }
            }
            else {
                Write-Host "Application Gateway not found or not deployed" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Log "Script execution completed successfully" -Level "Info" -LogFile $logFile
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" -Level "Error" -LogFile $logFile
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "Error" -LogFile $logFile
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    Write-Host "`nLog file saved to: $logFile" -ForegroundColor Gray
}
