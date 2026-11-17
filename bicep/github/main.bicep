// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Lets GitHub Actions work in Azure without a stored secret. Workflows sign
// in through OpenID Connect with a federated credential:
// - id-cars-github-build: the build of an image on main of the given repos;
//   pushes to the registry and reads the secrets of the Key Vault
// - id-cars-github-scan: the pull requests of the given repo; only pulls
//   from the registry, e.g. to scan images
// The Key Vault keeps secrets that workflows need beyond Azure, e.g. the
// private key of a GitHub App; the admin groups may write them. Needs the
// component container-registry deployed first.

@description('Azure region; defaults to the region of the resource group')
param location string = resourceGroup().location

@description('Who is technically responsible; set by deploy.js to the signed-in user')
param techResponsibility string

@description('GitHub organization of the repos')
param organization string = 'rljson'

@description('Repos whose workflows on main build and push images')
param buildRepos array

@description('Repos whose pull requests may pull images')
param scanRepos array

@description('Name of the container registry')
param registryName string = 'crcars'

@description('Name of the Key Vault, globally unique')
param keyVaultName string = 'kv-cars-github'

@description('Object IDs of the Entra groups that may write secrets; set by deploy.js')
param adminGroupIds array = []

var tags = {
  application: 'cars'
  environment: 'shared'
  techresponsibility: techResponsibility
}

var issuer = 'https://token.actions.githubusercontent.com'
var audience = 'api://AzureADTokenExchange'

// Built-in roles
var acrPushRoleId = '8311e382-0749-4cb8-b61a-304f252e45ec'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var secretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource registry 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  name: registryName
}

resource build 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-cars-github-build'
  location: location
  tags: tags
}

// One credential per repo; parallel writes of credentials fail, so serial
@batchSize(1)
resource buildCredentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = [
  for repo in buildRepos: {
    parent: build
    name: '${repo}-main'
    properties: {
      issuer: issuer
      subject: 'repo:${organization}/${repo}:ref:refs/heads/main'
      audiences: [audience]
    }
  }
]

resource scan 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-cars-github-scan'
  location: location
  tags: tags
}

@batchSize(1)
resource scanCredentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = [
  for repo in scanRepos: {
    parent: scan
    name: '${repo}-pull-request'
    properties: {
      issuer: issuer
      subject: 'repo:${organization}/${repo}:pull_request'
      audiences: [audience]
    }
  }
]

resource buildPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, build.id, acrPushRoleId)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPushRoleId)
    principalId: build.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource scanPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, scan.id, acrPullRoleId)
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: scan.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
  }
}

resource buildReads 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, build.id, secretsUserRoleId)
  scope: vault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalId: build.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource adminsWrite 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for id in adminGroupIds: {
    name: guid(vault.id, id, secretsOfficerRoleId)
    scope: vault
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsOfficerRoleId)
      principalId: id
      principalType: 'Group'
    }
  }
]

output buildClientId string = build.properties.clientId
output scanClientId string = scan.properties.clientId
output keyVaultName string = vault.name
