// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

using 'main.bicep'

param sides = ['origin', 'custom']
param stages = ['dev', 'test', 'prod']
param skuName = 'Standard_LRS'

// deploy.js overrides this with the signed-in user
param techResponsibility = ''
