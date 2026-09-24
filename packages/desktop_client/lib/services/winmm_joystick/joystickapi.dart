import 'dart:ffi';

import 'package:desktop_client/services/winmm_joystick/internal/joystickapi_typedef.dart';

class Joystickapi {
  late final DynamicLibrary _winmm;

  late final DartjoyGetNumDevs getNumDevs;
  late final DartjoyGetPosEx getPosEx;
  late final DartJoyGetDevCapsW getDevCapsW;

  Joystickapi() {
    _winmm = DynamicLibrary.open("winmm.dll");

    getNumDevs = _winmm.lookupFunction<CjoyGetNumDevs, DartjoyGetNumDevs>(
      'joyGetNumDevs',
    );
    getPosEx = _winmm.lookupFunction<CjoyGetPosEx, DartjoyGetPosEx>(
      'joyGetPosEx',
    );
    getDevCapsW = _winmm.lookupFunction<CjoyGetDevCapsW, DartJoyGetDevCapsW>(
      'joyGetDevCapsW',
    );
  }
}
