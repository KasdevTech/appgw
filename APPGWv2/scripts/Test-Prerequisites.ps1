# Environment Validation Script for Azure Application Gateway v2 Deployment
# File: scripts/Test-Prerequisites.ps1

<#
.SYNOPSIS
Validates prerequisites and environment setup for Azure Application Gateway v2 deployment

.DESCRIPTION
This script checks all prerequisites required for deploying Azure Application Gateway v2,
including PowerShell modules, Azure connectivity, permissions, and configuration files.

.PARAMETER Environment
The target environment to validate (nonprod, prod, all)

.PARAMETER ConfigPath
Path to the configuration directory (optional, defaults to ../config)

.PARAMETER SkipAzureValidation
Skip Azure connectivity and permission validation

.EXAMPLE
.\Test-Prerequisites.ps1 -Environment nonprod

.EXAMPLE
.\Test-Prerequisites.ps1 -Environment all

.EXAMPLE
.\Test-Prerequisites.ps1 -Environment prod -SkipAzureValidation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("nonprod", "prod", "all")]
    [string]$Environment = "all",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAzureValidation
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# Get script directory and set paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

if ([string]::IsNullOrEmpty($ConfigPath)) {
    $ConfigPath = Join-Path $rootDir "config"
}

$modulePath = Join-Path $rootDir "modules"

# Validation results
$validationResults = @{
    PowerShellVersion = @{ Status = "Unknown"; Details = "" }
    AzureModules = @{ Status = "Unknown"; Details = "" }
    CustomModules = @{ Status = "Unknown"; Details = "" }
    ConfigurationFiles = @{ Status = "Unknown"; Details = "" }
    AzureConnectivity = @{ Status = "Unknown"; Details = "" }
    AzurePermissions = @{ Status = "Unknown"; Details = "" }
    OverallStatus = "Unknown"
}

function Write-ValidationResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Details
    )
    
    $statusColor = switch ($Status) {
        "Pass" { "Green" }
        "Fail" { "Red" }
        "Warning" { "Yellow" }
        default { "Gray" }
    }
    
    Write-Host "[$Status]" -ForegroundColor $statusColor -NoNewline
    Write-Host " $TestName" -ForegroundColor White
    if ($Details) {
        Write-Host "       $Details" -ForegroundColor Gray
    }
}

function Test-PowerShellVersion {
    try {
        $version = $PSVersionTable.PSVersion
        $validationResults.PowerShellVersion.Details = "Version: $version"
        
        if ($version.Major -ge 5) {
            $validationResults.PowerShellVersion.Status = "Pass"
        }
        else {
            $validationResults.PowerShellVersion.Status = "Fail"
            $validationResults.PowerShellVersion.Details += " (Minimum version 5.1 required)"
        }
    }
    catch {
        $validationResults.PowerShellVersion.Status = "Fail"
        $validationResults.PowerShellVersion.Details = "Failed to get PowerShell version"
    }
    
    Write-ValidationResult -TestName "PowerShell Version" -Status $validationResults.PowerShellVersion.Status -Details $validationResults.PowerShellVersion.Details
}

function Test-AzureModules {
    $requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.Network')
    $missingModules = @()
    $installedModules = @()
    
    foreach ($module in $requiredModules) {
        try {
            $installedModule = Get-Module -Name $module -ListAvailable | Select-Object -First 1
            if ($installedModule) {
                $installedModules += "$module ($($installedModule.Version))"
            }
            else {
                $missingModules += $module
            }
        }
        catch {
            $missingModules += $module
        }
    }
    
    if ($missingModules.Count -eq 0) {
        $validationResults.AzureModules.Status = "Pass"
        $validationResults.AzureModules.Details = "All required modules installed: $($installedModules -join ', ')"
    }
    else {
        $validationResults.AzureModules.Status = "Fail"
        $validationResults.AzureModules.Details = "Missing modules: $($missingModules -join ', '). Run: Install-Module -Name Az -Force"
    }
    
    Write-ValidationResult -TestName "Azure PowerShell Modules" -Status $validationResults.AzureModules.Status -Details $validationResults.AzureModules.Details
}

