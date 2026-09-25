import 'dart:async';
import 'dart:io';

import 'package:desktop_client/utils/win32/run_as_admin.dart';
import 'package:win32_registry/win32_registry.dart';

import 'internal/vjoy_interface_types.dart';
import 'vjoy_device.dart';
import 'vjoy_error.dart';
import 'vjoy_interface_ffi.dart';

export 'internal/vjoy_interface_types.dart';
export 'vjoy_device.dart';
export 'vjoy_error.dart';
export 'vjoy_interface_ffi.dart';

/// High-level vJoy service, device manager, and discovery provider.
class Vjoy {
  static const String uninstallRegistryPath =
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1';
  static const String dllX64LocationKey = 'DllX64Location';
  static const String dllFileName = 'vJoyInterface.dll';

  /// Directory containing the 64-bit vJoy binaries/DLLs.
  final String dllLocation;

  /// Absolute file path to vJoyInterface.dll.
  final String dllPath;

  /// Low-level FFI interface wrapper.
  final VjoyInterfaceFFI ffi;

  Vjoy._({
    required this.dllLocation,
    required this.dllPath,
    required this.ffi,
  });

  /// Path to the vJoy configuration utility executable (`vJoyConfig.exe`).
  String get configExePath => '$dllLocation\\vJoyConfig.exe';

  /// Locate the 64-bit vJoy DLL directory from the Windows registry.
  /// Throws [VjoyNotInstalled] if the registry key is absent.
  /// Throws [VjoyArchUnsupported] if 64-bit DLL path is absent.
  static String findDllLocation() {
    late final RegistryKey key;
    try {
      key = LOCAL_MACHINE.open(uninstallRegistryPath);
    } catch (_) {
      throw const VjoyNotInstalled();
    }

    final dllLocation = key.getString(dllX64LocationKey);
    if (dllLocation == null || dllLocation.trim().isEmpty) {
      throw const VjoyArchUnsupported();
    }

    return dllLocation;
  }

  /// Initialize vJoy by scanning the Windows registry for the installation path.
  /// Throws [VjoyNotInstalled], [VjoyArchUnsupported], or [VjoyInterfaceMissing].
  factory Vjoy.fromRegistry() {
    final location = findDllLocation();
    final dllPath = '$location\\$dllFileName';
    final ffi = VjoyInterfaceFFI.fromPath(dllPath);

    return Vjoy._(
      dllLocation: location,
      dllPath: dllPath,
      ffi: ffi,
    );
  }

  /// Initialize vJoy from a custom directory location or DLL path.
  factory Vjoy.fromLocation(String directoryPath) {
    final dllPath = '$directoryPath\\$dllFileName';
    final ffi = VjoyInterfaceFFI.fromPath(dllPath);

    return Vjoy._(
      dllLocation: directoryPath,
      dllPath: dllPath,
      ffi: ffi,
    );
  }

  // ==========================================
  // Driver Status & Descriptors
  // ==========================================

  /// Returns `true` if the vJoy driver is enabled and functioning.
  bool get isEnabled => ffi.vJoyEnabled();

  /// Returns the vJoy driver version number (BCD format, e.g. 0x219 for v2.1.9).
  int get version => ffi.getvJoyVersion();

  /// Returns driver and DLL version match validation details.
  ({bool match, int dllVer, int drvVer}) get driverMatch => ffi.driverMatch();

  /// Product string descriptor (e.g. "vJoy - Virtual Joystick").
  String? get productString => ffi.getvJoyProductString();

  /// Manufacturer string descriptor (e.g. "Shaul Eizikovich").
  String? get manufacturerString => ffi.getvJoyManufacturerString();

  /// Serial number / version string descriptor.
  String? get serialNumberString => ffi.getvJoySerialNumberString();

  // ==========================================
  // Device Discovery & Access
  // ==========================================

  /// Gets a [VjoyDevice] instance for [deviceId] (1 to 16).
  VjoyDevice getDevice(int deviceId) {
    return VjoyDevice(this, deviceId);
  }

  /// Gets a [VjoyDevice] for [deviceId] and immediately acquires ownership.
  ///
  /// Throws [VjoyDeviceAcquisitionFailed] if acquisition fails (e.g. device missing or busy).
  VjoyDevice acquireDevice(int deviceId) {
    final device = getDevice(deviceId);
    if (!device.acquire()) {
      throw VjoyDeviceAcquisitionFailed(deviceId);
    }
    return device;
  }

  /// Returns the list of 1-based device IDs (1..16) that currently exist.
  List<int> getExistingDeviceIds() {
    final result = <int>[];
    for (var id = 1; id <= 16; id++) {
      if (ffi.isVJDExists(id)) {
        result.add(id);
      }
    }
    return result;
  }

  /// Returns a list of [VjoyDevice] instances for all currently configured devices.
  List<VjoyDevice> getExistingDevices() {
    return getExistingDeviceIds().map(getDevice).toList();
  }

  /// Resets all controls across all vJoy devices.
  void resetAll() {
    ffi.resetAll();
  }

  // ==========================================
  // Driver & Device Configuration (vJoyConfig)
  // ==========================================

