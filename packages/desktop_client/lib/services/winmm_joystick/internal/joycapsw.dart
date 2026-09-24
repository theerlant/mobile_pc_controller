// ignore_for_file: constant_identifier_names

import 'dart:ffi';

import 'package:win32/win32.dart';

const int MAXPNAMELEN = 32;
const int MAX_JOYSTICKOEMVXDNAME = 260;

const JOYCAPS_HASZ = 0x0001;
const JOYCAPS_HASR = 0x0002;
const JOYCAPS_HASU = 0x0004;
const JOYCAPS_HASV = 0x0008;
const JOYCAPS_HASPOV = 0x0010;
const JOYCAPS_POV4DIR = 0x0020;
const JOYCAPS_POVCTS = 0x0040;

final class JOYCAPSW extends Struct {
  @WORD()
  external int wMid;
  @WORD()
  external int wPid;
  @Array(MAXPNAMELEN)
  external Array<Uint16> szPname;
  @WORD()
  external int wXmin;
  @UINT()
  external int wXmax;
  @UINT()
  external int wYmin;
  @UINT()
  external int wYmax;
  @UINT()
  external int wZmin;
  @UINT()
  external int wZmax;
  @UINT()
  external int wNumButtons;
  @UINT()
  external int wPeriodMin;
  @UINT()
  external int wPeriodMax;
  @UINT()
  external int wRmin;
  @UINT()
  external int wRmax;
  @UINT()
  external int wUmin;
  @UINT()
  external int wUmax;
  @UINT()
  external int wVmin;
  @UINT()
  external int wVmax;
  @UINT()
  external int wCaps;
  @UINT()
  external int wMaxAxes;
  @UINT()
  external int wNumAxes;
  @UINT()
  external int wMaxButtons;
  @Array(MAXPNAMELEN)
  external Array<Uint16> szRegKey;
  @Array(MAX_JOYSTICKOEMVXDNAME)
  external Array<Uint16> szOEMVxD;
}
