// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// The identities of the data: one per master of each side and stage, and
// one for the job that creates the database users. Each is federated with
// a service account of aks-cars, so a pod of that account signs in
// without a secret. The rights on the data are granted by the components
// sql and storage.

@description('Azure region; defaults to the region of the resource group')
param location string = resourceGroup().location

@description('Who is technically responsible; set by deploy.js')
param techResponsibility string

@description('The sides, each with a master')
param sides array = ['origin', 'custom']

@description('The stages, each with a namespace per side')
param stages array = ['dev', 'test', 'prod']

@description('Namespace of the job that creates the database users')
param adminNamespace string = 'cars-data'

var tags = {
  application: 'cars'
  environment: 'shared'
  techresponsibility: techResponsibility
}

var audience = 'api://AzureADTokenExchange'

resource aks 'Microsoft.ContainerService/managedClusters@2026-04-01' existing = {
  name: 'aks-cars'
}

var issuer = aks.properties.oidcIssuerProfile.issuerURL

var masters = flatten(map(sides, side => map(stages, stage => {
  side: side
  stage: stage
  name: 'id-cars-${side}-master-${stage}'
  subject: 'system:serviceaccount:cars-${side}-${stage}:master'
})))

resource masterIds 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = [
  for m in masters: {
    name: m.name
    location: location
    tags: union(tags, { side: m.side, stage: m.stage })
  }
]

resource masterCredentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = [
  for (m, i) in masters: {
    parent: masterIds[i]
    name: 'aks-cars'
    properties: {
      issuer: issuer
      subject: m.subject
      audiences: [audience]
    }
  }
]

resource sqlAdmin 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-cars-sql-admin'
  location: location
  tags: tags
}

resource sqlAdminCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  parent: sqlAdmin
  name: 'aks-cars'
  properties: {
    issuer: issuer
    subject: 'system:serviceaccount:${adminNamespace}:sql-users'
    audiences: [audience]
  }
}

output masterClientIds array = [for (m, i) in masters: {
  name: m.name
  clientId: masterIds[i].properties.clientId
}]
output sqlAdminClientId string = sqlAdmin.properties.clientId
