param location string
param environment string
param servicePrincipalId string
@secure()
param servicePrincipalKey string
param appServicePlanName string 
@secure()
param emsAppConfigConnectionString string

param apiClientId string 
param groupId string

param functionResoureGroup string

var environmentMap = { dev: 'dev', test: 'tst', staging: 'stg', prod: 'prd' }
var envMap = { dev: 'dv', test: 'ts', staging: 'st', prod: 'pd' }
var resourceName = {
  applicationName: 'ivr'
  departmentCode: 'ccaas'
  environment: environmentMap[environment]
  sequenceNumber: '01' //SequenceNo can be moved to environment.bicep file, Need to research on it. 
  useShortLocationInName: true
}

var stgSlotName = '/staging'

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: 'appconfig-shared-ccaas-${envMap[toLower(environment)]}-w2-01'
  scope: resourceGroup('rg-TeamShared-EnterpriseServicesSolutions-${toLower(environment)}-westus2-01')
}

module functionApp '../ecp-resource-modules/src/modules/functionApp/deploy.bicep' = {
  name: '${uniqueString(deployment().name, location)}-function'
  params:{
    location: location
    servicePrincipalId: servicePrincipalId
    servicePrincipalKey: servicePrincipalKey
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Contributor'
        // pbc-vsts-EnterpriseServicesSolutions-dev (Principal for Service Connection to PBC Tentant)
        principalIds: ['09e9bfed-9e1a-402c-bddf-ca66230dec3f']
      }
    ]
    resourceName: resourceName
    appServicePlanName: appServicePlanName
    appServicePlanResourceGroupName: 'rg-TeamShared-EnterpriseServicesSolutions-${toLower(environment)}-westus2-01'
    existingKeyVaultName: 'kvsharedccaas${envMap[toLower(environment)]}w201'
    deployslots: ['staging']
    alwaysOn: true
    appSettingsKeyValuePairs: {
      AppConfiguration__CCaaSConnectionString: appConfig.listKeys().value[0].connectionString
      AppConfiguration__ConnectionString: emsAppConfigConnectionString
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'dotnet'
      WEBSITE_LOAD_ROOT_CERTIFICATES: '2D6E4A892D553801E2F47C9B679C7C48B99D98D4,BBAD140BA7CF16D9F8EDA415AA293E5FF27B109C'
      WEBSITE_LOAD_CERTIFICATES: '*'
    }
  }
}

var ResourceType = 'func'

// module slotFunctionApp '../common/function-appsettings.bicep' = {
//   name: '${uniqueString(deployment().name, location)}-appsettings'
//   scope: resourceGroup(functionResoureGroup)
//   params: {
//     functionAppName: toLower('${ResourceType}-${resourceName.applicationName}-${resourceName.departmentCode}-${resourceName.environment}-${location}-${resourceName.sequenceNumber}')
//     functionAppNameStaging: toLower('${ResourceType}-${resourceName.applicationName}-${resourceName.departmentCode}-${resourceName.environment}-${location}-${resourceName.sequenceNumber}${stgSlotName}')
//     AppConfiguration__EMSString: emsAppConfigConnectionString
//     location: location
//   }
//   dependsOn: [
//     functionApp
//   ]  
// }

module auth '../common/function-auth-policies-prod.bicep' = {
  name: '${uniqueString(deployment().name, location)}-auth'
  scope: resourceGroup(functionResoureGroup)
  params: {
    functionAppName: toLower('${ResourceType}-${resourceName.applicationName}-${resourceName.departmentCode}-${resourceName.environment}-${location}-${resourceName.sequenceNumber}')
    apiClientId: apiClientId
    groupId: groupId
  }
  dependsOn: [
    functionApp
  ]
}

module authStaging '../common/function-auth-policies.bicep' = {
  name: '${uniqueString(deployment().name, location)}-authstaging'
  scope: resourceGroup(functionResoureGroup)
  params: {
    functionAppName: toLower('${ResourceType}-${resourceName.applicationName}-${resourceName.departmentCode}-${resourceName.environment}-${location}-${resourceName.sequenceNumber}')
    apiClientId: apiClientId
    groupId: groupId
    functionAppNameStaging: toLower('${ResourceType}-${resourceName.applicationName}-${resourceName.departmentCode}-${resourceName.environment}-${location}-${resourceName.sequenceNumber}${stgSlotName}')
  }
  dependsOn: [
    functionApp
  ]
}


// module keyVaultPolicies '../common/keyvault-fa-policies.bicep' = {
//   name: '${uniqueString(deployment().name, location)}-kvpolicies'
//   scope: resourceGroup('rg-TeamShared-EnterpriseServicesSolutions-${toLower(environment)}-westus2-01') 
//   params: {
//     functionAppPrincipalId: functionApp.outputs.functionIdentityId
//     functionAppTentantId: subscription().tenantId
//     keyvaultName: 'kvsharedccaas${envMap[toLower(environment)]}w201'
//   }
//   dependsOn:[
//     functionApp
//   ]
// }

// module keyVaultPoliciesStaging '../common/keyvault-fa-policies.bicep' = {
//   name: '${uniqueString(deployment().name, location)}-kvpolicies-staging'
//   scope: resourceGroup('rg-TeamShared-EnterpriseServicesSolutions-${toLower(environment)}-westus2-01')
//   params: {
//     functionAppPrincipalId: functionApp.outputs.deploySlotsInfo[0].systemAssignedPrincipalId
//     functionAppTentantId: subscription().tenantId
//     keyvaultName: 'kvsharedccaas${envMap[toLower(environment)]}w201'
//   }
//   dependsOn:[
//     functionApp
//   ]
// }
