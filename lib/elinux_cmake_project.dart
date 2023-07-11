// Copyright 2021 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/build_info.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/ios/xcode_build_settings.dart' as xcode;
import 'package:flutter_tools/src/project.dart';

import 'tvos_plugins.dart';
import 'elinux_plugins.dart';

/// The eLinux sub project.
class ELinuxProject extends FlutterProjectPlatform
    implements CmakeBasedProject {
  ELinuxProject.fromFlutter(this.parent);

  @override
  final FlutterProject parent;

  @override
  String get pluginConfigKey => ELinuxPlugin.kConfigKey;

  String get _childDirectory => 'elinux';

  @override
  bool existsSync() => editableDirectory.existsSync() && cmakeFile.existsSync();

  @override
  File get cmakeFile => editableDirectory.childFile('CMakeLists.txt');

  @override
  File get managedCmakeFile => managedDirectory.childFile('CMakeLists.txt');

  @override
  File get generatedCmakeConfigFile =>
      ephemeralDirectory.childFile('generated_config.cmake');

  @override
  File get generatedPluginCmakeFile =>
      managedDirectory.childFile('generated_plugins.cmake');

  @override
  Directory get pluginSymlinkDirectory =>
      ephemeralDirectory.childDirectory('.plugin_symlinks');

  Directory get editableDirectory =>
      parent.directory.childDirectory(_childDirectory);

  Directory get managedDirectory => editableDirectory.childDirectory('flutter');

  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  Future<void> ensureReadyForPlatformSpecificTooling() async {
    await refreshELinuxPluginsList(parent);
  }
}

class TvOSProject extends XcodeBasedProject {
  TvOSProject.fromFlutter(this.parent);

  @override
  final FlutterProject parent;

  @override
  String get pluginConfigKey => TvOSPlugin.kConfigKey;

  @override
  bool existsSync() => hostAppRoot.existsSync();

  @override
  Directory get hostAppRoot => parent.directory.childDirectory('tvos');

  /// The directory in the project that is managed by Flutter. As much as
  /// possible, files that are edited by Flutter tooling after initial project
  /// creation should live here.
  Directory get managedDirectory => hostAppRoot.childDirectory('Flutter');

  /// The subdirectory of [managedDirectory] that contains files that are
  /// generated on the fly. All generated files that are not intended to be
  /// checked in should live here.
  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  /// The xcfilelist used to track the inputs for the Flutter script phase in
  /// the Xcode build.
  File get inputFileList =>
      ephemeralDirectory.childFile('FlutterInputs.xcfilelist');

  /// The xcfilelist used to track the outputs for the Flutter script phase in
  /// the Xcode build.
  File get outputFileList =>
      ephemeralDirectory.childFile('FlutterOutputs.xcfilelist');

  @override
  File get generatedXcodePropertiesFile =>
      ephemeralDirectory.childFile('Flutter-Generated.xcconfig');

  File get pluginRegistrantImplementation =>
      managedDirectory.childFile('GeneratedPluginRegistrant.swift');

  @override
  File xcodeConfigFor(String mode) =>
      managedDirectory.childFile('Flutter-$mode.xcconfig');

  @override
  File get generatedEnvironmentVariableExportScript =>
      ephemeralDirectory.childFile('flutter_export_environment.sh');

  /// The file where the Xcode build will write the name of the built app.
  ///
  /// Ideally this will be replaced in the future with inspection of the Runner
  /// scheme's target.
  File get nameFile => ephemeralDirectory.childFile('.app_filename');

  Future<void> ensureReadyForPlatformSpecificTooling() async {
    // TODO(stuartmorgan): Add create-from-template logic here.
    await _updateGeneratedXcodeConfigIfNeeded();
  }

  Future<void> _updateGeneratedXcodeConfigIfNeeded() async {
    if (globals.cache.isOlderThanToolsStamp(generatedXcodePropertiesFile)) {
      await xcode.updateGeneratedXcodeProperties(
        project: parent,
        buildInfo: BuildInfo.debug,
        useMacOSConfig: true,
      );
    }
  }
}
