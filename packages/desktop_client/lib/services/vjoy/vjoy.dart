import 'package:win32_registry/win32_registry.dart';

import 'vjoy_error.dart';
import 'vjoy_interface_ffi.dart';

export 'internal/vjoy_interface_types.dart';
export 'vjoy_error.dart';
export 'vjoy_interface_ffi.dart';

/// High-level vJoy service and discovery manager
class Vjoy {
  static const String uninstallRegistryPath =
      r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1';
  static const String dllX64LocationKey = 'DllX64Location';
  static const String dllFileName = 'vJoyInterface.dll';

  /// Directory containing the 64-bit vJoy binaries/DLLs
  final String dllLocation;

  /// Absolute file path to vJoyInterface.dll
  final String dllPath;

  /// Low-level FFI interface wrapper
  final VjoyInterfaceFFI ffi;

  Vjoy._({
    required this.dllLocation,
    required this.dllPath,
    required this.ffi,
  });

  /// Path to the vJoy configuration utility executable
  String get configExePath => '$dllLocation\\vJoyConfig.exe';

  /// Locate the 64-bit vJoy DLL directory from the Windows registry.
  /// Throws [VjoyNotInstalled] if registry key is absent.
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
}
