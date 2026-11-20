// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// A storage account per side with a blob container per stage. No shared
// keys, no anonymous access and no public network access; each account is
// reached through a private endpoint in snet-cars-endpoints, resolved by
// the zone privatelink.blob.core.windows.net. The master identity of a
// side and stage may read and write its own container only.

@description('Azure region; defaults to the region of the resource group')
param location string = resourceGroup().location

@description('Who is technically responsible; set by deploy.js')
param techResponsibility string

@description('The sides, each with an account')
param sides array = ['origin', 'custom']

@description('The stages, each with a container per side')
param stages array = ['dev', 'test', 'prod']

@description('Redundancy of the accounts')
param skuName string = 'Standard_LRS'

var tags = {
  application: 'cars'
  environment: 'shared'
  techresponsibility: techResponsibility
}

var blobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-cars'
}

resource endpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'snet-cars-endpoints'
}

resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
}

resource accounts 'Microsoft.Storage/storageAccounts@2024-01-01' = [
  for side in sides: {
    name: 'stcars${side}'
    location: location
    tags: union(tags, { side: side })
    kind: 'StorageV2'
    sku: { name: skuName }
    properties: {
      accessTier: 'Hot'
      allowSharedKeyAccess: false
      allowBlobPublicAccess: false
      publicNetworkAccess: 'Disabled'
      minimumTlsVersion: 'TLS1_2'
      supportsHttpsTrafficOnly: true
      defaultToOAuthAuthentication: true
      networkAcls: {
        defaultAction: 'Deny'
        bypass: 'None'
      }
    }
  }
]

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = [
  for (side, i) in sides: {
    parent: accounts[i]
    name: 'default'
  }
]

var containers = flatten(map(range(0, length(sides)), s => map(stages, stage => {
  account: s
  side: sides[s]
  stage: stage
})))

resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = [
  for c in containers: {
    parent: blobServices[c.account]
    name: c.stage
    properties: {
      publicAccess: 'None'
    }
  }
]

resource masterIds 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = [
  for c in containers: {
    name: 'id-cars-${c.side}-master-${c.stage}'
  }
]

resource containerRights 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (c, i) in containers: {
    scope: blobContainers[i]
    name: guid(blobContainers[i].id, masterIds[i].id, blobDataContributorRoleId)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataContributorRoleId)
      principalId: masterIds[i].properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource endpoints 'Microsoft.Network/privateEndpoints@2024-05-01' = [
  for (side, i) in sides: {
    name: 'pe-st-cars-${side}'
    location: location
    tags: union(tags, { side: side })
    properties: {
      subnet: { id: endpointsSubnet.id }
      privateLinkServiceConnections: [
        {
          name: 'stcars${side}'
          properties: {
            privateLinkServiceId: accounts[i].id
            groupIds: ['blob']
          }
        }
      ]
    }
  }
]

resource zoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = [
  for (side, i) in sides: {
    parent: endpoints[i]
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'blob'
          properties: { privateDnsZoneId: zone.id }
        }
      ]
    }
  }
]

output blobEndpoints array = [for (side, i) in sides: accounts[i].properties.primaryEndpoints.blob]
