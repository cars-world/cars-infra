#!/usr/bin/env node
// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// The test of cars-infra: runs the unit tests of lib and builds every Bicep
// and parameter file. Run it before each commit.
//
//   node test.js

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { chdir } from 'node:process';
import { fileURLToPath } from 'node:url';

import { bicepFiles, COMPONENTS, paramsFile } from './lib/common.js';

chdir(dirname(fileURLToPath(import.meta.url)));

let failed = 0;

const unit = spawnSync(process.execPath, ['--test', 'lib/'], {
  stdio: 'inherit',
});
if (unit.status !== 0) {
  console.log('❌ Unit tests of lib');
  failed++;
}

const files = bicepFiles('bicep');
for (const component of COMPONENTS) {
  for (const file of [join('bicep', component, 'main.bicep'), paramsFile(component)]) {
    if (!files.includes(file)) {
      console.log(`❌ Missing ${file}`);
      failed++;
    }
  }
}

for (const file of files) {
  const args = file.endsWith('.bicepparam')
    ? ['bicep', 'build-params', '--file', file, '--stdout']
    : ['bicep', 'build', '--file', file, '--stdout'];
  const { status } = spawnSync('az', args, { stdio: ['ignore', 'ignore', 'inherit'] });
  console.log(`${status === 0 ? '✅' : '❌'} ${file}`);
  if (status !== 0) failed++;
}

if (!files.length) {
  console.log('❌ No Bicep files found');
  process.exit(1);
}
// The workflows and the ruleset of main must agree on the check what-if
const ruleset = JSON.parse(readFileSync('.github/rulesets/main.json', 'utf8'));
const rule = (type) => ruleset.rules.find((r) => r.type === type)?.parameters;
const guarded =
  rule('required_status_checks')?.required_status_checks.some((c) => c.context === 'what-if') &&
  rule('pull_request')?.require_code_owner_review === true &&
  /^ {4}name: what-if$/m.test(readFileSync('.github/workflows/plan.yaml', 'utf8')) &&
  /^\* +@\S+/m.test(readFileSync('.github/CODEOWNERS', 'utf8'));
if (guarded) {
  console.log('✅ main requires the check what-if and the review of the code owner');
} else {
  console.log('❌ The ruleset, plan.yaml or CODEOWNERS no longer guard main');
  failed++;
}

if (failed) {
  console.log(`❌ ${failed} checks failed`);
  process.exit(1);
}
console.log(`✅ Unit tests pass, all ${files.length} Bicep files build`);
