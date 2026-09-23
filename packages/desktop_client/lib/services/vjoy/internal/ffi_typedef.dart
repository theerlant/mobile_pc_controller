import 'dart:ffi';

import 'package:win32/win32.dart';

// Generics
typedef CBoolUint = Bool Function(UINT arg);
typedef DartBoolUint = bool Function(int arg);

typedef CPVoidVoid = PVOID Function();
typedef DartPVoidVoid = PVOID Function();

// Helper
typedef CvJoyEnabled = Bool Function();
typedef DartvJoyEnabled = bool Function();

typedef CGetvJoyVersion = SHORT Function();
typedef DartGetvJoyVersion = int Function();

typedef CGetvJoyProductString = CPVoidVoid;
typedef DartGetvJoyProductString = DartPVoidVoid;

typedef CGetvJoyManufacturerString = CPVoidVoid;
typedef DartGetvJoyManufacturerString = DartPVoidVoid;

typedef CGetvJoySerialNumberString = CPVoidVoid;
typedef DartGetvJoySerialNumberString = DartPVoidVoid;

typedef CDriverMatch = Bool Function(
  Pointer<WORD> dllVer,
  Pointer<WORD> drvVer,
);
typedef DartDriverMatch = bool Function(
  Pointer<WORD> dllVer,
  Pointer<WORD> drvVer,
);

typedef CGetVJDStatus = Int32 Function(UINT rId);
typedef DartGetVJDStatus = int Function(int rId);

/// BOOL isVJDExists(UINT rID)
typedef CisVJDExists = CBoolUint;
typedef DartisVJDExists = DartBoolUint;

/// BOOL AcquireVJD(UINT rID)
typedef CAcquireVJD = CBoolUint;
typedef DartAcquireVJD = DartBoolUint;

/// VOID RelinquishVJD(UINT rID)
typedef CRelinquishVJD = Void Function(UINT rId);
typedef DartRelinquishVJD = void Function(int rId);

/// BOOL UpdateVJD(UINT rID, PVOID pData)
typedef CUpdateVJD = Bool Function(UINT rId, PVOID pData);
typedef DartUpdateVJD = bool Function(int rId, PVOID pData);

typedef CGetVJDAxisExist = Bool Function(UINT rId, UINT axis);
typedef DartGetVJDAxisExist = bool Function(int rId, int axis);
