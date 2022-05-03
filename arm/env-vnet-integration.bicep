param docsContainerName string = 'documents'
param spnObjectId string
param deployFunction bool  = true

var keyVaultName = 'akv-${uniqueString(resourceGroup().id)}'
var searchName = 'search-${uniqueString(resourceGroup().id)}'
var cognitiveAccountName = 'cognitive-account-${uniqueString(resourceGroup().id)}'
var storageAccountNameData = 'stg${uniqueString(resourceGroup().id)}'
var appServicePlanName = 'app-plan-${uniqueString(resourceGroup().id)}'
var webAppName = 'site-${uniqueString(resourceGroup().id)}'
var functionAppName = 'function-app-${uniqueString(resourceGroup().id)}'
var appInsightsName = 'app-insights-${uniqueString(resourceGroup().id)}'

var secretKeySearch = 'SEARCHSERVICESECRET'
var secretKeyStorageKey = 'STORAGEACCOUNTKEYSECRET'

var subnetAppServiceName = 'AppService'
var subnetPrivateEndpointsName = 'PrivateEndpoints'

/*
  Example:

  var ipAddressToAllow = [
    {
      value: 'x.x.x.x'
      action: 'Allow'
    }
    {
      value: 'y.y.y.y/a'
      action: 'Allow'
    }
  ]
*/
var ipAddressToAllow = [
]

// Networking
resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  location: resourceGroup().location
  name: 'vnet'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetAppServiceName
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'appservice-serverfarm'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: subnetPrivateEndpointsName
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource storageBlobPrivateZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource storageBlobPrivateZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${storageBlobPrivateZone.name}/${uniqueString(vnet.id)}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

// Key Vault
resource azure_key_vault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    tenantId: subscription().tenantId
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    accessPolicies: [
      {
        objectId: spnObjectId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
      {
        objectId: app_services_website.identity.principalId
        tenantId: app_services_website.identity.tenantId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
     
    ]
  }
}

resource akv_secret_storage_account_resource_id 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${azure_key_vault.name}/STORAGEACCOUNTRESOURCEID'
  properties: {
    value: azure_storage_account_data.id
  }
}

resource akv_secret_storage_account_secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${azure_key_vault.name}/STORAGEACCOUNTCONNECTIONSTRING'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${azure_storage_account_data.name};AccountKey=${listKeys(azure_storage_account_data.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
  }
}

resource akv_secret_storage_account_key_secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${azure_key_vault.name}/${secretKeyStorageKey}'
  properties: {
    value: listKeys(azure_storage_account_data.id, '2019-06-01').keys[0].value
  }
}

resource akv_secret_search_endpoint 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${azure_key_vault.name}/SEARCHSERVICEENDPOINT'
  properties: {
    value: 'https://${azure_search_service.name}.search.windows.net'
  }
}

resource akv_secret_search_secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${azure_key_vault.name}/${secretKeySearch}'
  properties: {
    value: listAdminKeys(azure_search_service.id, '2020-08-01').primaryKey
  }
}

resource akv_secret_cognitive_services_secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${azure_key_vault.name}/COGNITIVESERVICESSECRET'
  properties: {
    value: listKeys(azure_congnitive_account.id, '2017-04-18').key1
  }
}

// Search
resource azure_search_service 'Microsoft.Search/searchServices@2020-08-01' = {
  name: searchName
  location: resourceGroup().location
  sku: {
    name: 'standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Cognitive Services
resource azure_congnitive_account 'Microsoft.CognitiveServices/accounts@2017-04-18' = {
  name: cognitiveAccountName
  location: resourceGroup().location
  kind: 'CognitiveServices'

  sku: {
    name: 'S0'
  }
}

// Storage Accounts
resource azure_storage_account_data 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountNameData
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices,Logging,Metrics'
      ipRules: ipAddressToAllow
    }
  }
}

resource azure_storage_account_data_blob_pe 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  location: resourceGroup().location
  name: '${azure_storage_account_data.name}-blob-endpoint'
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${subnetPrivateEndpointsName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${azure_storage_account_data.name}-blob-endpoint'
        properties: {
          privateLinkServiceId: azure_storage_account_data.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource azure_storage_account_data_blob_pe_dns_reg 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${azure_storage_account_data_blob_pe.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_blob_core_windows_net'
        properties: {
          privateDnsZoneId: storageBlobPrivateZone.id
        }
      }
    ]
  }
}