  /// Runs `vJoyConfig.exe` with the given [parameters].
  ///
  /// If [asAdmin] is true (default), launches the process elevated via Windows UAC.
  /// If [asAdmin] is false, executes as a standard child process.
  Future<bool> runConfigCommand(String parameters, {bool asAdmin = true}) async {
    final configExe = File(configExePath);
    if (!configExe.existsSync()) {
      throw VjoyInterfaceMissing(configExePath);
    }

    if (asAdmin) {
      return runAsAdmin(configExePath, parameters: parameters);
    } else {
      final parts = parameters
          .split(' ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final result = await Process.run(configExePath, parts);
      if (result.exitCode != 0) {
        throw VjoyConfigException(result.stderr.toString(), result.exitCode);
      }
      return true;
    }
  }

  /// Enables or disables the vJoy driver using `vJoyConfig.exe enable [on|off]`.
  Future<bool> enableDriver({bool on = true, bool asAdmin = true}) {
    return runConfigCommand('enable ${on ? 'on' : 'off'}', asAdmin: asAdmin);
  }

  /// Disables the vJoy driver using `vJoyConfig.exe enable off`.
  Future<bool> disableDriver({bool asAdmin = true}) {
    return enableDriver(on: false, asAdmin: asAdmin);
  }

  /// Resets vJoy back to the default configuration using `vJoyConfig.exe -r`.
  Future<bool> resetToDefaultConfiguration({bool asAdmin = true}) {
    return runConfigCommand('-r', asAdmin: asAdmin);
  }

  /// Deletes a specific vJoy device (1..16) using `vJoyConfig.exe -d <deviceId>`.
  Future<bool> deleteDevice(int deviceId, {bool asAdmin = true}) {
    if (deviceId < 1 || deviceId > 16) {
      throw VjoyDeviceInvalid(deviceId);
    }
    return runConfigCommand('-d $deviceId', asAdmin: asAdmin);
  }

  /// Deletes multiple vJoy devices using `vJoyConfig.exe -d <id1> <id2> ...`.
  Future<bool> deleteDevices(List<int> deviceIds, {bool asAdmin = true}) {
    for (final id in deviceIds) {
      if (id < 1 || id > 16) throw VjoyDeviceInvalid(id);
    }
    return runConfigCommand('-d ${deviceIds.join(' ')}', asAdmin: asAdmin);
  }

  /// Creates or reconfigures a vJoy device (1..16) with specific axes, buttons, POVs, and FFB.
  ///
  /// - [deviceId]: Target device index (1-16).
  /// - [axes]: List of enabled [Axis] (default is all axes if null).
  /// - [numButtons]: Number of buttons (1-128, default = 8).
  /// - [numAnalogPovs]: Number of continuous POV switches (0-4, default = 0).
  /// - [numDiscretePovs]: Number of discrete 4-direction POV switches (0-4, default = 0).
  /// - [ffbEffects]: List of supported force feedback effects (or empty for none).
  /// - [force]: If true (`-f`), overwrites the existing device configuration.
  /// - [asAdmin]: Elevated execution (default = true).
  Future<bool> configureDevice(
    int deviceId, {
    List<Axis>? axes,
    int? numButtons,
    int? numAnalogPovs,
    int? numDiscretePovs,
    List<FfbEffect>? ffbEffects,
    bool force = true,
    bool asAdmin = true,
  }) {
    if (deviceId < 1 || deviceId > 16) {
      throw VjoyDeviceInvalid(deviceId);
    }

    final buffer = StringBuffer('$deviceId');
    if (force) {
      buffer.write(' -f');
    }

    if (axes != null && axes.isNotEmpty) {
      final axisArgs = axes.map(_axisToArg).where((s) => s.isNotEmpty).join(' ');
      if (axisArgs.isNotEmpty) {
        buffer.write(' -a $axisArgs');
      }
    }

    if (numButtons != null) {
      buffer.write(' -b $numButtons');
    }

    if (numAnalogPovs != null) {
      buffer.write(' -p $numAnalogPovs');
    }

    if (numDiscretePovs != null) {
      buffer.write(' -s $numDiscretePovs');
    }

    if (ffbEffects != null && ffbEffects.isNotEmpty) {
      final ffbArgs = ffbEffects.map(_ffbToArg).join(' ');
      buffer.write(' -e $ffbArgs');
    }

    return runConfigCommand(buffer.toString(), asAdmin: asAdmin);
  }

  static String _axisToArg(Axis axis) {
    switch (axis) {
      case Axis.X:
        return 'x';
      case Axis.Y:
        return 'y';
      case Axis.Z:
        return 'z';
      case Axis.RX:
        return 'rx';
      case Axis.RY:
        return 'ry';
      case Axis.RZ:
        return 'rz';
      case Axis.SL0:
        return 'sl0';
      case Axis.SL1:
        return 'sl1';
      case Axis.WHL:
        return 'whl';
      case Axis.POV:
        return 'pov';
      case Axis.UNKN:
        return '';
    }
  }

  static String _ffbToArg(FfbEffect effect) {
    switch (effect) {
      case FfbEffect.Const:
        return 'Const';
      case FfbEffect.Ramp:
        return 'Ramp';
      case FfbEffect.Squr:
        return 'Sq';
      case FfbEffect.Sine:
        return 'Sine';
      case FfbEffect.Trng:
        return 'Tr';
      case FfbEffect.Stup:
        return 'StUp';
      case FfbEffect.Stdn:
        return 'StDn';
      case FfbEffect.Sprng:
        return 'Spr';
      case FfbEffect.Dmpr:
        return 'Dm';
      case FfbEffect.Inrt:
        return 'Inr';
      case FfbEffect.Fric:
        return 'Fric';
    }
  }
}
