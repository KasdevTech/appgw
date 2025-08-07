# Networking Module for Azure Application Gateway v2 Deployment
# File: modules/Networking.psm1

Import-Module "$PSScriptRoot\Common-Functions.psm1" -Force

function Validate-VirtualNetworkConfiguration {
    <#
    .SYNOPSIS
    Validates the existence of the specified virtual network and subnet for Application Gateway
    .PARAMETER VNetConfig
    Virtual Network configuration from config file
    .PARAMETER ResourceGroupName
    Name of the resource group
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$VNetConfig,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    try {
        Write-Log "Validating virtual network and subnet existence..." -Level "Info"
        if (-not (Test-VirtualNetwork -VNetName $VNetConfig.Name -ResourceGroupName $ResourceGroupName)) {
            throw "Virtual network '$($VNetConfig.Name)' does not exist in resource group '$ResourceGroupName'."
        }
        $vnet = Get-AzVirtualNetwork -Name $VNetConfig.Name -ResourceGroupName $ResourceGroupName
        $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $VNetConfig.SubnetName }
        if ($null -eq $subnet) {
            throw "Subnet '$($VNetConfig.SubnetName)' does not exist in virtual network '$($VNetConfig.Name)'."
        }
        Write-Log "Virtual network and subnet validated: $($VNetConfig.Name) / $($VNetConfig.SubnetName)" -Level "Info"
        return $vnet
    }
    catch {
        Write-Log "Failed to validate virtual network or subnet: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Validate-PublicIPConfiguration {
    <#
    .SYNOPSIS
    Validates the existence of the specified public IP address for Application Gateway
    .PARAMETER PublicIPConfig
    Public IP configuration from config file
    .PARAMETER ResourceGroupName
    Name of the resource group
    #>
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PublicIPConfig,
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    try {
        Write-Log "Validating public IP existence..." -Level "Info"
        if (-not (Test-PublicIP -PublicIPName $PublicIPConfig.Name -ResourceGroupName $ResourceGroupName)) {
            throw "Public IP '$($PublicIPConfig.Name)' does not exist in resource group '$ResourceGroupName'."
        }
        $publicIP = Get-AzPublicIpAddress -Name $PublicIPConfig.Name -ResourceGroupName $ResourceGroupName
        Write-Log "Public IP validated: $($PublicIPConfig.Name)" -Level "Info"
        return $publicIP
    }
    catch {
        Write-Log "Failed to validate public IP: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Get-ApplicationGatewaySubnet {
    <#
    .SYNOPSIS
    Gets the Application Gateway subnet from virtual network
    .PARAMETER VirtualNetwork
    Virtual network object
    .PARAMETER SubnetName
    Name of the subnet
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$VirtualNetwork,
        
        [Parameter(Mandatory = $true)]
        [string]$SubnetName
    )
    
    try {
        $subnet = $VirtualNetwork.Subnets | Where-Object { $_.Name -eq $SubnetName }
        if ($null -eq $subnet) {
            throw "Subnet '$SubnetName' not found in virtual network '$($VirtualNetwork.Name)'"
        }
        
        Write-Log "Found Application Gateway subnet: $SubnetName" -Level "Info"
        return $subnet
    }
    catch {
        Write-Log "Failed to get Application Gateway subnet: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Test-NetworkSecurityGroupRules {
    <#
    .SYNOPSIS
    Validates Network Security Group rules for Application Gateway
    .PARAMETER SubnetId
    Subnet ID to check NSG rules
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubnetId
    )
    
    try {
        Write-Log "Checking Network Security Group rules for Application Gateway..." -Level "Info"
        
        # Get subnet information
        $subnet = Get-AzResource -ResourceId $SubnetId
        if ($null -eq $subnet) {
            Write-Log "Could not find subnet with ID: $SubnetId" -Level "Warning"
            return $false
        }
        
        # Check if NSG is associated with subnet
        $subnetConfig = Get-AzVirtualNetworkSubnetConfig -ResourceId $SubnetId
        if ($null -ne $subnetConfig.NetworkSecurityGroup) {
            $nsgId = $subnetConfig.NetworkSecurityGroup.Id
            $nsg = Get-AzNetworkSecurityGroup -ResourceId $nsgId
            
            # Check for required Application Gateway rules
            $requiredPorts = @(65200, 65201, 65202, 65203, 65204, 65205, 65206, 65207, 65208, 65209, 65210, 65211, 65212, 65213, 65214, 65215, 65216, 65217, 65218, 65219, 65220, 65221, 65222, 65223, 65224, 65225, 65226, 65227, 65228, 65229, 65230, 65231, 65232, 65233, 65234, 65235)
            
            $hasGatewayManagerRule = $nsg.SecurityRules | Where-Object {
                $_.SourceAddressPrefix -eq "GatewayManager" -and
                $_.Access -eq "Allow" -and
                $_.Direction -eq "Inbound"
            }
            
            if ($null -eq $hasGatewayManagerRule) {
                Write-Log "NSG is missing required GatewayManager inbound rule" -Level "Warning"
                return $false
            }
        }
        
        Write-Log "Network Security Group configuration validated" -Level "Info"
        return $true
    }
    catch {
        Write-Log "Failed to validate NSG rules: $($_.Exception.Message)" -Level "Warning"
        return $false
    }
}

Export-ModuleMember -Function @(
    'Validate-VirtualNetworkConfiguration',
    'Validate-PublicIPConfiguration',
    'Get-ApplicationGatewaySubnet',
    'Test-NetworkSecurityGroupRules'
)
