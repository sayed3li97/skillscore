// SPDX-License-Identifier: Apache-2.0
//
// Assembles the npm publish set under `npm/dist/` from the Dart binaries that
// the CI matrix compiled into `npm/artifacts/<os>-<cpu>/<exe>`.
//
// It produces one package per supported platform
// (`@skillscore/cli-<os>-<cpu>`, each carrying a single native binary and the
// matching `os`/`cpu` fields so npm installs only the right one) plus the main
// `skillscore` package (the launcher shim + its optionalDependencies). Every
// package.json version is stamped from `pubspec.yaml`, the single source of
// truth, so npm and pub.dev always release in lockstep.
//
// Usage:
//   node npm/build.mjs                 # all platforms; errors on a missing binary
//   node npm/build.mjs --allow-missing # skip platforms whose binary is absent
//                                      # (for a partial/local smoke test)

import { readFileSync, writeFileSync, mkdirSync, rmSync, copyFileSync, chmodSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(here, '..');
const allowMissing = process.argv.includes('--allow-missing');

function readVersion() {
  const pubspec = readFileSync(join(repoRoot, 'pubspec.yaml'), 'utf8');
  const m = pubspec.match(/^version:\s*(.+)$/m);
  if (!m) throw new Error('Could not read version from pubspec.yaml');
  return m[1].trim();
}

const version = readVersion();
const platforms = JSON.parse(readFileSync(join(here, 'platforms.json'), 'utf8'));
const distDir = join(here, 'dist');
const artifactsDir = join(here, 'artifacts');

rmSync(distDir, { recursive: true, force: true });
mkdirSync(distDir, { recursive: true });

const scopedNames = [];
const built = [];

for (const p of platforms) {
  const pkgName = `@skillscore/cli-${p.os}-${p.cpu}`;
  scopedNames.push(pkgName);

  const binarySrc = join(artifactsDir, `${p.os}-${p.cpu}`, p.exe);
  if (!existsSync(binarySrc)) {
    if (allowMissing) {
      console.warn(`skip ${pkgName}: no binary at ${binarySrc}`);
      continue;
    }
    throw new Error(`Missing binary for ${pkgName}: expected ${binarySrc}`);
  }

  const pkgDir = join(distDir, pkgName);
  const binDir = join(pkgDir, 'bin');
  mkdirSync(binDir, { recursive: true });

  copyFileSync(binarySrc, join(binDir, p.exe));
  if (p.os !== 'win32') chmodSync(join(binDir, p.exe), 0o755);

  writeFileSync(
    join(pkgDir, 'package.json'),
    JSON.stringify(
      {
        name: pkgName,
        version,
        description: `skillscore prebuilt CLI binary for ${p.os}-${p.cpu}.`,
        license: 'Apache-2.0',
        repository: {
          type: 'git',
          url: 'git+https://github.com/sayed3li97/skillscore.git',
        },
        // These gate installation to the matching host, so the other four
        // binaries are never downloaded.
        os: [p.os],
        cpu: [p.cpu],
        files: ['bin/'],
      },
      null,
      2
    ) + '\n'
  );
  built.push(pkgName);
}

// Main package: shim + README, with versions stamped in lockstep.
const mainDir = join(distDir, 'skillscore');
mkdirSync(join(mainDir, 'bin'), { recursive: true });
copyFileSync(join(here, 'bin', 'skillscore.js'), join(mainDir, 'bin', 'skillscore.js'));
if (existsSync(join(here, 'README.md'))) {
  copyFileSync(join(here, 'README.md'), join(mainDir, 'README.md'));
}

const mainPkg = JSON.parse(readFileSync(join(here, 'package.json'), 'utf8'));
mainPkg.version = version;
mainPkg.optionalDependencies = Object.fromEntries(scopedNames.map((n) => [n, version]));
writeFileSync(join(mainDir, 'package.json'), JSON.stringify(mainPkg, null, 2) + '\n');

console.log(`Assembled skillscore@${version} + ${built.length} platform package(s):`);
for (const n of built) console.log(`  ${n}@${version}`);
console.log(`Output: ${distDir}`);
