import 'dart:async';
import 'dart:ffi';

import 'package:desktop_client/services/winmm_joystick/internal/dwFlags.dart';
import 'package:desktop_client/services/winmm_joystick/internal/joycapsw.dart';
import 'package:desktop_client/services/winmm_joystick/internal/joyinfoex.dart';
import 'package:desktop_client/services/winmm_joystick/internal/mmresult.dart';
import 'package:ffi/ffi.dart';

import 'internal/joystickapi.dart';

export 'package:desktop_client/services/winmm_joystick/internal/dwFlags.dart';
export 'package:desktop_client/services/winmm_joystick/internal/joycapsw.dart'
    show
        JOYCAPS_HASPOV,
        JOYCAPS_HASR,
        JOYCAPS_HASU,
        JOYCAPS_HASV,
        JOYCAPS_HASZ,
        JOYCAPS_POV4DIR,
        JOYCAPS_POVCTS;
export 'package:desktop_client/services/winmm_joystick/internal/mmresult.dart';

export 'internal/joystickapi.dart';

typedef DeviceResult = ({int deviceId, int vendorId, int productId});

/// Checks whether the given device is a vJoy device.
bool isVjoyDevice(DeviceResult device) {
  return device.vendorId == 0x1234 && device.productId == 0xBEAD;
}

/// Represents an exception thrown during WinMM joystick API calls.
class JoystickException implements Exception {
  final int errorCode;
  final String message;

  const JoystickException(this.errorCode, this.message);

  factory JoystickException.fromErrorCode(int code, [String? context]) {
    final prefix = context != null ? '$context: ' : '';
    switch (code) {
      case MMSYSERR_BADDEVICEID:
        return JoystickException(
          code,
          '${prefix}Specified joystick device identifier is invalid (MMSYSERR_BADDEVICEID).',
        );
      case MMSYSERR_NODRIVER:
        return JoystickException(
          code,
          '${prefix}Joystick driver is not present (MMSYSERR_NODRIVER).',
        );
      case MMSYSERR_INVALIDPARAM:
        return JoystickException(
          code,
          '${prefix}Invalid parameter passed (MMSYSERR_INVALIDPARAM).',
        );
      case JOYERR_PARMS:
        return JoystickException(
          code,
          '${prefix}Invalid parameter passed to joystick subsystem (JOYERR_PARMS).',
        );
      case JOYERR_UNPLUGGED:
        return JoystickException(
          code,
          '${prefix}Joystick is unplugged or not connected (JOYERR_UNPLUGGED).',
        );
      case MMSYSERR_ERROR:
        return JoystickException(
          code,
          '${prefix}General MMSYSERR_ERROR failure.',
        );
      default:
        return JoystickException(
          code,
          '${prefix}Joystick API error code: $code',
        );
    }
  }

  @override
  String toString() => 'JoystickException: $message (code: $errorCode)';
}

/// Detailed capabilities for a joystick device.
class JoystickCaps {
  final int deviceId;
  final int vendorId;
  final int productId;
  final String productName;
  final String regKey;
  final String oemVxD;
  final int xMin;
  final int xMax;
  final int yMin;
  final int yMax;
  final int zMin;
  final int zMax;
  final int rMin;
  final int rMax;
  final int uMin;
  final int uMax;
  final int vMin;
  final int vMax;
  final int numButtons;
  final int maxButtons;
  final int numAxes;
  final int maxAxes;
  final int periodMin;
  final int periodMax;
  final int caps;

  const JoystickCaps({
    required this.deviceId,
    required this.vendorId,
    required this.productId,
    required this.productName,
    required this.regKey,
    required this.oemVxD,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.zMin,
    required this.zMax,
    required this.rMin,
    required this.rMax,
    required this.uMin,
    required this.uMax,
    required this.vMin,
    required this.vMax,
    required this.numButtons,
    required this.maxButtons,
    required this.numAxes,
    required this.maxAxes,
    required this.periodMin,
    required this.periodMax,
    required this.caps,
  });

  bool get hasZ => (caps & JOYCAPS_HASZ) != 0;
  bool get hasR => (caps & JOYCAPS_HASR) != 0;
  bool get hasU => (caps & JOYCAPS_HASU) != 0;
  bool get hasV => (caps & JOYCAPS_HASV) != 0;
  bool get hasPov => (caps & JOYCAPS_HASPOV) != 0;
  bool get isPov4Dir => (caps & JOYCAPS_POV4DIR) != 0;
  bool get isPovContinuous => (caps & JOYCAPS_POVCTS) != 0;
  bool get isVjoy => vendorId == 0x1234 && productId == 0xBEAD;

  DeviceResult toDeviceResult() =>
      (deviceId: deviceId, vendorId: vendorId, productId: productId);

