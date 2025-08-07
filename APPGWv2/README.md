# Azure Application Gateway v2 PowerShell Deployment

This repository provides a comprehensive, modular PowerShell solution for deploying Azure Application Gateway v2 with support for multiple environments. The solution follows Azure best practices and provides a clean, maintainable approach to infrastructure deployment.

## Features

- ✅ **Modular Architecture**: Each component is separated into its own module for clarity and reusability
- ✅ **Multi-Environment Support**: Easily manage different environments (nonprod, prod) with separate configuration files
- ✅ **Comprehensive Logging**: Detailed logging to both console and files with different log levels
- ✅ **Error Handling**: Robust error handling and validation throughout the deployment process
- ✅ **Resource Validation**: Checks for existing resources and handles updates appropriately
- ✅ **Health Monitoring**: Built-in health probes and backend health status checking
- ✅ **Autoscaling Support**: Configurable autoscaling for different environments
- ✅ **Best Practices**: Follows Azure Well-Architected Framework principles

## Project Structure

```
APPGWv2/
├── config/                     # Environment configuration files
│   ├── nonprod.json           # Non-production environment configuration
│   └── prod.json              # Production environment configuration
├── modules/                    # PowerShell modules
│   ├── Common-Functions.psm1  # Common utilities and helper functions
│   ├── Networking.psm1        # Virtual network and networking components
│   ├── ApplicationGateway-Config.psm1  # Application Gateway configuration
│   └── ApplicationGateway-Deployment.psm1  # Main deployment logic
├── scripts/                    # Main deployment scripts
│   └── Deploy-ApplicationGateway.ps1  # Main entry point script
├── logs/                       # Log files (created automatically)
└── README.md                   # This documentation
```

## Prerequisites

### Software Requirements

1. **PowerShell 5.1 or later** (PowerShell 7+ recommended)
2. **Azure PowerShell modules**:
   - Az.Accounts
   - Az.Resources
   - Az.Network

### Azure Requirements

1. **Azure Subscription** with sufficient permissions
2. **Resource Group Contributor** or **Owner** role
3. **Network Contributor** role for networking resources

### Installation

The script will automatically install required Azure PowerShell modules if they're not present. Alternatively, you can install them manually:

```powershell
# Install Azure PowerShell modules
Install-Module -Name Az.Accounts -Force -AllowClobber
Install-Module -Name Az.Resources -Force -AllowClobber
Install-Module -Name Az.Network -Force -AllowClobber
```

## Configuration

### Environment Configuration Files

Configuration files are stored in the `config/` directory and use JSON format. Each environment has its own configuration file.

#### Configuration Structure

```json
{
  "Environment": "nonprod",
  "ResourceGroup": {
    "Name": "rg-appgw-nonprod",
    "Location": "East US 2"
  },
  "VirtualNetwork": {
    "Name": "vnet-appgw-nonprod",
    "AddressPrefix": "10.0.0.0/16",
    "SubnetName": "subnet-appgw",
    "SubnetPrefix": "10.0.1.0/24"
  },
  "ApplicationGateway": {
    "Name": "appgw-nonprod",
    "Sku": {
      "Name": "Standard_v2",
      "Tier": "Standard_v2",
      "Capacity": 2
    },
    "AutoscaleConfiguration": {
      "MinCapacity": 1,
      "MaxCapacity": 3
    }
  }
  // ... additional configuration sections
}
```

### Key Configuration Sections

#### 1. Resource Group
- `Name`: Resource group name
- `Location`: Azure region

#### 2. Virtual Network
- `Name`: Virtual network name
- `AddressPrefix`: CIDR block for the VNet
- `SubnetName`: Subnet name for Application Gateway
- `SubnetPrefix`: CIDR block for the subnet

#### 3. Application Gateway
- `Name`: Application Gateway name
- `Sku`: SKU configuration (Name, Tier, Capacity)
- `AutoscaleConfiguration`: Autoscaling settings (optional)

#### 4. Backend Pools
- Array of backend address pools with IP addresses or FQDNs

#### 5. Health Probes
- Custom health probes for backend servers
- Configurable intervals, timeouts, and health checks

