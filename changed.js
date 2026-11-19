#!/usr/bin/env node
// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// Prints the components a change touches, one per line, in the order of
// deploy.js; github and github-infra are left out, as they are deployed by
// hand. Reads the changed paths from stdin, one per line, e.g. from
// git diff --name-only.
//
// Usage: git diff --name-only <base> <head> | node changed.js

import { readFileSync } from 'node:fs';

import { changedComponents, run } from './lib/common.js';

await run(() => {
  const paths = readFileSync(0, 'utf8').split('\n').filter(Boolean);
  for (const component of changedComponents(paths)) console.log(component);
});
