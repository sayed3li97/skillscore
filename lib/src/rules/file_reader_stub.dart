// SPDX-License-Identifier: Apache-2.0

/// Reads a local file's text, or returns null if it is absent or unreadable.
/// The web (JS/Wasm) build has no filesystem, so linked files are always
/// treated as unreadable and the D2 onward-link check degrades to a pass.
String? readLocalFileSync(String path) => null;
