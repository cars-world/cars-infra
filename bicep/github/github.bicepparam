// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

using 'main.bicep'

// GitHub signs the subjects of cars-world with the IDs of the organization
// and the repos: gh api orgs/cars-world -q .id, gh api repos/cars-world/<repo> -q .id
param organization = 'cars-world'
param organizationId = 358216462
param buildRepos = [
  { name: 'cars-origin-master', id: 1453837020 }
  { name: 'cars-origin-client', id: 1453837951 }
  { name: 'cars-custom-master', id: 1453841660 }
  { name: 'cars-custom-client', id: 1453842420 }
]
param scanRepos = [
  { name: 'cars-deployment', id: 1445883097 }
]
param registryName = 'crcars'
param keyVaultName = 'kv-cars-github'

// deploy.js overrides this with the signed-in user
param techResponsibility = ''

// The object IDs of the groups cars-admins and cars-operators; not secret
param adminGroupIds = [
  '108821f8-6d6a-4f12-977e-4b434ea31aa9' // cars-admins
  'e77360b5-2ca0-479d-8d79-4eabfe5e308c' // cars-operators
]
