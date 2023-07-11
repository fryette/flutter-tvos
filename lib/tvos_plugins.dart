// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/platform_plugins.dart';

import 'package:yaml/yaml.dart';

class TvOSPlugin extends PluginPlatform
    implements NativeOrDartPlugin, DarwinPlugin {
  const TvOSPlugin({
    required this.name,
    required this.classPrefix,
    this.pluginClass,
    this.dartPluginClass,
    bool? ffiPlugin,
    this.defaultPackage,
    bool? sharedDarwinSource,
  })  : ffiPlugin = ffiPlugin ?? false,
        sharedDarwinSource = sharedDarwinSource ?? false;

  factory TvOSPlugin.fromYaml(String name, YamlMap yaml) {
    assert(validate(
        yaml)); // TODO(zanderso): https://github.com/flutter/flutter/issues/67241
    return TvOSPlugin(
      name: name,
      classPrefix: '',
      pluginClass: yaml[kPluginClass] as String?,
      dartPluginClass: yaml[kDartPluginClass] as String?,
      ffiPlugin: yaml[kFfiPlugin] as bool?,
      defaultPackage: yaml[kDefaultPackage] as String?,
      sharedDarwinSource: yaml[kSharedDarwinSource] as bool?,
    );
  }

  static bool validate(YamlMap yaml) {
    return yaml[kPluginClass] is String ||
        yaml[kDartPluginClass] is String ||
        yaml[kFfiPlugin] == true ||
        yaml[kSharedDarwinSource] == true ||
        yaml[kDefaultPackage] is String;
  }

  static const String kConfigKey = 'tvos';

  final String name;

  /// Note, this is here only for legacy reasons. Multi-platform format
  /// always sets it to empty String.
  final String classPrefix;
  final String? pluginClass;
  final String? dartPluginClass;
  final bool ffiPlugin;
  final String? defaultPackage;

  /// Indicates the iOS native code is shareable with macOS in
  /// the subdirectory "darwin", otherwise in the subdirectory "ios".
  @override
  final bool sharedDarwinSource;

  @override
  bool hasMethodChannel() => pluginClass != null;

  @override
  bool hasFfi() => ffiPlugin;

  @override
  bool hasDart() => dartPluginClass != null;

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'prefix': classPrefix,
      if (pluginClass != null) 'class': pluginClass,
      if (dartPluginClass != null) kDartPluginClass: dartPluginClass,
      if (ffiPlugin) kFfiPlugin: true,
      if (sharedDarwinSource) kSharedDarwinSource: true,
      if (defaultPackage != null) kDefaultPackage: defaultPackage,
    };
  }
}
