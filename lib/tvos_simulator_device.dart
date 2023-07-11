// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/ios/simulators.dart';

/// eLinux device implementation.
///
/// See: [DesktopDevice] in `desktop_device.dart`
class TvOSSimulator extends IOSSimulator {
  TvOSSimulator(
    super.id, {
    required super.name,
    required super.simulatorCategory,
    required super.simControl,
  });

  @override
  bool isSupported() {
    if (!globals.platform.isMacOS) {
      return false;
    }

    return true;
  }
}
