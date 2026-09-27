import 'dart:ui';

import 'package:flutter/widgets.dart';

const int axisMinI = 0x0;
const int axisMaxI = 0x7FFFF;
const double axisMinD = 0x0;
const double axisMaxD = 0x7FFF;

class ControllerNotifier extends ChangeNotifier {
  double _axisX = 0.0;
  double _axisY = 0.0;
  double _axisZ = 0.0;
  double _axisRx = 0.0;
  double _axisRy = 0.0;
  double _axisRz = 0.0;
  double _axisSlider = 0.0;
  double _axisSlider2 = 0.0;

  int _buttons = 0;

  int _pov = -1;

  double get rawX => _axisX;
  int get x => (_axisX * axisMaxD).round();

  double get rawY => _axisY;
  int get y => (_axisY * axisMaxD).round();

  double get rawZ => _axisZ;
  int get z => (_axisZ * axisMaxD).round();

  double get rawRx => _axisRx;
  int get rx => (_axisRx * axisMaxD).round();

  double get rawRy => _axisRy;
  int get ry => (_axisRy * axisMaxD).round();

  double get rawRz => _axisRz;
  int get rz => (_axisRz * axisMaxD).round();

  double get rawSlider => _axisSlider;
  int get slider => (_axisSlider * axisMaxD).round();

  double get rawSlider2 => _axisSlider2;
  int get slider2 => (_axisSlider2 * axisMaxD).round();

  int get povHat => _pov;

  set rawX(double val) {
    _axisX = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set x(int val) {
    _axisX = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set rawY(double val) {
    _axisY = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set y(int val) {
    _axisY = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set rawZ(double val) {
    _axisZ = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set z(int val) {
    _axisZ = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set rawRx(double val) {
    _axisRx = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set rx(int val) {
    _axisRx = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set rawRy(double val) {
    _axisRy = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set ry(int val) {
    _axisRy = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set rawRz(double val) {
    _axisRz = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set rz(int val) {
    _axisRz = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set rawSlider(double val) {
    _axisSlider = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set slider(int val) {
    _axisSlider = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set rawSlider2(double val) {
    _axisSlider2 = clampDouble(val, 0, 1);
    notifyListeners();
  }

  set slider2(int val) {
    _axisSlider2 = clampDouble(val.toDouble(), axisMinD, axisMaxD) / axisMaxD;
    notifyListeners();
  }

  set povHat(int val) {
    _pov = val < 0 ? -1 : val.clamp(0, 35900);
    notifyListeners();
  }

  bool button(int index) {
    if (index < 1 || index > 32) {
      throw RangeError.range(
        index,
        1,
        32,
        'index',
        'Button index must be between 1 and 32.',
      );
    }
    return (_buttons & (1 << (index - 1))) != 0;
  }

  int get rawButtons => _buttons;

  set rawButtons(int val) {
    _buttons = val;
    notifyListeners();
  }

  void setButton(int index, bool state) {
    if (index < 1 || index > 32) {
      throw RangeError.range(
        index,
        1,
        32,
        'index',
        'Button index must be between 1 and 32.',
      );
    }
    if (state) {
      _buttons |= (1 << (index - 1));
    } else {
      _buttons &= ~(1 << (index - 1));
    }
    notifyListeners();
  }
}
