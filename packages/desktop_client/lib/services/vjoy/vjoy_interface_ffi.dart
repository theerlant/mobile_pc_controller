import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'internal/ffi_typedef.dart';
import 'internal/vjoy_interface_ref.dart' as ref;
import 'internal/vjoy_interface_types.dart' as types;
import 'vjoy_error.dart';

/// Low-level FFI binding for vJoyInterface.dll
class VjoyInterfaceFFI {
  final DynamicLibrary library;

  /// Load vJoyInterface from a DynamicLibrary instance directly
  VjoyInterfaceFFI.fromLibrary(this.library) {
    _registerMethods();
  }

  /// Load vJoyInterface by providing the DLL file path.
  /// Throws [VjoyInterfaceMissing] if the file does not exist at [dllPath].
  factory VjoyInterfaceFFI.fromPath(String dllPath) {
    final file = File(dllPath);
    if (!file.existsSync()) {
      throw VjoyInterfaceMissing(dllPath);
    }
    return VjoyInterfaceFFI.fromLibrary(DynamicLibrary.open(file.path));
  }

  // Raw FFI function pointers / bindings
  late final DartvJoyEnabled vJoyEnabled;
  late final DartGetvJoyVersion getvJoyVersion;
  late final DartisVJDExists isVJDExists;
  late final DartAcquireVJD acquireVJD;
  late final DartRelinquishVJD relinquishVJD;
  late final DartGetVJDAxisExist getVJDAxisExist;

  // Functions with non-primitive returns / parameters requiring internal wrappers
  late final CGetvJoyProductString _getvJoyProductString;
  late final CGetvJoyManufacturerString _getvJoyManufacturerString;
  late final CGetvJoySerialNumberString _getvJoySerialNumberString;
  late final DartDriverMatch _driverMatch;
  late final DartGetVJDStatus _getVJDStatus;
  late final DartUpdateVJD _updateVJD;

  void _registerMethods() {
    vJoyEnabled = library.lookupFunction<CvJoyEnabled, DartvJoyEnabled>(
      ref.vJoyEnabled,
    );

    getvJoyVersion = library
        .lookupFunction<CGetvJoyVersion, DartGetvJoyVersion>(
          ref.getvJoyVersion,
        );

    _getvJoyProductString = library
        .lookupFunction<CGetvJoyProductString, DartGetvJoyProductString>(
          ref.getvJoyProductString,
        );

    _getvJoyManufacturerString = library
        .lookupFunction<
          CGetvJoyManufacturerString,
          DartGetvJoyManufacturerString
        >(ref.getvJoyManufacturerString);

    _getvJoySerialNumberString = library
        .lookupFunction<
          CGetvJoySerialNumberString,
          DartGetvJoySerialNumberString
        >(ref.getvJoySerialNumberString);

    _driverMatch = library.lookupFunction<CDriverMatch, DartDriverMatch>(
      ref.driverMatch,
    );

    _getVJDStatus = library.lookupFunction<CGetVJDStatus, DartGetVJDStatus>(
      ref.getVJDStatus,
    );

    isVJDExists = library.lookupFunction<CisVJDExists, DartisVJDExists>(
      ref.isVJDExists,
    );

    acquireVJD = library.lookupFunction<CAcquireVJD, DartAcquireVJD>(
      ref.acquireVJD,
    );

    relinquishVJD = library.lookupFunction<CRelinquishVJD, DartRelinquishVJD>(
      ref.relinquishVJD,
    );

    _updateVJD = library.lookupFunction<CUpdateVJD, DartUpdateVJD>(
      ref.updateVJD,
    );

    getVJDAxisExist = library
        .lookupFunction<CGetVJDAxisExist, DartGetVJDAxisExist>(
          ref.getVJDAxisExist,
        );
  }

  /// Safely cast PVoid into a Dart String returned from [nativeFunc]
  String? _getStringFromPVoid(CPVoidVoid nativeFunc) {
    final resultPtr = nativeFunc();
    if (resultPtr == nullptr) {
      return null;
    }
    return (resultPtr as Pointer<Utf16>).toDartString();
  }

  String? getvJoyProductString() {
    return _getStringFromPVoid(_getvJoyProductString);
  }

  String? getvJoyManufacturerString() {
    return _getStringFromPVoid(_getvJoyManufacturerString);
  }

  String? getvJoySerialNumberString() {
    return _getStringFromPVoid(_getvJoySerialNumberString);
  }

  ({bool match, int dllVer, int drvVer}) driverMatch() {
    final Pointer<WORD> dllVerPtr = calloc<WORD>();
    final Pointer<WORD> drvVerPtr = calloc<WORD>();
    try {
      final result = _driverMatch(dllVerPtr, drvVerPtr);
      return (match: result, dllVer: dllVerPtr.value, drvVer: drvVerPtr.value);
    } finally {
      calloc.free(dllVerPtr);
      calloc.free(drvVerPtr);
    }
  }

  types.VjdStat getVJDStatus(int rId) {
    final status = _getVJDStatus(rId);
    return types.VjdStat.fromInt(status);
  }

  bool updateVJD(int rId, Pointer<Void> pData) {
    return _updateVJD(rId, pData);
  }
}

/// Backwards compatibility alias
typedef VjoyinterfaceFFI = VjoyInterfaceFFI;
