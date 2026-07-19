#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0
//
// Thin launcher for the `skillscore` CLI when installed from npm.
//
// The real CLI is a native binary compiled from Dart with `dart compile exe`.
// One prebuilt binary per platform is published as its own optional package
// (`@skillscore/cli-<platform>-<arch>`); npm installs only the one that matches
// the host. This shim resolves that package, then execs the binary with the
// user's arguments and forwards its exit code — so `npx skillscore ...` behaves
// exactly like the natively installed CLI, with no Dart toolchain required.
'use strict';

const path = require('path');
const { spawnSync } = require('child_process');

// npm's `os`/`cpu` values. process.platform is one of 'darwin' | 'linux' |
// 'win32'; process.arch is 'x64' | 'arm64' for the platforms we ship.
const platform = process.platform;
const arch = process.arch;
const exe = platform === 'win32' ? 'skillscore.exe' : 'skillscore';
const platformPackage = `@skillscore/cli-${platform}-${arch}`;

function resolveBinary() {
  try {
    // Resolve via the platform package's manifest, then join the binary path.
    // This is robust even when the binary has no file extension.
    const pkgJson = require.resolve(`${platformPackage}/package.json`);
    return path.join(path.dirname(pkgJson), 'bin', exe);
  } catch (_) {
    return null;
  }
}

const binary = resolveBinary();
if (binary === null) {
  process.stderr.write(
    `skillscore: no prebuilt binary for ${platform}-${arch}.\n` +
      'Supported: darwin-x64, darwin-arm64, linux-x64, linux-arm64, win32-x64.\n' +
      'If your platform is supported, reinstall so npm can fetch the optional\n' +
      "binary package. Otherwise install via Dart: 'dart pub global activate skillscore'.\n"
  );
  process.exit(1);
}

const result = spawnSync(binary, process.argv.slice(2), { stdio: 'inherit' });

if (result.error) {
  process.stderr.write(`skillscore: failed to run binary: ${result.error.message}\n`);
  process.exit(1);
}

// Propagate signals as the conventional 128+signal exit code; otherwise pass
// the child's own exit status straight through.
if (result.signal) {
  process.exit(1);
}
process.exit(result.status === null ? 1 : result.status);
