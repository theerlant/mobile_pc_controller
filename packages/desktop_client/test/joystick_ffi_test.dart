import 'dart:ffi';

import 'package:desktop_client/services/winmm_joystick/internal/joycapsw.dart';
import 'package:desktop_client/services/winmm_joystick/internal/joyinfoex.dart';
import 'package:desktop_client/services/winmm_joystick/joystick.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JoystickApi FFI Low-Level Binding Tests', () {
    late JoystickApi api;

    setUp(() {
      api = JoystickApi();
    });

    tearDown(() {
      api.dispose();
    });

    test('successfully loads winmm.dll and binds FFI functions', () {
      expect(api.getNumDevs, isNotNull);
      expect(api.getDevCapsW, isNotNull);
      expect(api.getPosEx, isNotNull);
    });

    test('getNumDevs returns a non-negative driver device limit', () {
      final numDevs = api.getNumDevs();
      expect(numDevs, isA<int>());
      expect(numDevs, greaterThanOrEqualTo(0));
    });

    test(
      'getDevCapsW executes without crashing for valid and invalid device IDs',
      () {
        final caps = calloc<JOYCAPSW>();
        final capsSize = sizeOf<JOYCAPSW>();

        try {
          // Query device ID 0
          final result0 = api.getDevCapsW(0, caps, capsSize);
          expect(result0, isA<int>());
          expect(
            result0,
            isIn([
              JOYERR_NOERROR,
              JOYERR_UNPLUGGED,
              JOYERR_PARMS,
              MMSYSERR_NODRIVER,
              MMSYSERR_BADDEVICEID,
              MMSYSERR_INVALIDPARAM,
            ]),
          );

          // Query out-of-range device ID (e.g. 9999)
          final resultInvalid = api.getDevCapsW(9999, caps, capsSize);
          expect(resultInvalid, isA<int>());
          expect(resultInvalid, isNot(equals(JOYERR_NOERROR)));
        } finally {
          calloc.free(caps);
        }
      },
    );

    test('getPosEx executes without crashing with JOYINFOEX struct', () {
      final info = calloc<JOYINFOEX>();
      final infoSize = sizeOf<JOYINFOEX>();

      try {
        info.ref.dwSize = infoSize;
        info.ref.dwFlags = JOY_RETURNALL;

        final result = api.getPosEx(0, info);
        expect(result, isA<int>());
        expect(
          result,
          isIn([
            JOYERR_NOERROR,
            JOYERR_UNPLUGGED,
            JOYERR_PARMS,
            MMSYSERR_NODRIVER,
            MMSYSERR_BADDEVICEID,
            MMSYSERR_INVALIDPARAM,
          ]),
        );
      } finally {
        calloc.free(info);
      }
    });
  });

  group('Joystick High-Level API Unit Tests', () {
    late Joystick joystick;

    setUp(() {
      joystick = Joystick();
    });

    tearDown(() {
      joystick.dispose();
    });

    test('numDevices returns a valid device count', () {
      expect(joystick.numDevices, isA<int>());
      expect(joystick.numDevices, greaterThanOrEqualTo(0));
    });

    test('findDevices returns a list of detected DeviceResult records', () {
      final devices = joystick.findDevices();
      expect(devices, isA<List<DeviceResult>>());

      for (final dev in devices) {
        expect(dev.deviceId, greaterThanOrEqualTo(0));
        expect(dev.vendorId, isA<int>());
        expect(dev.productId, isA<int>());
      }
    });

    test('isConnected returns a boolean for device indices', () {
      final connected0 = joystick.isConnected(0);
      expect(connected0, isA<bool>());

      final connectedInvalid = joystick.isConnected(9999);
      expect(connectedInvalid, isFalse);
    });

    test('getCaps returns JoystickCaps or null safely without crashing', () {
      final caps = joystick.getCaps(0);
      if (caps != null) {
        expect(caps.deviceId, equals(0));
        expect(caps.productName, isA<String>());
        expect(caps.numAxes, greaterThanOrEqualTo(0));
        expect(caps.numButtons, greaterThanOrEqualTo(0));
        expect(caps.hasPov, isA<bool>());
        expect(caps.hasZ, isA<bool>());
        expect(caps.hasR, isA<bool>());
        expect(caps.hasU, isA<bool>());
        expect(caps.hasV, isA<bool>());
        expect(caps.isVjoy, isA<bool>());
      } else {
        expect(caps, isNull);
      }

      // Out of bounds device should return null
      final invalidCaps = joystick.getCaps(9999);
      expect(invalidCaps, isNull);
    });

    test('getCapsOrThrow throws JoystickException when device is invalid/unplugged', () {
      expect(
        () => joystick.getCapsOrThrow(9999),
        throwsA(isA<JoystickException>()),
      );
    });

    test('getConnectedDevices returns list of caps for all active devices', () {
      final connected = joystick.getConnectedDevices();
      expect(connected, isA<List<JoystickCaps>>());
      for (final dev in connected) {
        expect(dev.deviceId, greaterThanOrEqualTo(0));
      }
    });

    test('getPos returns JoystickPosition or null safely', () {
      final pos = joystick.getPos(0);
      if (pos != null) {
        expect(pos.x, isA<int>());
        expect(pos.y, isA<int>());
        expect(pos.buttons, isA<int>());
        expect(pos.buttonNumber, isA<int>());
        expect(pos.isPovCentered, isA<bool>());
        expect(pos.pressedButtons, isA<List<int>>());
      } else {
        expect(pos, isNull);
      }

      final invalidPos = joystick.getPos(9999);
      expect(invalidPos, isNull);
    });

    test('getPosOrThrow throws JoystickException for invalid device ID', () {
      expect(
        () => joystick.getPosOrThrow(9999),
        throwsA(isA<JoystickException>()),
      );
    });

    test('throws StateError when used after dispose', () {
      final tempJoy = Joystick();
      tempJoy.dispose();

      expect(() => tempJoy.numDevices, throwsStateError);
      expect(() => tempJoy.findDevices(), throwsStateError);
      expect(() => tempJoy.isConnected(0), throwsStateError);
      expect(() => tempJoy.getCaps(0), throwsStateError);
      expect(() => tempJoy.getPos(0), throwsStateError);
    });
  });

  group('Joystick Helper Classes & Logic Unit Tests', () {
    test('isVjoyDevice identifies vJoy vendor and product IDs correctly', () {
      const vjoyDev = (deviceId: 0, vendorId: 0x1234, productId: 0xBEAD);
      const otherDev = (deviceId: 0, vendorId: 0x046D, productId: 0xC24F);

      expect(isVjoyDevice(vjoyDev), isTrue);
      expect(isVjoyDevice(otherDev), isFalse);
    });

    test(
      'JoystickPosition helpers compute POV and button states correctly',
      () {
        const centeredPos = JoystickPosition(
          flags: JOY_RETURNALL,
          x: 0,
          y: 0,
          z: 0,
          r: 0,
          u: 0,
          v: 0,
          buttons: 0x05, // buttons 1 and 3 pressed (bit 0 and bit 2)
          buttonNumber: 2,
          pov: 0xFFFF,
        );

        expect(centeredPos.isPovCentered, isTrue);
        expect(centeredPos.povAngleDegrees, isNull);
        expect(centeredPos.isButtonPressed(1), isTrue);
        expect(centeredPos.isButtonPressed(2), isFalse);
        expect(centeredPos.isButtonPressed(3), isTrue);
        expect(centeredPos.isButtonIndexPressed(0), isTrue);
        expect(centeredPos.isButtonIndexPressed(1), isFalse);
        expect(centeredPos.isButtonIndexPressed(2), isTrue);
        expect(centeredPos.pressedButtons, equals([1, 3]));

        const angledPos = JoystickPosition(
          flags: JOY_RETURNALL,
          x: 0,
          y: 0,
          z: 0,
          r: 0,
          u: 0,
          v: 0,
          buttons: 0,
          buttonNumber: 0,
          pov: 9000, // 90.00 degrees
        );

        expect(angledPos.isPovCentered, isFalse);
        expect(angledPos.povAngleDegrees, equals(90.0));
        expect(angledPos.pressedButtons, isEmpty);
      },
    );

    test('JoystickCaps bitflag getters evaluate capability bitmasks properly (synthetic data)', () {
      const caps = JoystickCaps(
        deviceId: 0,
        vendorId: 0x1234,
        productId: 0xBEAD,
        productName: 'Mock Joystick Device',
        regKey: '',
        oemVxD: '',
        xMin: 0,
        xMax: 32767,
        yMin: 0,
        yMax: 32767,
        zMin: 0,
        zMax: 32767,
        rMin: 0,
        rMax: 32767,
        uMin: 0,
        uMax: 0,
        vMin: 0,
        vMax: 0,
        numButtons: 8,
        maxButtons: 128,
        numAxes: 4,
        maxAxes: 8,
        periodMin: 10,
        periodMax: 1000,
        caps: JOYCAPS_HASZ | JOYCAPS_HASR | JOYCAPS_HASPOV | JOYCAPS_POVCTS,
      );

      expect(caps.isVjoy, isTrue);
      expect(caps.hasZ, isTrue);
      expect(caps.hasR, isTrue);
      expect(caps.hasU, isFalse);
      expect(caps.hasV, isFalse);
      expect(caps.hasPov, isTrue);
      expect(caps.isPovContinuous, isTrue);
      expect(caps.isPov4Dir, isFalse);
      expect(
        caps.toDeviceResult(),
        equals((deviceId: 0, vendorId: 0x1234, productId: 0xBEAD)),
      );
    });

    test('JoystickException.fromErrorCode produces expected messages', () {
      final unplugged = JoystickException.fromErrorCode(
        JOYERR_UNPLUGGED,
        'Device 0',
      );
      expect(unplugged.errorCode, equals(JOYERR_UNPLUGGED));
      expect(unplugged.message, contains('unplugged'));
      expect(unplugged.toString(), contains('JoystickException'));

      final badId = JoystickException.fromErrorCode(MMSYSERR_BADDEVICEID);
      expect(badId.errorCode, equals(MMSYSERR_BADDEVICEID));
      expect(badId.message, contains('MMSYSERR_BADDEVICEID'));

      final noDriver = JoystickException.fromErrorCode(MMSYSERR_NODRIVER);
      expect(noDriver.errorCode, equals(MMSYSERR_NODRIVER));
      expect(noDriver.message, contains('MMSYSERR_NODRIVER'));

      final invalidParam = JoystickException.fromErrorCode(
        MMSYSERR_INVALIDPARAM,
      );
      expect(invalidParam.errorCode, equals(MMSYSERR_INVALIDPARAM));
      expect(invalidParam.message, contains('MMSYSERR_INVALIDPARAM'));

      final joyParms = JoystickException.fromErrorCode(JOYERR_PARMS);
      expect(joyParms.errorCode, equals(JOYERR_PARMS));
      expect(joyParms.message, contains('JOYERR_PARMS'));

      final customError = JoystickException.fromErrorCode(999);
      expect(customError.errorCode, equals(999));
      expect(customError.message, contains('999'));
    });
  });
}
