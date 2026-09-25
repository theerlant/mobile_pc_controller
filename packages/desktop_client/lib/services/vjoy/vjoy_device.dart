import 'dart:async';

import 'internal/vjoy_interface_types.dart';
import 'vjoy.dart';
import 'vjoy_error.dart';

/// High-level representation of an individual vJoy virtual device (ID 1-16).
///
/// Encapsulates device discovery, ownership acquisition, control resets,
/// and full writing capabilities for axes, buttons, and POV switches.
class VjoyDevice {
  /// The parent [Vjoy] service manager.
  final Vjoy vjoy;

  /// The 1-based device identifier (1..16).
  final int deviceId;

  /// Standard vJoy minimum axis position (corresponds to minimum physical input).
  static const int axisMin = 1;

  /// Standard vJoy center / neutral axis position.
  static const int axisCenter = 16384;

  /// Standard vJoy maximum axis position (corresponds to maximum physical input).
  static const int axisMax = 32768;

  /// Create a high-level representation of a vJoy device with [deviceId] (1-16).
  VjoyDevice(this.vjoy, this.deviceId) {
    if (deviceId < 1 || deviceId > 16) {
      throw VjoyDeviceInvalid(deviceId);
    }
  }

  // ==========================================
  // Device Status & Capabilities
  // ==========================================

  /// Whether this vJoy device currently exists in the driver configuration.
  bool get exists => vjoy.ffi.isVJDExists(deviceId);

  /// Current device ownership status.
  VjdStat get status => vjoy.ffi.getVJDStatus(deviceId);

  /// True if this device is acquired and owned by the current process.
  bool get isOwned => status == VjdStat.own;

  /// True if this device exists and is free to be acquired.
  bool get isFree => status == VjdStat.free;

  /// True if this device exists but is owned by another process.
  bool get isBusy => status == VjdStat.busy;

  /// True if this device is not configured / missing in vJoy.
  bool get isMissing => status == VjdStat.miss;

  /// Returns the ownership state and raw Process ID (PID) of the device owner.
  (OwnerPID, int) get ownerPid => vjoy.ffi.getOwnerPid(deviceId);

  /// Number of buttons configured for this device (0-128).
  int get buttonCount => vjoy.ffi.getVJDButtonNumber(deviceId);

  /// Number of discrete 4-direction POV hats configured for this device (0-4).
  int get discretePovCount => vjoy.ffi.getVJDDiscPovNumber(deviceId);

  /// Number of continuous 360-degree analog POV hats configured for this device (0-4).
  int get continuousPovCount => vjoy.ffi.getVJDContPovNumber(deviceId);

  /// Checks whether a specific [axis] is supported and enabled on this device.
  bool hasAxis(Axis axis) => vjoy.ffi.getVJDAxisExist(deviceId, axis);

  /// Returns a list of all enabled [Axis] types on this device.
  List<Axis> get availableAxes => Axis.values
      .where((axis) => axis != Axis.UNKN && hasAxis(axis))
      .toList();

  // ==========================================
  // Device Lifecycle & Resets
  // ==========================================

  /// Acquire exclusive feeder ownership of this vJoy device.
  /// Returns `true` if successfully acquired.
  bool acquire() => vjoy.ffi.acquireVJD(deviceId);

  /// Relinquish ownership of this device, freeing it for other applications.
  void relinquish() => vjoy.ffi.relinquishVJD(deviceId);

  /// Reset all controls (axes, buttons, POVs) on this device to their neutral positions.
  void reset() => vjoy.ffi.resetVJD(deviceId);

  /// Reset all buttons on this device to the released state.
  void resetButtons() => vjoy.ffi.resetButtons(deviceId);

  /// Reset all POV hats on this device to their neutral / centered state.
  void resetPovs() => vjoy.ffi.resetPovs(deviceId);

  // ==========================================
  // Axis Feeder Controls
  // ==========================================

