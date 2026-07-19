// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

/// Reads a local file's text, or returns null if it is absent or unreadable.
/// The native implementation used when `dart:io` is available.
String? readLocalFileSync(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    return file.readAsStringSync();
  } on FileSystemException {
    return null;
  }
}
