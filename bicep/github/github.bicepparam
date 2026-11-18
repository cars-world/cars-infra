// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

using 'main.bicep'

param organization = 'cars-world'
param buildRepos = [
  'cars-origin-master'
  'cars-origin-client'
  'cars-custom-master'
  'cars-custom-client'
]
param scanRepos = [
  'cars-deployment'
]
param registryName = 'crcars'
param keyVaultName = 'kv-cars-github'

// deploy.js overrides this with the signed-in user
param techResponsibility = ''
