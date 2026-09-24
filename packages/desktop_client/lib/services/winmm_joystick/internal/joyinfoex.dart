import 'dart:ffi';

import 'package:win32/win32.dart';

final class JOYINFOEX extends Struct {
  @DWORD()
  external int dwSize;
  @DWORD()
  external int dwFlags;
  @DWORD()
  external int dwXpos;
  @DWORD()
  external int dwYpos;
  @DWORD()
  external int dwZpos;
  @DWORD()
  external int dwRpos;
  @DWORD()
  external int dwUpos;
  @DWORD()
  external int dwVpos;
  @DWORD()
  external int dwButtons;
  @DWORD()
  external int dwButtonNumber;
  @DWORD()
  external int dwPOV;
  @DWORD()
  external int dwReserved1;
  @DWORD()
  external int dwReserved2;
}
