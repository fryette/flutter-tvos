// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter_tools/src/android/android_workflow.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/utils.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/custom_devices/custom_devices_config.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/flutter_device_manager.dart';
import 'package:flutter_tools/src/fuchsia/fuchsia_workflow.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/ios/simulators.dart';
import 'package:flutter_tools/src/macos/macos_workflow.dart';
import 'package:flutter_tools/src/macos/xcode.dart';
import 'package:flutter_tools/src/windows/windows_workflow.dart';
import 'package:process/process.dart';

import 'tvos_simulator_device.dart';

/// An extended [FlutterDeviceManager] for managing eLinux devices.
class TvOSDeviceManager extends FlutterDeviceManager {
  /// Source: [runInContext] in `context_runner.dart`
  TvOSDeviceManager()
      : super(
          logger: globals.logger,
          processManager: globals.processManager,
          platform: globals.platform,
          androidSdk: globals.androidSdk,
          iosSimulatorUtils: globals.iosSimulatorUtils!,
          featureFlags: featureFlags,
          fileSystem: globals.fs,
          iosWorkflow: globals.iosWorkflow!,
          artifacts: globals.artifacts!,
          flutterVersion: globals.flutterVersion,
          androidWorkflow: androidWorkflow!,
          fuchsiaWorkflow: fuchsiaWorkflow!,
          xcDevice: globals.xcdevice!,
          userMessages: globals.userMessages,
          windowsWorkflow: windowsWorkflow!,
          macOSWorkflow: context.get<MacOSWorkflow>()!,
          fuchsiaSdk: globals.fuchsiaSdk!,
          operatingSystemUtils: globals.os,
          customDevicesConfig: CustomDevicesConfig(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
          ),
        );

  final TvOSSimulators _tvOSDeviceDiscovery = TvOSSimulators(
      iosSimulatorUtils: TvOSSimulatorUtils(
    xcode: globals.xcode!,
    logger: globals.logger,
    processManager: globals.processManager,
  ));

  @override
  List<DeviceDiscovery> get deviceDiscoverers => <DeviceDiscovery>[
        ...super.deviceDiscoverers,
        _tvOSDeviceDiscovery,
      ];
}

class TvOSSimulators extends PollingDeviceDiscovery {
  TvOSSimulators({
    required TvOSSimulatorUtils iosSimulatorUtils,
  })  : _tvOSSimulatorUtils = iosSimulatorUtils,
        super('tvOS simulators');

  final TvOSSimulatorUtils _tvOSSimulatorUtils;

  @override
  bool get supportsPlatform => globals.platform.isMacOS;

  @override
  bool get canListAnything => globals.iosWorkflow?.canListDevices ?? false;

  @override
  Future<List<Device>> pollingGetDevices({Duration? timeout}) async =>
      _tvOSSimulatorUtils.getAttachedDevices();

  @override
  List<String> get wellKnownIds => const <String>[];
}

class TvOSSimulatorUtils {
  TvOSSimulatorUtils({
    required Xcode xcode,
    required Logger logger,
    required ProcessManager processManager,
  })  : _simControl = TvOSSimControl(
          logger: logger,
          processManager: processManager,
          xcode: xcode,
        ),
        _xcode = xcode;

  final SimControl _simControl;
  final Xcode _xcode;

  Future<List<TvOSSimulator>> getAttachedDevices() async {
    if (!_xcode.isInstalledAndMeetsVersionCheck) {
      return <TvOSSimulator>[];
    }

    final List<BootedSimDevice> connected =
        await _simControl.getConnectedDevices();
    final devices = connected
        .map<TvOSSimulator?>((BootedSimDevice device) {
          final String? udid = device.udid;
          final String? name = device.name;
          if (udid == null) {
            globals.printTrace('Could not parse simulator udid');
            return null;
          }
          if (name == null) {
            globals.printTrace('Could not parse simulator name');
            return null;
          }
          return TvOSSimulator(
            udid,
            name: name,
            simControl: _simControl,
            simulatorCategory: device.category,
          );
        })
        .whereType<TvOSSimulator>()
        .toList();

    return devices;
  }
}