function Test-CustomModules {
    $requiredModules = @(
        'Common-Functions.psm1',
        'Networking.psm1',
        'ApplicationGateway-Config.psm1',
        'ApplicationGateway-Deployment.psm1'
    )
    
    $missingModules = @()
    $foundModules = @()
    
    foreach ($module in $requiredModules) {
        $modulePath = Join-Path $modulePath $module
        if (Test-Path $modulePath) {
            $foundModules += $module
        }
        else {
            $missingModules += $module
        }
    }
    
    if ($missingModules.Count -eq 0) {
        $validationResults.CustomModules.Status = "Pass"
        $validationResults.CustomModules.Details = "All custom modules found: $($foundModules -join ', ')"
    }
    else {
        $validationResults.CustomModules.Status = "Fail"
        $validationResults.CustomModules.Details = "Missing modules: $($missingModules -join ', ')"
    }
    
    Write-ValidationResult -TestName "Custom PowerShell Modules" -Status $validationResults.CustomModules.Status -Details $validationResults.CustomModules.Details
}

function Test-ConfigurationFiles {
    $environments = if ($Environment -eq "all") { @("nonprod", "prod") } else { @($Environment) }
    $missingConfigs = @()
    $foundConfigs = @()
    $invalidConfigs = @()
    
    foreach ($env in $environments) {
        $configFile = Join-Path $ConfigPath "$env.json"
        
        if (Test-Path $configFile) {
            try {
                $config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
                
                # Validate required properties
                $requiredProperties = @('Environment', 'ResourceGroup', 'VirtualNetwork', 'ApplicationGateway', 'PublicIP')
                $missingProperties = @()
                
                foreach ($prop in $requiredProperties) {
                    if (-not $config.PSObject.Properties[$prop]) {
                        $missingProperties += $prop
                    }
                }
                
                if ($missingProperties.Count -eq 0) {
                    $foundConfigs += "$env.json"
                }
                else {
                    $invalidConfigs += "$env.json (missing: $($missingProperties -join ', '))"
                }
            }
            catch {
                $invalidConfigs += "$env.json (invalid JSON)"
            }
        }
        else {
            $missingConfigs += "$env.json"
        }
    }
    
    if ($missingConfigs.Count -eq 0 -and $invalidConfigs.Count -eq 0) {
        $validationResults.ConfigurationFiles.Status = "Pass"
        $validationResults.ConfigurationFiles.Details = "Valid configuration files: $($foundConfigs -join ', ')"
    }
    elseif ($missingConfigs.Count -gt 0) {
        $validationResults.ConfigurationFiles.Status = "Fail"
        $validationResults.ConfigurationFiles.Details = "Missing configuration files: $($missingConfigs -join ', ')"
    }
    else {
        $validationResults.ConfigurationFiles.Status = "Fail"
        $validationResults.ConfigurationFiles.Details = "Invalid configuration files: $($invalidConfigs -join ', ')"
    }
    
    Write-ValidationResult -TestName "Configuration Files" -Status $validationResults.ConfigurationFiles.Status -Details $validationResults.ConfigurationFiles.Details
}

function Test-AzureConnectivity {
    if ($SkipAzureValidation) {
        $validationResults.AzureConnectivity.Status = "Skipped"
        $validationResults.AzureConnectivity.Details = "Azure validation skipped by user"
        Write-ValidationResult -TestName "Azure Connectivity" -Status $validationResults.AzureConnectivity.Status -Details $validationResults.AzureConnectivity.Details
        return
    }
    
    try {
        $context = Get-AzContext
        if ($null -eq $context) {
            $validationResults.AzureConnectivity.Status = "Fail"
            $validationResults.AzureConnectivity.Details = "Not connected to Azure. Run: Connect-AzAccount"
        }
        else {
            $validationResults.AzureConnectivity.Status = "Pass"
            $validationResults.AzureConnectivity.Details = "Connected to subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
        }
    }
    catch {
        $validationResults.AzureConnectivity.Status = "Fail"
        $validationResults.AzureConnectivity.Details = "Azure PowerShell not loaded or connection failed"
    }
    
    Write-ValidationResult -TestName "Azure Connectivity" -Status $validationResults.AzureConnectivity.Status -Details $validationResults.AzureConnectivity.Details
}

