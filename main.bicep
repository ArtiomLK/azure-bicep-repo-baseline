// ------------------------------------------------------------------------------------------------
// Deployment parameters
// ------------------------------------------------------------------------------------------------
@description('Az Resources tags')
param tags object = {}
@description('Az Resources deployment location')
param location string

// ------------------------------------------------------------------------------------------------
// Application parameters
// ------------------------------------------------------------------------------------------------
@description('App Service Names separated by commas. For example: applicationA | applicationA,applicationB | applicationA,applicationB,applicationC')
param app_names string
var app_names_parsed = split(app_names, ',')

@description('App Service Plan resource ID')
param plan_ids string
var plan_id_parsed = split(plan_ids, ',')

@description('Enable only HTTPS traffic through App Service')
param app_enable_https_only string
var app_enable_https_only_parsed = split(app_enable_https_only, ',')

// ------------------------------------------------------------------------------------------------
// Application Topology parameters
// ------------------------------------------------------------------------------------------------
@description('Enable only HTTPS traffic through App Service')
param app_min_tls_v string
var app_min_tls_v_parsed = split(app_min_tls_v, ',')

@description('Enable app Virtual Network Integration by providing a subnet ID')
param snet_plan_vnet_integration_id string = ''
var snet_plan_vnet_integration_id_parsed = split(snet_plan_vnet_integration_id, ',')

@description('Enbable App Private Endpoints Connections')
param app_enable_pendpoints string
var app_enable_pendpoints_parsed = split(app_enable_pendpoints, ',')
var app_enable_pe = contains(app_enable_pendpoints_parsed, 'true')

@description('subnets IDs to Enbable App Private Endpoints Connections')
param snet_app_vnet_pe_id string = ''
var snet_app_vnet_pe_id_parsed = split(snet_app_vnet_pe_id, ',')

// pdnszgroup - Add A records to PDNSZ for app pe
@description('App Service Private DNS Zone Resource ID where the A records will be written')
param pdnsz_app_id string = ''
var pdnsz_app_parsed_id = {
  sub_id: substring(substring(pdnsz_app_id, indexOf(pdnsz_app_id, 'subscriptions/') + 14), 0, indexOf(substring(pdnsz_app_id, indexOf(pdnsz_app_id, 'subscriptions/') + 14), '/'))
  rg_n: substring(substring(pdnsz_app_id, indexOf(pdnsz_app_id, 'resourceGroups/') + 15), 0, indexOf(substring(pdnsz_app_id, indexOf(pdnsz_app_id, 'resourceGroups/') + 15), '/'))
  res_n: substring(pdnsz_app_id, lastIndexOf(pdnsz_app_id, '/')+1)
}

var app_properties = [for i in range(0, length(app_names_parsed)): {
  serverFarmId: length(plan_id_parsed) == 1 ? plan_id_parsed[0] : app_names_parsed[i]
  httpsOnly: length(app_enable_https_only_parsed) == 1 ? app_enable_https_only_parsed[0] : app_enable_https_only_parsed[i]
  siteConfig: {
    minTlsVersion: length(app_min_tls_v_parsed) == 1 ? app_min_tls_v_parsed[0] : app_min_tls_v_parsed[i]
  }
}]

// ------------------------------------------------------------------------------------------------
// Deploy Application
// ------------------------------------------------------------------------------------------------
resource appService 'Microsoft.Web/sites@2021-03-01' = [for i in range(0, length(app_names_parsed)): {
  name: app_names_parsed[i]
  location: location
  properties: empty(snet_plan_vnet_integration_id) ? app_properties[0] : union(app_properties[0], {
    virtualNetworkSubnetId: snet_plan_vnet_integration_id
  })
  tags: tags
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = [for i in range(0, length(app_names_parsed)): if (bool(app_enable_pendpoints_parsed[i])) {
  tags: tags
  name: 'pe-${app_names_parsed[i]}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pe-${app_names_parsed[i]}-${take(guid(subscription().id, app_names_parsed[i], tags.env), 4)}'
        properties: {
          privateLinkServiceId: '${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${appService[i].name}'
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    subnet: {
      id: length(snet_app_vnet_pe_id_parsed) == 1 ? snet_app_vnet_pe_id_parsed[0] : snet_app_vnet_pe_id_parsed[i]
    }
  }
  dependsOn: [
    appService
  ]
}]

// App Private DNS Zone Group - A Record
resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-08-01' = [for i in range(0, length(app_names_parsed)): if (bool(app_enable_pendpoints_parsed[i])) {
  name: '${privateEndpoint[i].name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.azurewebsites.net'
        properties: {
          privateDnsZoneId: pdnsz_app_id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}]

module pdnszVnetLinkDeployment 'br:bicephubdev.azurecr.io/bicep/modules/networkprivatednszonesvirtualnetworklinks:b066cd77ae1236f4b0e18c6a2c530aa5518de854' = if (app_enable_pe) {
  name: 'pdnsVnetLinkDeployment'
  scope: resourceGroup(pdnsz_app_parsed_id.rg_n)
  params: {
    snet_app_pe_id: snet_app_vnet_pe_id
    enable_pdnsz_autoregistration: false
    pdnsz_app_id: pdnsz_app_id
    tags: tags
  }
}

output appServices array = [for (name, i) in app_names_parsed: {
  id: appService[i].id
  app_n: appService[i].name
  app_fqdn: '${appService[i].name}.azurewebsites.net'
}]
