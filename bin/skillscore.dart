// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:skillscore/skillscore.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await runCli(arguments);
  } on FileSystemException catch (e) {
    // A closed pipe (e.g. `skillscore rules | head`) is not an error.
    if (e.osError?.errorCode == 32) {
      exitCode = exitOk;
    } else {
      stderr.writeln('Error: ${e.message}');
      exitCode = exitUsage;
    }
  }
}