  @override
  String toString() =>
      'JoystickCaps(deviceId: $deviceId, vendorId: 0x${vendorId.toRadixString(16)}, '
      'productId: 0x${productId.toRadixString(16)}, productName: "$productName", '
      'buttons: $numButtons, axes: $numAxes)';
}

/// Represents the current position and button state of a joystick.
class JoystickPosition {
  final int flags;
  final int x;
  final int y;
  final int z;
  final int r;
  final int u;
  final int v;
  final int buttons;
  final int buttonNumber;
  final int pov;

  const JoystickPosition({
    required this.flags,
    required this.x,
    required this.y,
    required this.z,
    required this.r,
    required this.u,
    required this.v,
    required this.buttons,
    required this.buttonNumber,
    required this.pov,
  });

  /// True if POV hat is in centered / neutral position.
  bool get isPovCentered => pov == 0xFFFF || pov == 65535 || pov == -1;

  /// Returns POV hat angle in degrees (0.0 to 359.99), or null if centered.
  double? get povAngleDegrees => isPovCentered ? null : pov / 100.0;

  /// Check if a button (1-indexed, 1..32) is pressed.
  bool isButtonPressed(int buttonNumber1Based) {
    if (buttonNumber1Based < 1 || buttonNumber1Based > 32) return false;
    return (buttons & (1 << (buttonNumber1Based - 1))) != 0;
  }

  /// Check if a button (0-indexed, 0..31) is pressed.
  bool isButtonIndexPressed(int buttonIndex0Based) {
    if (buttonIndex0Based < 0 || buttonIndex0Based >= 32) return false;
    return (buttons & (1 << buttonIndex0Based)) != 0;
  }

  /// List of pressed button numbers (1-indexed).
  List<int> get pressedButtons {
    final pressed = <int>[];
    for (var i = 0; i < 32; i++) {
      if ((buttons & (1 << i)) != 0) {
        pressed.add(i + 1);
      }
    }
    return pressed;
  }

  @override
  String toString() =>
      'JoystickPosition(x: $x, y: $y, z: $z, r: $r, u: $u, v: $v, '
      'buttons: 0x${buttons.toRadixString(16)}, pov: $pov)';
}

/// Higher level API for winmm joystick implementation on [JoystickApi]
class Joystick {
  final JoystickApi _joy;
  final bool _ownsJoyApi;

  final Pointer<JOYCAPSW> _caps = calloc<JOYCAPSW>();
  final int _capsSize = sizeOf<JOYCAPSW>();

  final Pointer<JOYINFOEX> _info = calloc<JOYINFOEX>();
  final int _infoSize = sizeOf<JOYINFOEX>();

  bool _isDisposed = false;

  Joystick({JoystickApi? joystickApi})
    : _joy = joystickApi ?? JoystickApi(),
      _ownsJoyApi = joystickApi == null;

