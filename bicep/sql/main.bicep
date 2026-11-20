// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// A logical SQL server per side with a database per stage. The servers
// allow Entra sign-in only and no public network access; each is reached
// through a private endpoint in snet-cars-endpoints, resolved by the zone
// privatelink.database.windows.net. The identity id-cars-sql-admin is the
// Entra admin of both; a job in the cluster signs in with it and creates
// the users of the master identities, each in its own database only.

@description('Azure region; defaults to the region of the resource group')
param location string = resourceGroup().location

@description('Who is technically responsible; set by deploy.js')
param techResponsibility string

@description('The sides, each with a server')
param sides array = ['origin', 'custom']

@description('The stages, each with a database per side')
param stages array = ['dev', 'test', 'prod']

@description('Size limit of each database in bytes; 2 GB on Basic')
param maxSizeBytes int = 2147483648

@description('Tier of the databases')
param sku object = {
  name: 'Basic'
  tier: 'Basic'
}

var tags = {
  application: 'cars'
  environment: 'shared'
  techresponsibility: techResponsibility
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: 'vnet-cars'
}

resource endpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'snet-cars-endpoints'
}

resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
}

resource sqlAdmin 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: 'id-cars-sql-admin'
}

resource servers 'Microsoft.Sql/servers@2023-08-01' = [
  for side in sides: {
    name: 'sql-cars-${side}'
    location: location
    tags: union(tags, { side: side })
    properties: {
      minimalTlsVersion: '1.2'
      publicNetworkAccess: 'Disabled'
      administrators: {
        administratorType: 'ActiveDirectory'
        principalType: 'Application'
        login: sqlAdmin.name
        // For an application the SID is its client ID
        sid: sqlAdmin.properties.clientId
        tenantId: subscription().tenantId
        azureADOnlyAuthentication: true
      }
    }
  }
]

var databases = flatten(map(range(0, length(sides)), s => map(stages, stage => {
  server: s
  side: sides[s]
  stage: stage
})))

resource dbs 'Microsoft.Sql/servers/databases@2023-08-01' = [
  for db in databases: {
    parent: servers[db.server]
    name: 'sqldb-cars-${db.side}-${db.stage}'
    location: location
    tags: union(tags, { side: db.side, stage: db.stage })
    sku: sku
    properties: {
      maxSizeBytes: maxSizeBytes
    }
  }
]

resource endpoints 'Microsoft.Network/privateEndpoints@2024-05-01' = [
  for (side, i) in sides: {
    name: 'pe-sql-cars-${side}'
    location: location
    tags: union(tags, { side: side })
    properties: {
      subnet: { id: endpointsSubnet.id }
      privateLinkServiceConnections: [
        {
          name: 'sql-cars-${side}'
          properties: {
            privateLinkServiceId: servers[i].id
            groupIds: ['sqlServer']
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
          name: 'database'
          properties: { privateDnsZoneId: zone.id }
        }
      ]
    }
  }
]

output serverHosts array = [for (side, i) in sides: servers[i].properties.fullyQualifiedDomainName]
