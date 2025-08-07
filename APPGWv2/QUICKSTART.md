# Quick Start Guide - Azure Application Gateway v2 PowerShell Deployment

This guide will help you quickly deploy Azure Application Gateway v2 using the provided PowerShell solution.

## 🚀 Quick Start (5 minutes)

### Step 1: Prerequisites Check
Run the prerequisites validation script:

```powershell
.\scripts\Test-Prerequisites.ps1 -Environment nonprod
```

If any issues are found, follow the remediation suggestions provided by the script.

### Step 2: Connect to Azure
```powershell
# Connect to Azure
Connect-AzAccount

# Select your subscription
Set-AzContext -SubscriptionId "your-subscription-id"
```

### Step 3: Deploy Application Gateway
```powershell
# Deploy to non-production environment
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod
```

### Step 4: Verify Deployment
```powershell
# Check the status
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Status
```

That's it! Your Application Gateway v2 is now deployed and ready to use.

## 📋 Before You Start

### Required Information
- **Azure Subscription ID**
- **Preferred Azure Region** (default: East US 2)
- **Backend Server IP Addresses** (update in config files)

### What Gets Created
- Resource Group
- Virtual Network with dedicated subnet
- Public IP Address (Static)
- Application Gateway v2 with:
  - Backend pools
  - Health probes
  - HTTP listeners
  - Routing rules
  - Autoscaling (production)

## ⚙️ Configuration

### Customize Backend Servers
Edit the configuration files in the `config/` directory:

**For nonprod environment** (`config/nonprod.json`):
```json
"BackendAddressPools": [
  {
    "Name": "backend-pool-web",
    "BackendAddresses": [
      { "IpAddress": "10.0.2.10" },  // Replace with your server IPs
      { "IpAddress": "10.0.2.11" }
    ]
  }
]
```

**For prod environment** (`config/prod.json`):
```json
"BackendAddressPools": [
  {
    "Name": "backend-pool-web",
    "BackendAddresses": [
      { "IpAddress": "10.1.2.10" },  // Replace with your server IPs
      { "IpAddress": "10.1.2.11" },
      { "IpAddress": "10.1.2.12" }
    ]
  }
]
```

### Customize Health Probes
Update health probe settings for your applications:

```json
"HealthProbes": [
  {
    "Name": "health-probe-web",
    "Protocol": "Http",
    "Host": "127.0.0.1",
    "Path": "/health",        // Change to your health endpoint
    "Interval": 30,
    "Timeout": 30,
    "UnhealthyThreshold": 3
  }
]
```

## 🔍 Common Commands

### Deployment Commands
```powershell
# Preview what will be deployed (dry run)
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -WhatIf

# Deploy to nonprod
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod

# Deploy to production
.\scripts\Deploy-ApplicationGateway.ps1 -Environment prod

# Check deployment status
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Status
```

### Management Commands
```powershell
# Remove Application Gateway (keeps other resources)
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Remove

# Remove entire resource group and all resources
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Remove -RemoveResourceGroup
```

### Troubleshooting Commands
```powershell
# Check prerequisites
.\scripts\Test-Prerequisites.ps1 -Environment all

# Enable verbose logging
$VerbosePreference = "Continue"
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Verbose
```

## 📊 Monitoring Your Deployment

### Check Application Gateway Status
```powershell
# Get detailed status including backend health
.\scripts\Deploy-ApplicationGateway.ps1 -Environment nonprod -Action Status
```

### View Logs
Logs are automatically saved to the `logs/` directory with timestamps:
```
logs/appgw-deployment-nonprod-20240807-143022.log
```

### Azure Portal
After deployment, you can also monitor your Application Gateway in the Azure Portal:
1. Navigate to your Resource Group
2. Click on the Application Gateway resource
3. Check the "Backend health" section

## 🔧 Environment Differences

### Non-Production (nonprod)
- **Autoscaling**: 1-3 instances
- **SKU**: Standard_v2 with 2 base instances
- **Backend Pool**: Single web tier
- **Listeners**: HTTP only (port 80)

### Production (prod)
- **Autoscaling**: 2-10 instances
- **SKU**: Standard_v2 with 3 base instances
- **Backend Pools**: Web and API tiers
- **Listeners**: HTTP (80) and HTTPS (443)
- **Multi-tier architecture**: Separate pools for web and API

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Issue: "No Azure context found"
```powershell
# Solution: Connect to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

#### Issue: "Insufficient permissions"
- Ensure you have **Contributor** role on the subscription or resource group
- Ensure you have **Network Contributor** role

#### Issue: "Backend servers unhealthy"
1. Check Network Security Group rules
2. Verify backend server health endpoints
3. Confirm backend servers are running and accessible

#### Issue: "Deployment takes too long"
- Application Gateway deployment typically takes 10-15 minutes
- Check the logs for progress updates
- Large environments may take up to 30 minutes

### Getting Help
1. Check the detailed README.md file
2. Review log files in the `logs/` directory
3. Use the `-WhatIf` parameter to preview changes
4. Enable verbose logging with `-Verbose`

## 🎯 Next Steps

After successful deployment:

1. **Configure DNS**: Point your domain to the Application Gateway's public IP
2. **SSL Certificates**: Add SSL certificates for HTTPS listeners (production)
3. **Monitoring**: Set up Azure Monitor alerts and dashboards
4. **Security**: Configure Web Application Firewall (WAF) if needed
5. **Backup**: Document your configuration for disaster recovery

## 📞 Support

For issues or questions:
1. Review the comprehensive README.md
2. Check the troubleshooting section above
3. Examine log files for detailed error information
4. Consult Azure Application Gateway documentation

---

**Happy Deploying! 🎉**