  /// Total number of joystick devices supported by the driver.
  int get numDevices {
    _checkDisposed();
    return _joy.getNumDevs();
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Joystick instance has been disposed.');
    }
  }

  static String _extractWString(Array<Uint16> array, int maxLength) {
    final units = <int>[];
    for (var i = 0; i < maxLength; i++) {
      final code = array[i];
      if (code == 0) break;
      units.add(code);
    }
    return String.fromCharCodes(units);
  }

  /// Releases native memory resources allocated by this Joystick instance.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    calloc.free(_caps);
    calloc.free(_info);
    if (_ownsJoyApi) {
      _joy.dispose();
    }
  }

  /// Find all valid joysticks and return their id, vendor id, and product id.
  List<DeviceResult> findDevices() {
    _checkDisposed();
    final devices = <DeviceResult>[];
    final maxDevs = _joy.getNumDevs();
    for (var id = 0; id < maxDevs; id++) {
      final result = _joy.getDevCapsW(id, _caps, _capsSize);
      if (result == JOYERR_NOERROR) {
        devices.add((
          deviceId: id,
          vendorId: _caps.ref.wMid,
          productId: _caps.ref.wPid,
        ));
      }
    }

    return devices;
  }

  /// Returns whether a device with [deviceId] is currently connected.
  bool isConnected(int deviceId) {
    _checkDisposed();
    final result = _joy.getDevCapsW(deviceId, _caps, _capsSize);
    return result == JOYERR_NOERROR;
  }

  /// Retrieves the capabilities of the joystick specified by [deviceId].
  /// Returns `null` if the device is unplugged, invalid, or not present.
  JoystickCaps? getCaps(int deviceId) {
    _checkDisposed();
    final result = _joy.getDevCapsW(deviceId, _caps, _capsSize);
    if (result == JOYERR_UNPLUGGED ||
        result == JOYERR_PARMS ||
        result == MMSYSERR_NODRIVER ||
        result == MMSYSERR_BADDEVICEID) {
      return null;
    }
    if (result != JOYERR_NOERROR) {
      throw JoystickException.fromErrorCode(
        result,
        'Failed to getDevCapsW for device $deviceId',
      );
    }

    final ref = _caps.ref;
    return JoystickCaps(
      deviceId: deviceId,
      vendorId: ref.wMid,
      productId: ref.wPid,
      productName: _extractWString(ref.szPname, MAXPNAMELEN),
      regKey: _extractWString(ref.szRegKey, MAXPNAMELEN),
      oemVxD: _extractWString(ref.szOEMVxD, MAX_JOYSTICKOEMVXDNAME),
      xMin: ref.wXmin,
      xMax: ref.wXmax,
      yMin: ref.wYmin,
      yMax: ref.wYmax,
      zMin: ref.wZmin,
      zMax: ref.wZmax,
      rMin: ref.wRmin,
      rMax: ref.wRmax,
      uMin: ref.wUmin,
      uMax: ref.wUmax,
      vMin: ref.wVmin,
      vMax: ref.wVmax,
      numButtons: ref.wNumButtons,
      maxButtons: ref.wMaxButtons,
      numAxes: ref.wNumAxes,
      maxAxes: ref.wMaxAxes,
      periodMin: ref.wPeriodMin,
      periodMax: ref.wPeriodMax,
      caps: ref.wCaps,
    );
  }

  /// Retrieves the capabilities of the joystick specified by [deviceId],
  /// or throws [JoystickException] if not available.
  JoystickCaps getCapsOrThrow(int deviceId) {
    final caps = getCaps(deviceId);
    if (caps == null) {
      throw JoystickException(
        JOYERR_UNPLUGGED,
        'Device $deviceId is unplugged or invalid.',
      );
    }
    return caps;
  }

  /// Returns full capabilities for all connected joysticks.
  List<JoystickCaps> getConnectedDevices() {
    _checkDisposed();
    final devices = <JoystickCaps>[];
    final maxDevs = _joy.getNumDevs();
    for (var id = 0; id < maxDevs; id++) {
      final caps = getCaps(id);
      if (caps != null) {
        devices.add(caps);
      }
    }
    return devices;
  }

  /// Retrieves the current position and button state for [deviceId].
  /// Returns `null` if the device is unplugged or not present.
  JoystickPosition? getPos(int deviceId, {int flags = JOY_RETURNALL}) {
    _checkDisposed();
    _info.ref.dwSize = _infoSize;
    _info.ref.dwFlags = flags;

    final result = _joy.getPosEx(deviceId, _info);
    if (result == JOYERR_UNPLUGGED ||
        result == JOYERR_PARMS ||
        result == MMSYSERR_NODRIVER ||
        result == MMSYSERR_BADDEVICEID) {
      return null;
    }
    if (result != JOYERR_NOERROR) {
      throw JoystickException.fromErrorCode(
        result,
        'Failed to getPosEx for device $deviceId',
      );
    }

    final ref = _info.ref;
    return JoystickPosition(
      flags: ref.dwFlags,
      x: ref.dwXpos,
      y: ref.dwYpos,
      z: ref.dwZpos,
      r: ref.dwRpos,
      u: ref.dwUpos,
      v: ref.dwVpos,
      buttons: ref.dwButtons,
      buttonNumber: ref.dwButtonNumber,
      pov: ref.dwPOV,
    );
  }

  /// Retrieves the current position and button state for [deviceId],
  /// or throws [JoystickException] if not available.
  JoystickPosition getPosOrThrow(int deviceId, {int flags = JOY_RETURNALL}) {
    final pos = getPos(deviceId, flags: flags);
    if (pos == null) {
      throw JoystickException(
        JOYERR_UNPLUGGED,
        'Device $deviceId is unplugged or invalid.',
      );
    }
    return pos;
  }

  /// Returns a [Stream] that periodically polls and emits the [JoystickPosition]
  /// for [deviceId] at the given [interval].
  ///
  /// Polling stops when the stream subscription is cancelled or when the device
  /// is unplugged (if [cancelOnError] is true).
  Stream<JoystickPosition> pollPosition(
    int deviceId, {
    Duration interval = const Duration(milliseconds: 16),
    int flags = JOY_RETURNALL,
    bool cancelOnDisconnect = false,
  }) {
    late StreamController<JoystickPosition> controller;
    Timer? timer;

    controller = StreamController<JoystickPosition>(
      onListen: () {
        timer = Timer.periodic(interval, (_) {
          if (_isDisposed) {
            timer?.cancel();
            controller.close();
            return;
          }
          final pos = getPos(deviceId, flags: flags);
          if (pos != null) {
            controller.add(pos);
          } else if (cancelOnDisconnect) {
            timer?.cancel();
            controller.addError(
              JoystickException(
                JOYERR_UNPLUGGED,
                'Device $deviceId disconnected during polling.',
              ),
            );
            controller.close();
          }
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }
}
