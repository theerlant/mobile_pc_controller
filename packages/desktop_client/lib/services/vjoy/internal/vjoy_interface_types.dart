// ignore_for_file: non_constant_identifier_names, constant_identifier_names

/// Vjoy device status
enum VjdStat {
  own(0),
  free(1),
  busy(2),
  miss(3),
  unkn(4);

  final int value;
  const VjdStat(this.value);

  static VjdStat fromInt(int value) {
    return VjdStat.values.firstWhere(
      (stat) => stat.value == value,
      orElse: () => VjdStat.unkn,
    );
  }
}

/// Vjoy Device Owner
enum OwnerPID {
  NO_FILE_EXIST(-13),
  NO_DEV_EXIST(-12),
  BAD_DEV_STAT(-11),
  UNKNOWN(-10),
  Owned(0);

  final int value;

  const OwnerPID(this.value);

  /// Only return the Device Owner State. Method must also return the actual Process ID!
  static OwnerPID fromInt(int pId) {
    if (pId < 0) {
      for (var value in OwnerPID.values) {
        if (value.value == pId) return value;
      }
      return OwnerPID.UNKNOWN;
    }
    return OwnerPID.Owned;
  }
}

/// Vjoy Axis UINT (HID_USAGE_*AXIS*)
enum Axis {
  X(0x30),
  Y(0x31),
  Z(0x32),
  RX(0x33),
  RY(0x34),
  RZ(0x35),
  SL0(0x36),
  SL1(0x37),
  WHL(0x38),
  POV(0x39),
  UNKN(0x00);

  final int value;

  const Axis(this.value);

  static Axis fromInt(int value) {
    return Axis.values.firstWhere(
      (axis) => axis.value == value,
      orElse: () => Axis.UNKN,
    );
  }
}

/// Discrete POV int value
enum DiscPov {
  North(0),
  East(1),
  South(2),
  West(3),
  Neutral(-1);

  final int value;
  const DiscPov(this.value);

  static DiscPov fromInt(int value) {
    return DiscPov.values.firstWhere(
      (pov) => pov.value == value,
      orElse: () => DiscPov.Neutral,
    );
  }
}

/// Force Feedback Effects (HID_USAGE_*EFFECT*)
enum FfbEffect {
  Const(0x26),
  Ramp(0x27),
  Squr(0x30),
  Sine(0x31),
  Trng(0x32),
  Stup(0x33),
  Stdn(0x34),
  Sprng(0x40),
  Dmpr(0x41),
  Inrt(0x42),
  Fric(0x43);

  final int value;

  const FfbEffect(this.value);
}