class TvOSSimControl extends SimControl {
  TvOSSimControl({
    required super.logger,
    required super.processManager,
    required super.xcode,
  })  : _logger = logger,
        _xcode = xcode,
        _processUtils =
            ProcessUtils(processManager: processManager, logger: logger);

  final Logger _logger;
  final ProcessUtils _processUtils;
  final Xcode _xcode;

  @override
  Future<List<BootedSimDevice>> getConnectedDevices() async {
    final List<BootedSimDevice> devices = <BootedSimDevice>[];

    final Map<String, Object?> devicesSection = await _listBootedDevices();

    for (final String deviceCategory in devicesSection.keys) {
      final Object? devicesData = devicesSection[deviceCategory];
      if (devicesData != null && devicesData is List<Object?>) {
        for (final Map<String, Object?> data in devicesData
            .map<Map<String, Object?>?>(castStringKeyedMap)
            .whereType<Map<String, Object?>>()) {
          devices.add(BootedSimDevice(deviceCategory, data));
        }
      }
    }

    return devices;
  }

  Future<Map<String, Object?>> _listBootedDevices() async {
    // Sample output from `simctl list available booted --json`:
    //
    // {
    //   "devices" : {
    //     "com.apple.CoreSimulator.SimRuntime.iOS-14-0" : [
    //       {
    //         "lastBootedAt" : "2022-07-26T01:46:23Z",
    //         "dataPath" : "\/Users\/magder\/Library\/Developer\/CoreSimulator\/Devices\/9EC90A99-6924-472D-8CDD-4D8234AB4779\/data",
    //         "dataPathSize" : 1620578304,
    //         "logPath" : "\/Users\/magder\/Library\/Logs\/CoreSimulator\/9EC90A99-6924-472D-8CDD-4D8234AB4779",
    //         "udid" : "9EC90A99-6924-472D-8CDD-4D8234AB4779",
    //         "isAvailable" : true,
    //         "logPathSize" : 9740288,
    //         "deviceTypeIdentifier" : "com.apple.CoreSimulator.SimDeviceType.iPhone-11",
    //         "state" : "Booted",
    //         "name" : "iPhone 11"
    //       }
    //     ],
    //     "com.apple.CoreSimulator.SimRuntime.iOS-13-0" : [
    //
    //     ],
    //     "com.apple.CoreSimulator.SimRuntime.iOS-12-4" : [
    //
    //     ],
    //     "com.apple.CoreSimulator.SimRuntime.iOS-16-0" : [
    //
    //     ]
    //   }
    // }

    final List<String> command = <String>[
      ..._xcode.xcrunCommand(),
      'simctl',
      'list',
      'devices',
      'booted',
      'tvos',
      '--json',
    ];
    _logger.printTrace(command.join(' '));
    final RunResult results = await _processUtils.run(command);
    if (results.exitCode != 0) {
      _logger.printError(
          'Error executing simctl: ${results.exitCode}\n${results.stderr}');
      return <String, Map<String, Object?>>{};
    }
    try {
      final Object? decodeResult =
          (json.decode(results.stdout) as Map<String, Object?>)['devices'];
      if (decodeResult is Map<String, Object?>) {
        return decodeResult;
      }
      _logger.printError(
          'simctl returned unexpected JSON response: ${results.stdout}');
      return <String, Object>{};
    } on FormatException {
      // We failed to parse the simctl output, or it returned junk.
      // One known message is "Install Started" isn't valid JSON but is
      // returned sometimes.
      _logger
          .printError('simctl returned non-JSON response: ${results.stdout}');
      return <String, Object>{};
    }
  }
}

