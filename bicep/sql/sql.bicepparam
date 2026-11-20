// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

using 'main.bicep'

param sides = ['origin', 'custom']
param stages = ['dev', 'test', 'prod']

// Basic with 2 GB to start (azure-014, req-azure-tir); S0 when exceeded
param sku = {
  name: 'Basic'
  tier: 'Basic'
}
param maxSizeBytes = 2147483648

// deploy.js overrides this with the signed-in user
param techResponsibility = ''
