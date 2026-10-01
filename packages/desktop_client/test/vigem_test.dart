import 'package:desktop_client/services/vigem/vigem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ViGEm Error Codes & Exceptions Tests', () {
    test('VigemErrors.fromInt handles unsigned 32-bit hex values', () {
      expect(
        VigemErrors.fromInt(0x20000000),
        equals(VigemErrors.VIGEM_ERROR_NONE),
      );
      expect(VigemErrors.fromInt(0x20000000).isSuccess, isTrue);

      expect(
        VigemErrors.fromInt(0xE0000001),
        equals(VigemErrors.VIGEM_ERROR_BUS_NOT_FOUND),
      );
      expect(VigemErrors.fromInt(0xE0000001).isSuccess, isFalse);

      expect(
        VigemErrors.fromInt(0xE0000005),
        equals(VigemErrors.VIGEM_ERROR_ALREADY_CONNECTED),
      );
      expect(
        VigemErrors.fromInt(0xE0000007),
        equals(VigemErrors.VIGEM_ERROR_TARGET_NOT_PLUGGED_IN),
      );
    });

    test('VigemErrors.fromInt handles signed 32-bit negative integers', () {
      // 0xE0000001 as signed 32-bit int is -536870911
      const signedBusNotFound = -536870911;
      expect(
        VigemErrors.fromInt(signedBusNotFound),
        equals(VigemErrors.VIGEM_ERROR_BUS_NOT_FOUND),
      );

      // Unknown code falls back to undefined
      expect(
        VigemErrors.fromInt(0x12345678),
        equals(VigemErrors.FROM_INT_UNDEFINED),
      );
    });

    test('VIGEM_SUCCESS_OR_THROW behavior', () {
      expect(
        () => VIGEM_SUCCESS_OR_THROW(VigemErrors.VIGEM_ERROR_NONE.value),
        returnsNormally,
      );

      expect(
        () => VIGEM_SUCCESS_OR_THROW(
          VigemErrors.VIGEM_ERROR_BUS_NOT_FOUND.value,
        ),
        throwsA(
          isA<ViGEmNativeException>().having(
            (e) => e.errorCode,
            'errorCode',
            equals(VigemErrors.VIGEM_ERROR_BUS_NOT_FOUND),
          ),
        ),
      );
    });

    test('ViGEm Exception hierarchy and messages', () {
      expect(const ViGEmClientAllocException(), isA<ViGEmException>());
      expect(const ViGEmPadFullException(), isA<ViGEmException>());
      expect(const ViGEmDisposedException(), isA<ViGEmException>());
      expect(const ViGEmNotConnectedException(), isA<ViGEmException>());

      final nativeEx = ViGEmNativeException(
        VigemErrors.VIGEM_ERROR_NO_FREE_SLOT,
        'All 4 slots occupied',
      );
      expect(nativeEx.toString(), contains('VIGEM_ERROR_NO_FREE_SLOT'));
      expect(nativeEx.toString(), contains('All 4 slots occupied'));
    });
  });

  group('ViGEm XUSB Types & Button Bitmask Tests', () {
    test('XusbButton bitmask values and isPressedIn', () {
      const bitmask = 0x1000 | 0x0100 | 0x0001; // A | LB | DPAD_UP

      expect(XusbButton.XUSB_GAMEPAD_A.isPressedIn(bitmask), isTrue);
      expect(
        XusbButton.XUSB_GAMEPAD_LEFT_SHOULDER.isPressedIn(bitmask),
        isTrue,
      );
      expect(XusbButton.XUSB_GAMEPAD_DPAD_UP.isPressedIn(bitmask), isTrue);

      expect(XusbButton.XUSB_GAMEPAD_B.isPressedIn(bitmask), isFalse);
      expect(XusbButton.XUSB_GAMEPAD_X.isPressedIn(bitmask), isFalse);
      expect(XusbButton.XUSB_GAMEPAD_Y.isPressedIn(bitmask), isFalse);
      expect(
        XusbButton.XUSB_GAMEPAD_RIGHT_SHOULDER.isPressedIn(bitmask),
        isFalse,
      );
    });

    test('XusbButton.fromInt converts exact values', () {
      expect(
        XusbButton.fromInt(0x1000),
        equals(XusbButton.XUSB_GAMEPAD_A),
      );
      expect(
        XusbButton.fromInt(0x2000),
        equals(XusbButton.XUSB_GAMEPAD_B),
      );
      expect(
        XusbButton.fromInt(0x4000),
        equals(XusbButton.XUSB_GAMEPAD_X),
      );
      expect(
        XusbButton.fromInt(0x8000),
        equals(XusbButton.XUSB_GAMEPAD_Y),
      );
      expect(
        XusbButton.fromInt(0x9999),
        equals(XusbButton.FROM_INT_UNDEFINED),
      );
    });

    test('XusbDpadDirection conversions to and from button bitmasks', () {
      for (final dir in XusbDpadDirection.values) {
        final mask = dir.buttonMask;
        final roundTrip = XusbDpadDirection.fromMask(mask);
        expect(roundTrip, equals(dir));
      }

      expect(XusbDpadDirection.centered.buttonMask, equals(0));
      expect(
        XusbDpadDirection.up.buttonMask,
        equals(XusbButton.XUSB_GAMEPAD_DPAD_UP.value),
      );
      expect(
        XusbDpadDirection.down.buttonMask,
        equals(XusbButton.XUSB_GAMEPAD_DPAD_DOWN.value),
      );
      expect(
        XusbDpadDirection.left.buttonMask,
        equals(XusbButton.XUSB_GAMEPAD_DPAD_LEFT.value),
      );
      expect(
        XusbDpadDirection.right.buttonMask,
        equals(XusbButton.XUSB_GAMEPAD_DPAD_RIGHT.value),
      );
      expect(
        XusbDpadDirection.upRight.buttonMask,
        equals(
          XusbButton.XUSB_GAMEPAD_DPAD_UP.value |
              XusbButton.XUSB_GAMEPAD_DPAD_RIGHT.value,
        ),
      );
    });

    test('XusbOutput rumble and LED state model', () {
      const output = XusbOutput(largeMotor: 255, smallMotor: 128, ledNumber: 1);

      expect(output.largeMotor, equals(255));
      expect(output.smallMotor, equals(128));
      expect(output.ledNumber, equals(1));
      expect(output.isVibrating, isTrue);
      expect(output.largeMotorNormalized, equals(1.0));
      expect(output.smallMotorNormalized, closeTo(128 / 255.0, 0.001));

      const idleOutput = XusbOutput();
      expect(idleOutput.isVibrating, isFalse);
      expect(idleOutput.largeMotorNormalized, equals(0.0));
      expect(idleOutput.smallMotorNormalized, equals(0.0));

      expect(output, equals(const XusbOutput(largeMotor: 255, smallMotor: 128, ledNumber: 1)));
      expect(output.hashCode, equals(const XusbOutput(largeMotor: 255, smallMotor: 128, ledNumber: 1).hashCode));
    });
  });

  group('ViGEmPad Normalization Math Tests', () {
    test('normalizeThumb maps -1.0 to 1.0 correctly to raw int16 range', () {
      expect(ViGEmPad.normalizeThumb(0.0), equals(0));
      expect(ViGEmPad.normalizeThumb(1.0), equals(32767));
      expect(ViGEmPad.normalizeThumb(-1.0), equals(-32768));
      expect(ViGEmPad.normalizeThumb(0.5), equals((0.5 * 32767).round()));
      expect(ViGEmPad.normalizeThumb(-0.5), equals((-0.5 * 32768).round()));

      // Clamping limits
      expect(ViGEmPad.normalizeThumb(2.5), equals(32767));
      expect(ViGEmPad.normalizeThumb(-2.5), equals(-32768));
    });

    test('normalizeTrigger maps 0.0 to 1.0 correctly to raw uint8 range', () {
      expect(ViGEmPad.normalizeTrigger(0.0), equals(0));
      expect(ViGEmPad.normalizeTrigger(1.0), equals(255));
      expect(ViGEmPad.normalizeTrigger(0.5), equals(128));

      // Clamping limits
      expect(ViGEmPad.normalizeTrigger(-0.5), equals(0));
      expect(ViGEmPad.normalizeTrigger(1.5), equals(255));
    });
  });
}
