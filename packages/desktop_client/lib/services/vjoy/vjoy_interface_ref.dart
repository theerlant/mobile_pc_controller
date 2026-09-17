// ignore_for_file: non_constant_identifier_names, constant_identifier_names

/// vJoyInterface.dll methods reference, adapted into dart casing convetion
final vJoyEnabled = "vJoyEnabled";
final getvJoyVersion = "GetvJoyVersion";
final getvJoyProductString = "GetvJoyProductString";
final getvJoyManufacturerString = "GetvJoyManufacturerString";
final getvJoySerialNumberString = "GetvJoySerialNumberString";
final driverMatch = "DriverMatch";
final getVJDStatus = "GetVJDStatus";
final isVJDExists = "isVJDExists";
final acquireVJD = "AcquireVJD";
final relinquishVJD = 'RelinquishVJD';
final updateVJD = 'UpdateVJD';
final getVJDAxisExist = 'GetVJDAxisExist';
final resetVJD = 'ResetVJD';
final resetButtons = 'ResetButtons';
final resetPovs = 'ResetPovs';
final setAxis = 'SetAxis';
final setBtn = 'SetBtn';
final setDiscPov = 'SetDiscPov';
final setContPov = 'SetContPov';

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

/// Vjoy Axis UINT
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
