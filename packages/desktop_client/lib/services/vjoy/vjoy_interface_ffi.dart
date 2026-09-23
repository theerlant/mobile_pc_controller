import 'dart:ffi';
import 'dart:io';

import 'package:desktop_client/services/vjoy/vjoy.dart';
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

  // Functions with non-primitive returns / parameters requiring internal wrappers
  late final CGetvJoyProductString _getvJoyProductString;
  late final CGetvJoyManufacturerString _getvJoyManufacturerString;
  late final CGetvJoySerialNumberString _getvJoySerialNumberString;
  late final DartDriverMatch _driverMatch;
  late final DartGetVJDStatus _getVJDStatus;
  late final DartGetOwnerPID _getOwnerPID;
  late final DartUpdateVJD _updateVJD;
  late final DartGetVJDAxisExist _getVJDAxisExist;
  late final DartSetAxis _setAxis;

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

    _getOwnerPID = library.lookupFunction<CGetOwnerPID, DartGetOwnerPID>(
      ref.getOwnerPid,
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

    getVJDButtonNumber = library
        .lookupFunction<CGetVJDItemNumber, DartGetVJDItemNumber>(
          ref.getVJDButtonNumber,
        );

    getVJDDiscPovNumber = library
        .lookupFunction<CGetVJDItemNumber, DartGetVJDItemNumber>(
          ref.getVJDDiscPovNumber,
        );

    getVJDContPovNumber = library
        .lookupFunction<CGetVJDItemNumber, DartGetVJDItemNumber>(
          ref.getVJDContPovNumber,
        );

    _getVJDAxisExist = library
        .lookupFunction<CGetVJDAxisExist, DartGetVJDAxisExist>(
          ref.getVJDAxisExist,
        );

    resetVJD = library.lookupFunction<CResetVJD, DartResetVJD>(ref.resetVJD);
    resetAll = library.lookupFunction<CResetAll, DartResetAll>(ref.resetAll);
    resetButtons = library.lookupFunction<CResetVJD, DartResetVJD>(
      ref.resetButtons,
    );
    resetPovs = library.lookupFunction<CResetVJD, DartResetVJD>(ref.resetPovs);
    _setAxis = library.lookupFunction<CSetAxis, DartSetAxis>(ref.setAxis);
    setBtn = library.lookupFunction<CSetBtn, DartSetBtn>(ref.setBtn);
    setDiscPov = library.lookupFunction<CSetDiscPov, DartSetDiscPov>(
      ref.setDiscPov,
    );
    setContPov = library.lookupFunction<CSetContPov, DartSetContPov>(
      ref.setContPov,
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

  // ---- Actual Callable Methods ---
  // ---- General Driver Data ----
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

  // ---- Write access to vJoy Device
  types.VjdStat getVJDStatus(int rId) {
    final status = _getVJDStatus(rId);
    return types.VjdStat.fromInt(status);
  }

  late final DartisVJDExists isVJDExists;

  (types.OwnerPID, int) getOwnerPid(int rId) {
    final result = _getOwnerPID(rId);
    return (OwnerPID.fromInt(result), result);
  }

  late final DartAcquireVJD acquireVJD;
  late final DartRelinquishVJD relinquishVJD;

  bool updateVJD(int rId, Pointer<Void> pData) {
    return _updateVJD(rId, pData);
  }

  // ---- vJoy Device properties
  late final DartGetVJDItemNumber getVJDButtonNumber;
  late final DartGetVJDItemNumber getVJDDiscPovNumber;
  late final DartGetVJDItemNumber getVJDContPovNumber;

  bool getVJDAxisExist(int rId, types.Axis axis) {
    return _getVJDAxisExist(rId, axis.value);
  }

  // ---- Robust write access to vJoy Devices
  late final DartResetVJD resetVJD;
  late final DartResetAll resetAll;
  late final DartResetButtons resetButtons;
  late final DartResetPovs resetPovs;

  bool setAxis(int value, int rId, types.Axis axis) {
    return _setAxis(value, rId, axis.value);
  }

  late final DartSetBtn setBtn;
  late final DartSetDiscPov setDiscPov;
  late final DartSetContPov setContPov;
}

/// Backwards compatibility alias
typedef VjoyinterfaceFFI = VjoyInterfaceFFI;
