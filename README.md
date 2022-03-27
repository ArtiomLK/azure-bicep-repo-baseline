# Azure Front Door

## Instructions

### Parameter Values

| Name                         | Description                                                   | Value             | Examples                             |
| ---------------------------- | ------------------------------------------------------------- | ----------------- | ------------------------------------ |
| tags                         | Az Resources tags                                             | object            | `{ key: value }`                     |
| fd_n                         | Front Door Name                                               | string [required] |                                      |
| fd_backend_pool_n            | Front Door BackendPool names                                  | string [required] | `backend-pool-app`                   |
| fd_backend_pool_backend_addr | Front Door BackendPool Backends. Must be IPs address or FQDNs | string [required] | `app-service-name.azurewebsites.net` |

### [Reference Examples][1]

## Locally test Azure Bicep Modules

```bash
# Create an Azure Resource Group
az group create \
--name 'rg-azure-bicep-front-door' \
--location 'eastus2' \
--tags project=bicephub env=dev

# Deploy Sample Modules
az deployment group create \
--resource-group 'rg-azure-bicep-front-door' \
--mode Complete \
--template-file examples/examples.bicep
```

[1]: ./examples/examples.bicep