  /// Helper to convert a bipolar normalized value (-1.0 to +1.0) to raw vJoy range (1..32768).
  /// -1.0 -> 1, 0.0 -> 16384, +1.0 -> 32768.
  static int normalizeBipolar(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    if (clamped == 0.0) return axisCenter;
    if (clamped < 0.0) {
      return (axisCenter + clamped * (axisCenter - axisMin))
          .round()
          .clamp(axisMin, axisMax);
    }
    return (axisCenter + clamped * (axisMax - axisCenter))
        .round()
        .clamp(axisMin, axisMax);
  }

  /// Helper to convert a unipolar normalized value (0.0 to 1.0) to raw vJoy range (1..32768).
  /// 0.0 -> 1, 1.0 -> 32768.
  static int normalizeUnipolar(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return (clamped * (axisMax - axisMin) + axisMin).round().clamp(axisMin, axisMax);
  }

  /// Set the raw value of [axis] on this device.
  ///
  /// [rawValue] will be clamped to valid vJoy limits (1..32768).
  bool setAxis(Axis axis, int rawValue) {
    final clamped = rawValue.clamp(axisMin, axisMax);
    return vjoy.ffi.setAxis(clamped, deviceId, axis);
  }

  /// Set the normalized value of [axis].
  ///
  /// If [bipolar] is true (default, suitable for steering wheel and centering axes),
  /// [value] is expected in the range [-1.0 .. +1.0].
  ///
  /// If [bipolar] is false (suitable for throttle, brake, clutch, handbrake),
  /// [value] is expected in the range [0.0 .. 1.0].
  bool setAxisNormalized(Axis axis, double value, {bool bipolar = true}) {
    final rawValue = bipolar ? normalizeBipolar(value) : normalizeUnipolar(value);
    return setAxis(axis, rawValue);
  }

  /// Set X Axis (commonly used for Steering Wheel or Primary Horizontal Axis).
  bool setX(int rawValue) => setAxis(Axis.X, rawValue);

  /// Set X Axis with normalized value (-1.0 to +1.0).
  bool setXNormalized(double value, {bool bipolar = true}) =>
      setAxisNormalized(Axis.X, value, bipolar: bipolar);

  /// Set Y Axis (commonly used for Throttle or Primary Vertical Axis).
  bool setY(int rawValue) => setAxis(Axis.Y, rawValue);

  /// Set Y Axis with normalized value (0.0 to 1.0 for pedals, or -1.0 to 1.0 for sticks).
  bool setYNormalized(double value, {bool bipolar = false}) =>
      setAxisNormalized(Axis.Y, value, bipolar: bipolar);

  /// Set Z Axis (commonly used for Brake or Throttle/Brake combo).
  bool setZ(int rawValue) => setAxis(Axis.Z, rawValue);

  /// Set Z Axis with normalized value (0.0 to 1.0 for pedals).
  bool setZNormalized(double value, {bool bipolar = false}) =>
      setAxisNormalized(Axis.Z, value, bipolar: bipolar);

  /// Set RX Axis (commonly used for Clutch or Secondary Rotation Axis).
  bool setRx(int rawValue) => setAxis(Axis.RX, rawValue);

  /// Set RX Axis with normalized value (0.0 to 1.0 for clutch/pedal, or -1.0 to 1.0).
  bool setRxNormalized(double value, {bool bipolar = false}) =>
      setAxisNormalized(Axis.RX, value, bipolar: bipolar);

  /// Set RY Axis (commonly used for Handbrake or Secondary Rotation Axis).
  bool setRy(int rawValue) => setAxis(Axis.RY, rawValue);

  /// Set RY Axis with normalized value (0.0 to 1.0 for handbrake, or -1.0 to 1.0).
  bool setRyNormalized(double value, {bool bipolar = false}) =>
      setAxisNormalized(Axis.RY, value, bipolar: bipolar);

  /// Set RZ Axis (commonly used for Rudder or Steering).
  bool setRz(int rawValue) => setAxis(Axis.RZ, rawValue);

  /// Set RZ Axis with normalized value (-1.0 to +1.0).
  bool setRzNormalized(double value, {bool bipolar = true}) =>
      setAxisNormalized(Axis.RZ, value, bipolar: bipolar);