resource azure_storage_account_functions 'Microsoft.Storage/storageAccounts@2019-06-01' = if (deployFunction) {
  name: 'stgfunc${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'Logging,Metrics'
    }
  }
}

resource azure_storage_account_functions_blob_pe 'Microsoft.Network/privateEndpoints@2020-06-01' = if (deployFunction) {
  location: resourceGroup().location
  name: '${azure_storage_account_functions.name}-blob-endpoint'
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${subnetPrivateEndpointsName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${azure_storage_account_functions.name}-blob-endpoint'
        properties: {
          privateLinkServiceId: azure_storage_account_functions.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource azure_storage_account_functions_blob_pe_dns_reg 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' =  if (deployFunction) {
  name: '${azure_storage_account_functions_blob_pe.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_blob_core_windows_net'
        properties: {
          privateDnsZoneId: storageBlobPrivateZone.id
        }
      }
    ]
  }
}

resource azure_storage_account_container_docs 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01'  = {
  name: '${azure_storage_account_data.name}/default/${docsContainerName}'
  properties: {
    publicAccess: 'None'
  }
}

// App Service
resource azure_app_service_plan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: resourceGroup().location
  kind: 'Linux'
  sku: {
    tier: 'Standard'
    name: 'S1'
  }
  properties: {
    reserved: true
  }
}

resource app_insights 'Microsoft.Insights/components@2015-05-01' = {
  name: appInsightsName
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource app_services_website 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppName
  location: resourceGroup().location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: azure_app_service_plan.id
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|3.1'
      appSettings: [
        {
          name: 'WEBSITE_DNS_SERVER' // required for VNET Integration + Azure DNS Private Zones
          value: '168.63.129.16'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'SearchServiceName'
          value: azure_search_service.name
        }
        {
          name: 'SearchApiKey'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${secretKeySearch})'
        }
        {
          name: 'SearchIndexName'
          value: 'km'
        }
        {
          name: 'SearchIndexerName'
          value: 'km-indexer'
        }
        {
          name: 'StorageAccountName'
          value: azure_storage_account_data.name
        }
        {
          name: 'StorageAccountKey'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${secretKeyStorageKey})'
        }
        {
          name: 'StorageContainerAddress'
          value: 'https://${azure_storage_account_data.name}.blob.core.windows.net/${docsContainerName}'
        }
        {
          name: 'KeyField'
          value: 'metadata_storage_path'
        }
        {
          name: 'IsPathBase64Encoded'
          value: 'true'
        }
        {
          name: 'InstrumentationKey'
          value: app_insights.properties.InstrumentationKey
        }
      ]
    }
  }
}

resource app_services_website_vnet 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  name: '${app_services_website.name}/VirtualNetwork'
  properties: {
    subnetResourceId: '${vnet.id}/subnets/${subnetAppServiceName}'
    swiftSupported: true
  } 
}

resource app_services_function_app 'Microsoft.Web/sites@2020-06-01' = if (deployFunction) {
  name: functionAppName
  location: resourceGroup().location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: azure_app_service_plan.id
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_DNS_SERVER' // required for VNET Integration + Azure DNS Private Zones
          value: '168.63.129.16'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '10.14.1'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: app_insights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: deployFunction ? 'DefaultEndpointsProtocol=https;AccountName=${azure_storage_account_functions.name};AccountKey=${listKeys(azure_storage_account_functions.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net' : ''
        }
      ]
    }
  }
}

resource function_access_policy 'Microsoft.KeyVault/vaults/accessPolicies@2021-11-01-preview' = if (deployFunction) {
  name: 'add'
  parent: azure_key_vault
  properties: {
    accessPolicies: deployFunction ? [
       {
        objectId: app_services_function_app.identity.principalId
        tenantId: app_services_function_app.identity.tenantId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ] : []
  }
}

resource app_services_function_app_vnet 'Microsoft.Web/sites/networkConfig@2020-06-01' = if (deployFunction) {
  name: '${app_services_function_app.name}/VirtualNetwork'
  properties: {
    subnetResourceId: '${vnet.id}/subnets/${subnetAppServiceName}'
    swiftSupported: true
  } 
}

// Role Assignments
resource roleAssignSearchToStorageBlobReader 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, 'Storage Blob Data Reader')
  scope: azure_storage_account_data
  properties: {
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    principalId: azure_search_service.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output storage_data_id string = azure_storage_account_data.id
output search_enpoint string = 'https://${azure_search_service.name}.search.windows.net'
