import 'dart:ffi';

import 'package:desktop_client/services/winmm_joystick/internal/joycapsw.dart';
import 'package:win32/win32.dart';

import 'joyinfoex.dart';

typedef CjoyGetNumDevs = UINT Function();
typedef DartjoyGetNumDevs = int Function();

typedef CjoyGetPosEx = INT Function(UINT32, Pointer<JOYINFOEX>);
typedef DartjoyGetPosEx = int Function(int, Pointer<JOYINFOEX>);

typedef CjoyGetDevCapsW = UINT32 Function(UINT_PTR, Pointer<JOYCAPSW>, UINT);
typedef DartJoyGetDevCapsW = int Function(int, Pointer<JOYCAPSW>, int);
