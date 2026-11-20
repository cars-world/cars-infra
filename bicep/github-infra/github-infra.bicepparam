// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

using 'main.bicep'

// GitHub signs the subjects with immutable IDs:
// gh api orgs/cars-world -q .id, gh api repos/cars-world/cars-infra -q .id
param organization = 'cars-world'
param organizationId = 358216462
param repo = { name: 'cars-infra', id: 1445880210 }
param environment = 'azure'

// The roles the components assign; the deploy may assign these only
param assignableRoleIds = [
  '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
  '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush
  'ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8' // Azure Kubernetes Service Contributor
  'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b' // Azure Kubernetes Service RBAC Cluster Admin
  '4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
  '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
  'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
]

// deploy.js overrides this with the signed-in user
param techResponsibility = ''
