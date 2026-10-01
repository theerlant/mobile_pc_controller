// ignore_for_file: constant_identifier_names, camel_case_types, non_constant_identifier_names

import 'dart:ffi';

import 'package:win32/win32.dart';

/// Represents an XINPUT_GAMEPAD-compatible report structure.
final class XUSB_REPORT extends Struct {
  @USHORT()
  external int wButtons;
  @UCHAR()
  external int bLeftTrigger;
  @UCHAR()
  external int bRightTrigger;
  @SHORT()
  external int sThumbLX;
  @SHORT()
  external int sThumbLY;
  @SHORT()
  external int sThumbRX;
  @SHORT()
  external int sThumbRY;
}

/// Values set by output reports on XINPUT_GAMEPAD
final class XUSB_OUTPUT_DATA extends Struct {
  @UCHAR()
  external int LargeMotor;
  @UCHAR()
  external int SmallMotor;
  @UCHAR()
  external int LedNumber;
}

typedef PXUSB_OUTPUT_DATA = Pointer<XUSB_OUTPUT_DATA>;

/// Possible XUSB report buttons with bitmask constants.
enum XusbButton {
  XUSB_GAMEPAD_DPAD_UP(0x0001),
  XUSB_GAMEPAD_DPAD_DOWN(0x0002),
  XUSB_GAMEPAD_DPAD_LEFT(0x0004),
  XUSB_GAMEPAD_DPAD_RIGHT(0x0008),
  XUSB_GAMEPAD_START(0x0010),
  XUSB_GAMEPAD_BACK(0x0020),
  XUSB_GAMEPAD_LEFT_THUMB(0x0040),
  XUSB_GAMEPAD_RIGHT_THUMB(0x0080),
  XUSB_GAMEPAD_LEFT_SHOULDER(0x0100),
  XUSB_GAMEPAD_RIGHT_SHOULDER(0x0200),
  XUSB_GAMEPAD_GUIDE(0x0400),
  XUSB_GAMEPAD_A(0x1000),
  XUSB_GAMEPAD_B(0x2000),
  XUSB_GAMEPAD_X(0x4000),
  XUSB_GAMEPAD_Y(0x8000),
  FROM_INT_UNDEFINED(0xFFFF);

  final int value;

  const XusbButton(this.value);

  /// Find [XusbButton] by its exact bit value.
  static XusbButton fromInt(int value) => XusbButton.values.firstWhere(
    (btn) => btn.value == value,
    orElse: () => XusbButton.FROM_INT_UNDEFINED,
  );

  /// Checks if this button flag is set within a combined buttons bitmask.
  bool isPressedIn(int bitmask) => (bitmask & value) != 0;
}

/// High-level 8-direction or centered D-Pad state.
enum XusbDpadDirection {
  centered,
  up,
  upRight,
  right,
  downRight,
  down,
  downLeft,
  left,
  upLeft;

  /// Returns the corresponding [XusbButton] bitmask for this directional position.
  int get buttonMask {
    switch (this) {
      case XusbDpadDirection.centered:
        return 0;
      case XusbDpadDirection.up:
        return XusbButton.XUSB_GAMEPAD_DPAD_UP.value;
      case XusbDpadDirection.upRight:
        return XusbButton.XUSB_GAMEPAD_DPAD_UP.value |
            XusbButton.XUSB_GAMEPAD_DPAD_RIGHT.value;
      case XusbDpadDirection.right:
        return XusbButton.XUSB_GAMEPAD_DPAD_RIGHT.value;
      case XusbDpadDirection.downRight:
        return XusbButton.XUSB_GAMEPAD_DPAD_DOWN.value |
            XusbButton.XUSB_GAMEPAD_DPAD_RIGHT.value;
      case XusbDpadDirection.down:
        return XusbButton.XUSB_GAMEPAD_DPAD_DOWN.value;
      case XusbDpadDirection.downLeft:
        return XusbButton.XUSB_GAMEPAD_DPAD_DOWN.value |
            XusbButton.XUSB_GAMEPAD_DPAD_LEFT.value;
      case XusbDpadDirection.left:
        return XusbButton.XUSB_GAMEPAD_DPAD_LEFT.value;
      case XusbDpadDirection.upLeft:
        return XusbButton.XUSB_GAMEPAD_DPAD_UP.value |
            XusbButton.XUSB_GAMEPAD_DPAD_LEFT.value;
    }
  }

  /// Derives the [XusbDpadDirection] from a combined buttons bitmask.
  static XusbDpadDirection fromMask(int bitmask) {
    final up = XusbButton.XUSB_GAMEPAD_DPAD_UP.isPressedIn(bitmask);
    final down = XusbButton.XUSB_GAMEPAD_DPAD_DOWN.isPressedIn(bitmask);
    final left = XusbButton.XUSB_GAMEPAD_DPAD_LEFT.isPressedIn(bitmask);
    final right = XusbButton.XUSB_GAMEPAD_DPAD_RIGHT.isPressedIn(bitmask);

    if (up && left) return XusbDpadDirection.upLeft;
    if (up && right) return XusbDpadDirection.upRight;
    if (up) return XusbDpadDirection.up;

    if (down && left) return XusbDpadDirection.downLeft;
    if (down && right) return XusbDpadDirection.downRight;
    if (down) return XusbDpadDirection.down;

    if (left) return XusbDpadDirection.left;
    if (right) return XusbDpadDirection.right;

    return XusbDpadDirection.centered;
  }
}

/// High-level representation of force-feedback rumble and LED ring state from the host.
class XusbOutput {
  /// Low-frequency / heavy rumble motor speed (0..255).
  final int largeMotor;

  /// High-frequency / light rumble motor speed (0..255).
  final int smallMotor;

  /// Quadrant LED index indicator assigned by the host (0..4).
  final int ledNumber;

  const XusbOutput({
    this.largeMotor = 0,
    this.smallMotor = 0,
    this.ledNumber = 0,
  });

  /// `true` if either rumble motor is actively vibrating.
  bool get isVibrating => largeMotor > 0 || smallMotor > 0;

  /// Normalized large motor speed (0.0 to 1.0).
  double get largeMotorNormalized => (largeMotor / 255.0).clamp(0.0, 1.0);

  /// Normalized small motor speed (0.0 to 1.0).
  double get smallMotorNormalized => (smallMotor / 255.0).clamp(0.0, 1.0);

  @override
  String toString() =>
      'XusbOutput(largeMotor: $largeMotor, smallMotor: $smallMotor, led: $ledNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XusbOutput &&
          runtimeType == other.runtimeType &&
          largeMotor == other.largeMotor &&
          smallMotor == other.smallMotor &&
          ledNumber == other.ledNumber;

  @override
  int get hashCode => Object.hash(largeMotor, smallMotor, ledNumber);
}