/// Device discovery for tvOS devices.
// class TvOSSimulatorDeviceDiscovery extends IOSSimulators {
//   TvOSSimulatorDeviceDiscovery({
//     required TvOSWorkflow eLinuxWorkflow,
//     required ProcessManager processManager,
//     required Logger logger,
//   })  : _eLinuxWorkflow = eLinuxWorkflow,
//         _logger = logger,
//         _processManager = processManager,
//         _processUtils =
//             ProcessUtils(logger: logger, processManager: processManager),
//         _eLinuxRemoteDevicesConfig = ELinuxRemoteDevicesConfig(
//           platform: globals.platform,
//           fileSystem: globals.fs,
//           logger: logger,
//         ),
//         super('eLinux devices');

//   final TvOSWorkflow _eLinuxWorkflow;
//   final Logger _logger;
//   final ProcessManager _processManager;
//   final ProcessUtils _processUtils;
//   final ELinuxRemoteDevicesConfig _eLinuxRemoteDevicesConfig;

//   @override
//   bool get supportsPlatform => _eLinuxWorkflow.appliesToHostPlatform;

//   @override
//   bool get canListAnything => _eLinuxWorkflow.canListDevices;

//   @override
//   Future<List<Device>> pollingGetDevices({Duration? timeout}) async {
//     if (!canListAnything) {
//       return const <Device>[];
//     }

//     final List<ELinuxDevice> devices = <ELinuxDevice>[];

//     // Adds current desktop host.
//     devices.add(
//       ELinuxDevice('elinux-wayland',
//           config: null,
//           desktop: true,
//           targetArch: _getCurrentHostPlatformArchName(),
//           backendType: 'wayland',
//           logger: _logger,
//           processManager: _processManager,
//           operatingSystemUtils: OperatingSystemUtils(
//             fileSystem: globals.fs,
//             logger: _logger,
//             platform: globals.platform,
//             processManager: const LocalProcessManager(),
//           )),
//     );
//     devices.add(
//       ELinuxDevice('elinux-x11',
//           config: null,
//           desktop: true,
//           targetArch: _getCurrentHostPlatformArchName(),
//           backendType: 'x11',
//           logger: _logger,
//           processManager: _processManager,
//           operatingSystemUtils: OperatingSystemUtils(
//             fileSystem: globals.fs,
//             logger: _logger,
//             platform: globals.platform,
//             processManager: const LocalProcessManager(),
//           )),
//     );

//     // Adds remote devices.
//     for (final ELinuxRemoteDeviceConfig remoteDevice
//         in _eLinuxRemoteDevicesConfig.devices) {
//       if (!remoteDevice.enabled) {
//         continue;
//       }

//       String stdout;
//       RunResult result;
//       try {
//         result = await _processUtils.run(remoteDevice.pingCommand,
//             throwOnError: true);
//         stdout = result.stdout.trim();
//       } on ProcessException catch (ex) {
//         _logger.printTrace('ping failed to list attached devices:\n$ex');
//         continue;
//       }

//       if (result.exitCode == 0 &&
//           stdout.contains(remoteDevice.pingSuccessRegex!)) {
//         final ELinuxDevice device = ELinuxDevice(remoteDevice.id,
//             config: remoteDevice,
//             desktop: false,
//             targetArch: remoteDevice.platform!,
//             backendType: remoteDevice.backend!,
//             sdkNameAndVersion: remoteDevice.sdkNameAndVersion,
//             logger: _logger,
//             processManager: _processManager,
//             operatingSystemUtils: OperatingSystemUtils(
//               fileSystem: globals.fs,
//               logger: _logger,
//               platform: globals.platform,
//               processManager: const LocalProcessManager(),
//             ));
//         devices.add(device);
//       }
//     }

//     return devices;
//   }

//   @override
//   Future<List<String>> getDiagnostics() async => const <String>[];

//   String _getCurrentHostPlatformArchName() {
//     final HostPlatform hostPlatform = getCurrentHostPlatform();
//     return getNameForHostPlatformArch(hostPlatform);
//   }

//   @override
//   List<String> get wellKnownIds => const <String>['tvos'];
// }
