// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

using 'main.bicep'

param tier = 'Free'
param nodeSize = 'Standard_D2s_v6'
param nodeCounts = {
  system: 2
  origin: 1
  custom: 1
}

// The object IDs of the groups cars-admins and cars-operators; not secret
param clusterAdminGroupIds = [
  '108821f8-6d6a-4f12-977e-4b434ea31aa9' // cars-admins
  'e77360b5-2ca0-479d-8d79-4eabfe5e308c' // cars-operators
]

// deploy.js overrides this with the signed-in user
param techResponsibility = ''
