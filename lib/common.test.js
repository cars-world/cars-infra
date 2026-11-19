// @license
// Copyright (c) rljson
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

import {
  bicepFiles,
  changedComponents,
  CI_COMPONENTS,
  COMPONENTS,
  declaresParam,
  paramsFile,
  parseDeployArgs,
  setsParam,
} from './common.js';

describe('setsParam', () => {
  it('sees a set value and ignores empty ones', () => {
    assert.equal(setsParam("param ids = [\n  'a'\n]", 'ids'), true);
    assert.equal(setsParam('param ids = []', 'ids'), false);
    assert.equal(setsParam("param user = ''", 'user'), false);
    assert.equal(setsParam('param other = 1', 'ids'), false);
  });
});

describe('changedComponents', () => {
  it('lists the changed components of CI in their order', () => {
    const paths = ['bicep/aks/main.bicep', 'README.md', 'bicep/network/network.bicepparam'];
    assert.deepEqual(changedComponents(paths), ['network', 'aks']);
  });

  it('leaves out github and github-infra, which are deployed by hand', () => {
    assert.deepEqual(changedComponents(['bicep/github/main.bicep', 'bicep/github-infra/main.bicep']), []);
    assert.ok(!CI_COMPONENTS.includes('github'));
  });
});

describe('paramsFile()', () => {
  it('names the one parameter file of a component', () => {
    assert.equal(
      paramsFile('network'),
      join('bicep', 'network', 'network.bicepparam'),
    );
  });
});

describe('parseDeployArgs()', () => {
  it('reads a component and the mode', () => {
    assert.deepEqual(parseDeployArgs(['network']), {
      components: ['network'],
      mode: 'ask',
    });
    assert.equal(parseDeployArgs(['network', '--what-if']).mode, 'what-if');
    assert.equal(parseDeployArgs(['network', '--yes']).mode, 'yes');
  });

  it('expands all into every component, in order', () => {
    assert.deepEqual(parseDeployArgs(['all']).components, COMPONENTS);
    assert.deepEqual(COMPONENTS, [
      'log-analytics',
      'container-registry',
      'network',
      'aks',
      'aks-schedule',
      'github',
      'github-infra',
    ]);
  });

  it('rejects wrong input', () => {
    assert.throws(() => parseDeployArgs([]), /Usage/);
    assert.throws(() => parseDeployArgs(['nope']), /Unknown component/);
    assert.throws(() => parseDeployArgs(['environment']), /Unknown component/);
    assert.throws(() => parseDeployArgs(['network', 'dev']), /Unknown option/);
    assert.throws(() => parseDeployArgs(['network', '--yes', 'x']), /Usage/);
  });
});

describe('declaresParam()', () => {
  it('finds a declared parameter only', () => {
    const bicep = 'param clusterAdminGroupIds array\nparam tier string';
    assert.equal(declaresParam(bicep, 'clusterAdminGroupIds'), true);
    assert.equal(declaresParam(bicep, 'tier'), true);
    assert.equal(declaresParam(bicep, 'clusterAdmin'), false);
    assert.equal(declaresParam('// param tier string', 'tier'), false);
  });
});

describe('bicepFiles()', () => {
  it('lists Bicep and parameter files below a folder, sorted', () => {
    const dir = mkdtempSync(join(tmpdir(), 'bicep-'));
    mkdirSync(join(dir, 'b'));
    writeFileSync(join(dir, 'b', 'main.bicep'), '');
    writeFileSync(join(dir, 'b', 'b.bicepparam'), '');
    writeFileSync(join(dir, 'README.md'), '');
    assert.deepEqual(bicepFiles(dir), [
      join(dir, 'b', 'b.bicepparam'),
      join(dir, 'b', 'main.bicep'),
    ]);
  });
});