  /// Set Slider 0 (SL0).
  bool setSlider0(int rawValue) => setAxis(Axis.SL0, rawValue);

  /// Set Slider 0 with normalized value (0.0 to 1.0).
  bool setSlider0Normalized(double value, {bool bipolar = false}) =>
      setAxisNormalized(Axis.SL0, value, bipolar: bipolar);

  /// Set Slider 1 (SL1).
  bool setSlider1(int rawValue) => setAxis(Axis.SL1, rawValue);

  /// Set Slider 1 with normalized value (0.0 to 1.0).
  bool setSlider1Normalized(double value, {bool bipolar = false}) =>
      setAxisNormalized(Axis.SL1, value, bipolar: bipolar);

  /// Set Wheel axis (WHL).
  bool setWheel(int rawValue) => setAxis(Axis.WHL, rawValue);

  /// Set Wheel axis with normalized value (-1.0 to +1.0).
  bool setWheelNormalized(double value, {bool bipolar = true}) =>
      setAxisNormalized(Axis.WHL, value, bipolar: bipolar);

  // ==========================================
  // Button Feeder Controls
  // ==========================================

  /// Set the state of button [buttonNumber] (1-indexed, 1..128).
  bool setButton(int buttonNumber, bool isPressed) {
    return vjoy.ffi.setBtn(isPressed, deviceId, buttonNumber);
  }

  /// Press button [buttonNumber] (1-indexed, 1..128).
  bool pressButton(int buttonNumber) => setButton(buttonNumber, true);

  /// Release button [buttonNumber] (1-indexed, 1..128).
  bool releaseButton(int buttonNumber) => setButton(buttonNumber, false);

  // ==========================================
  // POV Hat Controls
  // ==========================================

  /// Set continuous / analog POV [povNumber] (1-indexed, 1..4).
  ///
  /// [centidegrees] is in 1/100ths of a degree (0..35900).
  /// Pass `-1` or `0xFFFF` to center the POV hat.
  bool setContinuousPov(int povNumber, int centidegrees) {
    return vjoy.ffi.setContPov(centidegrees, deviceId, povNumber);
  }

  /// Set continuous / analog POV [povNumber] (1-indexed, 1..4) using degrees (0.0 to 359.99).
  ///
  /// Pass `null` to center the POV hat.
  bool setContinuousPovAngle(int povNumber, double? angleDegrees) {
    if (angleDegrees == null) {
      return setContinuousPov(povNumber, -1);
    }
    final centidegrees = ((angleDegrees % 360.0) * 100.0).round();
    return setContinuousPov(povNumber, centidegrees);
  }

  /// Set discrete 4-direction POV [povNumber] (1-indexed, 1..4) to [direction].
  bool setDiscretePov(int povNumber, DiscPov direction) {
    return vjoy.ffi.setDiscPov(direction.value, deviceId, povNumber);
  }

  // ==========================================
  // Configuration & Management
  // ==========================================

  /// Reconfigure this device's layout (axes, buttons, POVs, FFB) via the vJoyConfig utility.
  Future<bool> configure({
    List<Axis>? axes,
    int? numButtons,
    int? numAnalogPovs,
    int? numDiscretePovs,
    List<FfbEffect>? ffbEffects,
    bool force = true,
    bool asAdmin = true,
  }) {
    return vjoy.configureDevice(
      deviceId,
      axes: axes,
      numButtons: numButtons,
      numAnalogPovs: numAnalogPovs,
      numDiscretePovs: numDiscretePovs,
      ffbEffects: ffbEffects,
      force: force,
      asAdmin: asAdmin,
    );
  }

  /// Delete this vJoy device from the driver configuration.
  Future<bool> delete({bool asAdmin = true}) {
    return vjoy.deleteDevice(deviceId, asAdmin: asAdmin);
  }

  @override
  String toString() =>
      'VjoyDevice(id: $deviceId, exists: $exists, status: ${status.name}, '
      'buttons: $buttonCount, continuousPOVs: $continuousPovCount, discretePOVs: $discretePovCount)';
}
