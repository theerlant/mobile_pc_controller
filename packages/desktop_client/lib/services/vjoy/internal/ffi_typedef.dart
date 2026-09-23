import 'dart:ffi';

import 'package:win32/win32.dart';

// ---- Generics ----
typedef CBoolUint = Bool Function(UINT arg);
typedef DartBoolUint = bool Function(int arg);

typedef CPVoidVoid = PVOID Function();
typedef DartPVoidVoid = PVOID Function();

typedef CIntUint = Int Function(UINT arg);
typedef DartIntUint = int Function(int arg);

// General Driver Data
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

// ---- Write Access to vJoy Driver
typedef CGetVJDStatus = Int32 Function(UINT rId);
typedef DartGetVJDStatus = int Function(int rId);

typedef CisVJDExists = CBoolUint;
typedef DartisVJDExists = DartBoolUint;

typedef CGetOwnerPID = CIntUint;
typedef DartGetOwnerPID = DartIntUint;

typedef CAcquireVJD = CBoolUint;
typedef DartAcquireVJD = DartBoolUint;

typedef CRelinquishVJD = Void Function(UINT rId);
typedef DartRelinquishVJD = void Function(int rId);

typedef CUpdateVJD = Bool Function(UINT rId, PVOID pData);
typedef DartUpdateVJD = bool Function(int rId, PVOID pData);

// --- vJoy Device Properties ---
typedef CGetVJDAxisExist = Bool Function(UINT rId, UINT axis);
typedef DartGetVJDAxisExist = bool Function(int rId, int axis);

typedef CGetVJDItemNumber = CIntUint;
typedef DartGetVJDItemNumber = DartIntUint;

// --- Robust Write Access API ---
typedef CResetVJD = CBoolUint;
typedef DartResetVJD = DartBoolUint;

typedef CResetAll = Bool Function();
typedef DartResetAll = bool Function();

typedef CResetButtons = CBoolUint;
typedef DartResetButtons = DartBoolUint;

typedef CResetPovs = CBoolUint;
typedef DartResetPovs = DartBoolUint;

typedef CSetAxis = Bool Function(LONG value, UINT rId, UINT axis);
typedef DartSetAxis = bool Function(int value, int rId, int axis);

typedef CSetBtn = Bool Function(Bool value, UINT rId, UCHAR nBtn);
typedef DartSetBtn = bool Function(bool value, int rId, int nBtn);

typedef CSetDiscPov = Bool Function(Int value, UINT rId, UCHAR nPov);
typedef DartSetDiscPov = bool Function(int value, int rId, int nPov);

typedef CSetContPov = Bool Function(DWORD value, UINT rId, UCHAR nPov);
typedef DartSetContPov = bool Function(int value, int rId, int nPov);
