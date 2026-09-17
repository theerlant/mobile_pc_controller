import 'dart:ffi';
import 'dart:io';

import 'package:desktop_client/services/vjoy/vjoy_interface_ref.dart' as ref;
import 'package:desktop_client/services/win32/win_messagebox.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:win32_registry/win32_registry.dart';

import 'ffi_typedef.dart';

class Vjoyinterface {
  late final DynamicLibrary _library;

  Vjoyinterface._internal() {
    _loadLibrary();
  }

  static final Vjoyinterface instance = Vjoyinterface._internal();

  /// Search and load the vJoyInterface.dll library
  void _loadLibrary() {
    late final RegistryKey key;
    try {
      key = LOCAL_MACHINE.open(
        r'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1',
      );
    } catch (err) {
      winMessageBox(
        message: "vJoy must be installed on this device!",
        uType: MB_STYLE_ERROR_OK,
      );
      exit(0); // Forcefully close the process
    }
    print("vJoy installation registry key found!");

    // Get dllx64 path
    final dllPath = key.getString('DllX64Location');
    if (dllPath == null) {
      winMessageBox(
        message: "Only 64bit version of vJoy is supported!",
        uType: MB_STYLE_ERROR_OK,
      );
      exit(0);
    }
    print("vJoy 64 bit dll path found!");

    // Try load and see if dll exist
    final file = File("$dllPath\\vJoyInterface.dll");
    if (!file.existsSync()) {
      winMessageBox(
        message:
            "Missing vJoyInterface.dll in \"${file.path}\". vJoy installation might be corrupt.",
        uType: MB_STYLE_WARNING_OK,
      );
      exit(0);
    }
    print("vJoyInterface.dll found in ${file.path}!");

    _library = DynamicLibrary.open(file.path);

    _registerMethods();
  }

  /// Register methods inside the library. Run after [_loadLibrary]
  void _registerMethods() {
    vJoyEnabled = _library.lookupFunction<CvJoyEnabled, DartvJoyEnabled>(
      ref.vJoyEnabled,
    );

    _getvJoyProductString = _library
        .lookupFunction<CGetvJoyProductString, DartGetvJoyProductString>(
          ref.getvJoyProductString,
        );

    _getvJoyManufacturerString = _library
        .lookupFunction<
          CGetvJoyManufacturerString,
          DartGetvJoyManufacturerString
        >(ref.getvJoyManufacturerString);

    _getvJoySerialNumberString = _library
        .lookupFunction<
          CGetvJoySerialNumberString,
          DartGetvJoySerialNumberString
        >(ref.getvJoySerialNumberString);

    _driverMatch = _library.lookupFunction<CDriverMatch, DartDriverMatch>(
      ref.driverMatch,
    );

    _getVJDStatus = _library.lookupFunction<CGetVJDStatus, DartGetVJDStatus>(
      ref.getVJDStatus,
    );

    isVJDExists = _library.lookupFunction<CisVJDExists, DartisVJDExists>(
      ref.isVJDExists,
    );

    acquireVJD = _library.lookupFunction<CAcquireVJD, DartAcquireVJD>(
      ref.acquireVJD,
    );

    relinquishVJD = _library.lookupFunction<CRelinquishVJD, DartRelinquishVJD>(
      ref.relinquishVJD,
    );

    _updateVJD = _library.lookupFunction<CUpdateVJD, DartUpdateVJD>(
      ref.updateVJD,
    );
  }

  // Special functions that return pointers or non primitive values
  late final CGetvJoyProductString _getvJoyProductString;
  late final CGetvJoyManufacturerString _getvJoyManufacturerString;
  late final CGetvJoySerialNumberString _getvJoySerialNumberString;
  late final DartDriverMatch _driverMatch;
  late final DartGetVJDStatus _getVJDStatus;
  late final DartUpdateVJD _updateVJD;

  // Helpers
  /// Safely cast PVoid into string returned from [nativeFunc]
  String? _getStringFromPVoid(CPVoidVoid nativeFunc) {
    final resultPtr = nativeFunc();

    if (resultPtr == nullptr) {
      return null;
    }

    final result = (resultPtr as Pointer<Utf16>).toDartString();
    return result;
  }

  // Public functions
  late final DartvJoyEnabled vJoyEnabled;
  late final DartGetvJoyVersion getvJoyVersion;

  String? getvJoyProductString() {
    return _getStringFromPVoid(_getvJoyProductString);
  }

  String? getvJoyManufacturerString() {
    return _getStringFromPVoid(_getvJoyManufacturerString);
  }

  String? getvJoySerialNumberString() {
    return _getStringFromPVoid(_getvJoySerialNumberString);
  }

  bool driverMatch(int dllVer, int drvVer) {
    final Pointer<WORD> dllVerPtr = calloc<WORD>();
    final Pointer<WORD> drvVerPtr = calloc<WORD>();

    dllVerPtr.value = dllVer;
    drvVerPtr.value = drvVer;

    return _driverMatch(dllVerPtr, drvVerPtr);
  }

  ref.VjdStat getVJDStatus(int rId) {
    final status = _getVJDStatus(rId);
    return ref.VjdStat.fromInt(status);
  }

  late final DartisVJDExists isVJDExists;
  late final DartAcquireVJD acquireVJD;
  late final DartRelinquishVJD relinquishVJD;
}