function Test-AzurePermissions {
    if ($SkipAzureValidation -or $validationResults.AzureConnectivity.Status -ne "Pass") {
        $validationResults.AzurePermissions.Status = "Skipped"
        $validationResults.AzurePermissions.Details = "Skipped due to Azure connectivity issues"
        Write-ValidationResult -TestName "Azure Permissions" -Status $validationResults.AzurePermissions.Status -Details $validationResults.AzurePermissions.Details
        return
    }
    
    try {
        # Test permissions by trying to list resource groups
        $resourceGroups = Get-AzResourceGroup -ErrorAction Stop
        
        # Test ability to create resources (dry run)
        $testLocation = "East US 2"
        $testResult = Test-AzDeployment -Location $testLocation -TemplateBody @"
{
    "`$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "resources": []
}
"@ -ErrorAction Stop
        
        $validationResults.AzurePermissions.Status = "Pass"
        $validationResults.AzurePermissions.Details = "Sufficient permissions to create Azure resources"
    }
    catch {
        $validationResults.AzurePermissions.Status = "Fail"
        $validationResults.AzurePermissions.Details = "Insufficient permissions: $($_.Exception.Message)"
    }
    
    Write-ValidationResult -TestName "Azure Permissions" -Status $validationResults.AzurePermissions.Status -Details $validationResults.AzurePermissions.Details
}

function Get-OverallStatus {
    $failedTests = @()
    $warningTests = @()
    
    foreach ($test in $validationResults.Keys) {
        if ($test -eq "OverallStatus") { continue }
        
        switch ($validationResults[$test].Status) {
            "Fail" { $failedTests += $test }
            "Warning" { $warningTests += $test }
        }
    }
    
    if ($failedTests.Count -eq 0) {
        if ($warningTests.Count -eq 0) {
            $validationResults.OverallStatus = "Pass"
        }
        else {
            $validationResults.OverallStatus = "Warning"
        }
    }
    else {
        $validationResults.OverallStatus = "Fail"
    }
}

# Main execution
Write-Host "=== Azure Application Gateway v2 Prerequisites Validation ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "Config Path: $ConfigPath" -ForegroundColor White
Write-Host ""

# Run all validation tests
Test-PowerShellVersion
Test-AzureModules
Test-CustomModules
Test-ConfigurationFiles
Test-AzureConnectivity
Test-AzurePermissions

# Calculate overall status
Get-OverallStatus

# Display summary
Write-Host ""
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan

$summaryColor = switch ($validationResults.OverallStatus) {
    "Pass" { "Green" }
    "Warning" { "Yellow" }
    "Fail" { "Red" }
    default { "Gray" }
}

Write-Host "Overall Status: " -NoNewline -ForegroundColor White
Write-Host $validationResults.OverallStatus -ForegroundColor $summaryColor

if ($validationResults.OverallStatus -eq "Pass") {
    Write-Host ""
    Write-Host "✅ All prerequisites validated successfully!" -ForegroundColor Green
    Write-Host "You can proceed with the Application Gateway deployment." -ForegroundColor Green
}
elseif ($validationResults.OverallStatus -eq "Warning") {
    Write-Host ""
    Write-Host "⚠️  Some warnings were found, but deployment should still work." -ForegroundColor Yellow
    Write-Host "Review the warnings above and proceed with caution." -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "❌ Prerequisites validation failed!" -ForegroundColor Red
    Write-Host "Please resolve the issues above before proceeding with deployment." -ForegroundColor Red
    
    # Provide remediation suggestions
    Write-Host ""
    Write-Host "=== Remediation Suggestions ===" -ForegroundColor Cyan
    
    if ($validationResults.AzureModules.Status -eq "Fail") {
        Write-Host "• Install Azure PowerShell modules:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name Az -Force -AllowClobber" -ForegroundColor Gray
    }
    
    if ($validationResults.AzureConnectivity.Status -eq "Fail") {
        Write-Host "• Connect to Azure:" -ForegroundColor Yellow
        Write-Host "  Connect-AzAccount" -ForegroundColor Gray
        Write-Host "  Set-AzContext -SubscriptionId 'your-subscription-id'" -ForegroundColor Gray
    }
    
    if ($validationResults.AzurePermissions.Status -eq "Fail") {
        Write-Host "• Ensure you have appropriate Azure permissions:" -ForegroundColor Yellow
        Write-Host "  - Contributor role on the subscription or resource group" -ForegroundColor Gray
        Write-Host "  - Network Contributor role for networking resources" -ForegroundColor Gray
    }
    
    if ($validationResults.ConfigurationFiles.Status -eq "Fail") {
        Write-Host "• Verify configuration files exist and are valid JSON" -ForegroundColor Yellow
        Write-Host "  Check files in: $ConfigPath" -ForegroundColor Gray
    }
}

Write-Host ""

# Exit with appropriate code
switch ($validationResults.OverallStatus) {
    "Pass" { exit 0 }
    "Warning" { exit 0 }
    "Fail" { exit 1 }
    default { exit 1 }
}