#### 6. HTTP Settings
- Backend HTTP settings including protocols, ports, and cookie affinity

#### 7. Listeners
- Frontend listeners with port and protocol configurations

#### 8. Routing Rules
- Request routing rules connecting listeners to backend pools

## Usage

### Authentication

First, connect to your Azure subscription:

```powershell
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

### Basic Deployment

Deploy to non-production environment:

```powershell
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod
```

Deploy to production environment:

```powershell
.\scripts\Deploy-ApplicationGateway.ps1 -Environment prod
```

### Advanced Usage

#### Preview Deployment (WhatIf)

See what would be deployed without actually creating resources:

```powershell
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -WhatIf
```

#### Check Status

Get the current status and health of the Application Gateway:

```powershell
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Status
```

#### Remove Resources

Remove Application Gateway resources (keeps VNet and Resource Group):

```powershell
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Remove
```

Remove entire resource group and all resources:

```powershell
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Remove -RemoveResourceGroup
```

#### Custom Paths

Specify custom configuration and log paths:

```powershell
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -ConfigPath "C:\CustomConfig" -LogPath "C:\CustomLogs"
```

## Logging

The solution provides comprehensive logging:

- **Console Output**: Color-coded messages for different log levels
- **Log Files**: Detailed logs saved to `logs/` directory
- **Timestamps**: All log entries include timestamps
- **Log Levels**: Info, Warning, Error levels for different message types

Log files are named with timestamp: `appgw-deployment-{environment}-{timestamp}.log`

## Error Handling

The solution includes robust error handling:

- **Validation**: Input validation and Azure resource validation
- **Retry Logic**: Automatic retries for transient failures
- **Graceful Failures**: Proper cleanup on deployment failures
- **Detailed Errors**: Comprehensive error messages and stack traces

## Customization

### Adding New Environments

1. Create a new JSON configuration file in the `config/` directory
2. Update the `ValidateSet` parameter in the main script
3. Configure environment-specific settings

### Extending Functionality

The modular structure makes it easy to extend:

- **Add new modules** in the `modules/` directory
- **Extend configuration** by adding new sections to the JSON files
- **Add new actions** by extending the main deployment script

### Custom Health Probes

Configure custom health probes for your applications:

```json
{
  "Name": "custom-health-probe",
  "Protocol": "Http",
  "Host": "127.0.0.1",
  "Path": "/health",
  "Interval": 30,
  "Timeout": 30,
  "UnhealthyThreshold": 3,
  "MinServers": 0,
  "Match": {
    "StatusCodes": ["200-399"]
  }
}
```

## Best Practices

### Security
- Use Azure Key Vault for sensitive configuration
- Implement proper RBAC permissions
- Enable Azure Security Center recommendations

### Performance
- Configure autoscaling based on your traffic patterns
- Use health probes to ensure backend availability
- Monitor Application Gateway metrics

### Cost Optimization
- Use autoscaling to optimize costs
- Choose appropriate SKU for your workload
- Monitor usage and adjust capacity accordingly

### Monitoring
- Enable diagnostic logging
- Set up Azure Monitor alerts
- Use Application Insights for application monitoring

## Troubleshooting

### Common Issues

#### 1. Authentication Errors
```
Error: No Azure context found
Solution: Run Connect-AzAccount and set the correct subscription
```

#### 2. Permission Errors
```
Error: Insufficient permissions to create resources
Solution: Ensure you have Contributor role on the subscription/resource group
```

#### 3. Subnet Size Issues
```
Error: Subnet too small for Application Gateway
Solution: Use at least a /24 subnet for Application Gateway
```

#### 4. Backend Health Issues
```
Error: Backend servers showing as unhealthy
Solution: Check NSG rules, health probe configuration, and backend server status
```

### Debug Mode

Enable verbose logging for troubleshooting:

```powershell
$VerbosePreference = "Continue"
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Verbose
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review the log files for detailed error information
3. Check Azure documentation for Application Gateway v2
4. Open an issue in the repository

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### Version 1.0.0
- Initial release with modular PowerShell deployment
- Support for multiple environments
- Comprehensive logging and error handling
- Health monitoring and status checking
- Autoscaling configuration support
