// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Lets the workflows of the infrastructure repo work in rg-cars without a
// stored secret:
// - id-cars-github-infra-plan: the pull requests; reads the resources and
//   runs a what-if, changes nothing
// - id-cars-github-infra: the workflows in the GitHub environment of the
//   deploy; Contributor, and may assign only the roles in assignableRoleIds
//
// This component grants the deploy its own rights, so it is deployed by
// hand only, never by the workflow it serves.

@description('Azure region; defaults to the region of the resource group')
param location string = resourceGroup().location

@description('Who is technically responsible; set by deploy.js')
param techResponsibility string

@description('GitHub organization of the repo')
param organization string

@description('ID of the GitHub organization; GitHub puts it into the subject')
param organizationId int

@description('The infrastructure repo, as { name, id }')
param repo object

@description('GitHub environment whose jobs may deploy')
param environment string = 'azure'

@description('IDs of the roles the deploy identity may assign')
param assignableRoleIds array

var tags = {
  application: 'cars'
  environment: 'shared'
  techresponsibility: techResponsibility
}

var issuer = 'https://token.actions.githubusercontent.com'
var audience = 'api://AzureADTokenExchange'
var subjectPrefix = 'repo:${organization}@${organizationId}/${repo.name}@${repo.id}'

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var rbacAdministratorRoleId = 'f58310d9-a9f6-439a-9e8d-f62e7b41a168'

// Role assignments of the deploy identity: it may write or delete only
// those whose role is one of assignableRoleIds
var allowedRoles = join(assignableRoleIds, ', ')
var assignCondition = '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${allowedRoles}})) AND ((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/delete\'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${allowedRoles}}))'

resource plan 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-cars-github-infra-plan'
  location: location
  tags: tags
}

resource planCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  parent: plan
  name: '${repo.name}-pull-request'
  properties: {
    issuer: issuer
    subject: '${subjectPrefix}:pull_request'
    audiences: [audience]
  }
}

resource deploy 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-cars-github-infra'
  location: location
  tags: tags
}

resource deployCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  parent: deploy
  name: '${repo.name}-environment-${environment}'
  properties: {
    issuer: issuer
    subject: '${subjectPrefix}:environment:${environment}'
    audiences: [audience]
  }
}

// A what-if needs, beyond reading, the right to validate and simulate a
// deployment; it creates nothing
resource whatIfRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, 'cars-what-if')
  properties: {
    roleName: 'cars what-if on ${resourceGroup().name}'
    description: 'Runs a what-if of a deployment in ${resourceGroup().name}; changes nothing'
    type: 'CustomRole'
    assignableScopes: [resourceGroup().id]
    permissions: [
      {
        actions: [
          'Microsoft.Resources/deployments/validate/action'
          'Microsoft.Resources/deployments/whatIf/action'
        ]
        notActions: []
      }
    ]
  }
}

resource planReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, plan.id, readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: plan.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource planWhatIf 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, plan.id, whatIfRole.id)
  properties: {
    roleDefinitionId: whatIfRole.id
    principalId: plan.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploy.id, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: deploy.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource deployRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploy.id, rbacAdministratorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', rbacAdministratorRoleId)
    principalId: deploy.properties.principalId
    principalType: 'ServicePrincipal'
    condition: assignCondition
    conditionVersion: '2.0'
  }
}

output planClientId string = plan.properties.clientId
output deployClientId string = deploy.properties.clientId
