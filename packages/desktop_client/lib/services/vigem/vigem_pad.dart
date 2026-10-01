import 'dart:ffi';

import 'package:desktop_client/services/vigem/vigem.dart';
import 'package:ffi/ffi.dart';

/// High-level representation of an emulated virtual Xbox 360 controller.
///
/// Encapsulates connection lifecycle, state buffering, input feeds (axes, buttons,
/// triggers, D-Pad), force feedback / rumble output queries, and normalization helpers.
class ViGEmPad {
  /// The parent [ViGEm] client service.
  final ViGEm vigem;

  /// Native pointer to the underlying virtual target.
  final PVIGEM_TARGET target;

  /// Cached native buffers for high-performance zero-GC updates.
  final Pointer<XUSB_REPORT> _reportPtr = calloc<XUSB_REPORT>();
  final Pointer<XUSB_OUTPUT_DATA> _outputPtr = calloc<XUSB_OUTPUT_DATA>();
  final Pointer<Uint32> _userIndexPtr = calloc<Uint32>();

  bool _isDisposed = false;

  /// Whether changes to controls are immediately flushed to the virtual device.
  ///
  /// When `false` (recommended for high-frequency game loops), call [update]
  /// once per frame/tick after modifying multiple axes or buttons.
  bool autoUpdate;

  // Internal state cache
  int _wButtons = 0;
  int _bLeftTrigger = 0;
  int _bRightTrigger = 0;
  int _sThumbLX = 0;
  int _sThumbLY = 0;
  int _sThumbRX = 0;
  int _sThumbRY = 0;

  /// Minimum raw trigger value.
  static const int triggerMin = 0;

  /// Maximum raw trigger value.
  static const int triggerMax = 255;

  /// Minimum raw thumbstick axis value.
  static const int thumbMin = -32768;

  /// Neutral / center raw thumbstick axis value.
  static const int thumbCenter = 0;

  /// Maximum raw thumbstick axis value.
  static const int thumbMax = 32767;

  /// Creates a new [ViGEmPad] instance wrapping [target].
  ViGEmPad(
    this.vigem,
    this.target, {
    bool autoConnect = false,
    this.autoUpdate = false,
  }) {
    if (autoConnect) {
      connect();
    }
  }

  void _checkNotDisposed() {
    if (_isDisposed) {
      throw const ViGEmDisposedException();
    }
  }

  void _maybeAutoUpdate() {
    if (autoUpdate) {
      update();
    }
  }

  // ==========================================
  // Device Lifecycle & Properties
  // ==========================================

  /// Whether this gamepad instance has been disposed.
  bool get isDisposed => _isDisposed;

  /// Whether this virtual controller is currently plugged into the system bus.
  bool get isAttached {
    if (_isDisposed) return false;
    return vigem.ffi.vigemTargetIsAttached(target) != 0;
  }

  /// Alias for [isAttached].
  bool get isConnected => isAttached;

  /// Retrieves the XInput user/player index (1..4) assigned to this gamepad by Windows.
  /// Returns `null` if the device is not attached or index is unassigned.
  int? get userIndex {
    _checkNotDisposed();
    if (!isAttached) return null;

    final result = vigem.ffi.vigemTargetX360GetUserIndex(
      vigem.client,
      target,
      _userIndexPtr,
    );
    if (VigemErrors.fromInt(result).isSuccess) {
      return _userIndexPtr.value;
    }
    return null;
  }

  /// Vendor ID (VID) for this virtual controller.
  int get vendorId {
    _checkNotDisposed();
    return vigem.ffi.vigemTargetGetVID(target);
  }

  /// Sets the Vendor ID (VID). Typically configured prior to plugging in.
  set vendorId(int vid) {
    _checkNotDisposed();
    vigem.ffi.vigemTargetSetVID(target, vid);
  }

  /// Product ID (PID) for this virtual controller.
  int get productId {
    _checkNotDisposed();
    return vigem.ffi.vigemTargetGetPID(target);
  }

  /// Sets the Product ID (PID). Typically configured prior to plugging in.
  set productId(int pid) {
    _checkNotDisposed();
    vigem.ffi.vigemTargetSetPID(target, pid);
  }

  /// Connects / plugs in this virtual gamepad to the system bus.
  ///
  /// Does not throw if already connected.
  void connect() {
    _checkNotDisposed();
    final result = vigem.ffi.vigemTargetAdd(vigem.client, target);
    final error = VigemErrors.fromInt(result);
    if (error == VigemErrors.VIGEM_ERROR_ALREADY_CONNECTED) {
      return;
    }
    VIGEM_SUCCESS_OR_THROW(result);
  }

  /// Disconnects / unplugs this virtual gamepad from the system bus.
  ///
  /// Does not throw if not currently plugged in.
  void disconnect() {
    if (_isDisposed) return;
    final result = vigem.ffi.vigemTargetRemove(vigem.client, target);
    final error = VigemErrors.fromInt(result);
    if (error == VigemErrors.VIGEM_ERROR_TARGET_NOT_PLUGGED_IN) {
      return;
    }
    VIGEM_SUCCESS_OR_THROW(result);
  }

  /// Disconnects, frees native target resources, and removes this pad from the manager.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    try {
      disconnect();
    } catch (_) {}

    try {
      vigem.ffi.vigemTargetFree(target);
    } catch (_) {}

    calloc.free(_reportPtr);
    calloc.free(_outputPtr);
    calloc.free(_userIndexPtr);

    vigem.removePadInternal(this);
  }

  // ==========================================
  // Normalization Helpers
  // ==========================================

  /// Normalizes a bipolar input value (-1.0 to +1.0) into the raw thumbstick range (-32768 to 32767).
  static int normalizeThumb(double value) {
    final clamped = value.clamp(-1.0, 1.0);
    if (clamped == 0.0) return thumbCenter;
    if (clamped < 0.0) {
      return (clamped * 32768.0).round().clamp(thumbMin, thumbMax);
    }
    return (clamped * 32767.0).round().clamp(thumbMin, thumbMax);
  }

  /// Normalizes a unipolar input value (0.0 to 1.0) into the raw trigger range (0 to 255).
  static int normalizeTrigger(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return (clamped * 255.0).round().clamp(triggerMin, triggerMax);
  }

  // ==========================================
  // State Inspection Getters
  // ==========================================

  /// Current raw buttons bitmask.
  int get buttons => _wButtons;

  /// Current raw left trigger value (0..255).
  int get leftTrigger => _bLeftTrigger;

  /// Current raw right trigger value (0..255).
  int get rightTrigger => _bRightTrigger;

  /// Current raw left thumbstick X position (-32768..32767).
  int get leftThumbX => _sThumbLX;

  /// Current raw left thumbstick Y position (-32768..32767).
  int get leftThumbY => _sThumbLY;

  /// Current raw right thumbstick X position (-32768..32767).
  int get rightThumbX => _sThumbRX;

  /// Current raw right thumbstick Y position (-32768..32767).
  int get rightThumbY => _sThumbRY;

  /// Normalized left trigger position (0.0 to 1.0).
  double get leftTriggerNormalized => _bLeftTrigger / 255.0;

  /// Normalized right trigger position (0.0 to 1.0).
  double get rightTriggerNormalized => _bRightTrigger / 255.0;

  /// Normalized left thumbstick X position (-1.0 to +1.0).
  double get leftThumbXNormalized =>
      _sThumbLX < 0 ? _sThumbLX / 32768.0 : _sThumbLX / 32767.0;

  /// Normalized left thumbstick Y position (-1.0 to +1.0).
  double get leftThumbYNormalized =>
      _sThumbLY < 0 ? _sThumbLY / 32768.0 : _sThumbLY / 32767.0;

  /// Normalized right thumbstick X position (-1.0 to +1.0).
  double get rightThumbXNormalized =>
      _sThumbRX < 0 ? _sThumbRX / 32768.0 : _sThumbRX / 32767.0;

  /// Normalized right thumbstick Y position (-1.0 to +1.0).
  double get rightThumbYNormalized =>
      _sThumbRY < 0 ? _sThumbRY / 32768.0 : _sThumbRY / 32767.0;

  /// Current D-Pad direction derived from button state.
  XusbDpadDirection get dpadDirection => XusbDpadDirection.fromMask(_wButtons);

  // ==========================================
  // Button Controls
  // ==========================================

  /// Checks if [button] is currently pressed in the local state.
  bool isButtonPressed(XusbButton button) => button.isPressedIn(_wButtons);

  /// Sets the state of a specific [button].
  void setButton(XusbButton button, bool isPressed) {
    if (isPressed) {
      _wButtons |= button.value;
    } else {
      _wButtons &= ~button.value;
    }
    _maybeAutoUpdate();
  }

  /// Presses [button].
  void pressButton(XusbButton button) => setButton(button, true);

  /// Releases [button].
  void releaseButton(XusbButton button) => setButton(button, false);

  /// Toggles the current state of [button].
  void toggleButton(XusbButton button) =>
      setButton(button, !isButtonPressed(button));

  /// Overwrites the full raw button bitmask.
  void setButtons(int rawButtonsMask) {
    _wButtons = rawButtonsMask & 0xFFFF;
    _maybeAutoUpdate();
  }

  // Named Button Helpers
  void setA(bool isPressed) => setButton(XusbButton.XUSB_GAMEPAD_A, isPressed);
  void pressA() => pressButton(XusbButton.XUSB_GAMEPAD_A);
  void releaseA() => releaseButton(XusbButton.XUSB_GAMEPAD_A);

  void setB(bool isPressed) => setButton(XusbButton.XUSB_GAMEPAD_B, isPressed);
  void pressB() => pressButton(XusbButton.XUSB_GAMEPAD_B);
  void releaseB() => releaseButton(XusbButton.XUSB_GAMEPAD_B);

  void setX(bool isPressed) => setButton(XusbButton.XUSB_GAMEPAD_X, isPressed);
  void pressX() => pressButton(XusbButton.XUSB_GAMEPAD_X);
  void releaseX() => releaseButton(XusbButton.XUSB_GAMEPAD_X);

  void setY(bool isPressed) => setButton(XusbButton.XUSB_GAMEPAD_Y, isPressed);
  void pressY() => pressButton(XusbButton.XUSB_GAMEPAD_Y);
  void releaseY() => releaseButton(XusbButton.XUSB_GAMEPAD_Y);

  void setLB(bool isPressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_LEFT_SHOULDER, isPressed);
  void pressLB() => pressButton(XusbButton.XUSB_GAMEPAD_LEFT_SHOULDER);
  void releaseLB() => releaseButton(XusbButton.XUSB_GAMEPAD_LEFT_SHOULDER);

  void setRB(bool isPressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_RIGHT_SHOULDER, isPressed);
  void pressRB() => pressButton(XusbButton.XUSB_GAMEPAD_RIGHT_SHOULDER);
  void releaseRB() => releaseButton(XusbButton.XUSB_GAMEPAD_RIGHT_SHOULDER);

  void setStart(bool isPressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_START, isPressed);
  void pressStart() => pressButton(XusbButton.XUSB_GAMEPAD_START);
  void releaseStart() => releaseButton(XusbButton.XUSB_GAMEPAD_START);

  void setBack(bool isPressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_BACK, isPressed);
  void pressBack() => pressButton(XusbButton.XUSB_GAMEPAD_BACK);
  void releaseBack() => releaseButton(XusbButton.XUSB_GAMEPAD_BACK);

  void setGuide(bool isPressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_GUIDE, isPressed);
  void pressGuide() => pressButton(XusbButton.XUSB_GAMEPAD_GUIDE);
  void releaseGuide() => releaseButton(XusbButton.XUSB_GAMEPAD_GUIDE);

  void setLeftThumbButton(bool isPressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_LEFT_THUMB, isPressed);
  void pressLeftThumbButton() => pressButton(XusbButton.XUSB_GAMEPAD_LEFT_THUMB);
  void releaseLeftThumbButton() =>
      releaseButton(XusbButton.XUSB_GAMEPAD_LEFT_THUMB);

  void setRightThumbButton(bool isPressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_RIGHT_THUMB, isPressed);
  void pressRightThumbButton() =>
      pressButton(XusbButton.XUSB_GAMEPAD_RIGHT_THUMB);
  void releaseRightThumbButton() =>
      releaseButton(XusbButton.XUSB_GAMEPAD_RIGHT_THUMB);

  // ==========================================
  // D-Pad Controls
  // ==========================================

  /// Sets the D-Pad to a specific [direction].
  void setDpadDirection(XusbDpadDirection direction) {
    const dpadMask =
        0x0001 | 0x0002 | 0x0004 | 0x0008; // UP | DOWN | LEFT | RIGHT
    _wButtons = (_wButtons & ~dpadMask) | direction.buttonMask;
    _maybeAutoUpdate();
  }

  /// Sets individual D-Pad cardinal directions. Unspecified directions are left unchanged.
  void setDpad({bool? up, bool? down, bool? left, bool? right}) {
    if (up != null) setButton(XusbButton.XUSB_GAMEPAD_DPAD_UP, up);
    if (down != null) setButton(XusbButton.XUSB_GAMEPAD_DPAD_DOWN, down);
    if (left != null) setButton(XusbButton.XUSB_GAMEPAD_DPAD_LEFT, left);
    if (right != null) setButton(XusbButton.XUSB_GAMEPAD_DPAD_RIGHT, right);
  }

  void setDpadUp(bool pressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_DPAD_UP, pressed);
  void setDpadDown(bool pressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_DPAD_DOWN, pressed);
  void setDpadLeft(bool pressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_DPAD_LEFT, pressed);
  void setDpadRight(bool pressed) =>
      setButton(XusbButton.XUSB_GAMEPAD_DPAD_RIGHT, pressed);

  /// Resets all D-Pad directional buttons to released.
  void resetDpad() => setDpadDirection(XusbDpadDirection.centered);

  // ==========================================
  // Trigger Controls
  // ==========================================

  /// Sets the raw Left Trigger value (0..255).
  void setLeftTrigger(int rawValue) {
    _bLeftTrigger = rawValue.clamp(triggerMin, triggerMax);
    _maybeAutoUpdate();
  }

  /// Sets the raw Right Trigger value (0..255).
  void setRightTrigger(int rawValue) {
    _bRightTrigger = rawValue.clamp(triggerMin, triggerMax);
    _maybeAutoUpdate();
  }

  /// Sets both triggers with raw values (0..255).
  void setTriggers(int leftRaw, int rightRaw) {
    _bLeftTrigger = leftRaw.clamp(triggerMin, triggerMax);
    _bRightTrigger = rightRaw.clamp(triggerMin, triggerMax);
    _maybeAutoUpdate();
  }

  /// Sets the Left Trigger using a normalized value (0.0 to 1.0).
  void setLeftTriggerNormalized(double value) =>
      setLeftTrigger(normalizeTrigger(value));

  /// Sets the Right Trigger using a normalized value (0.0 to 1.0).
  void setRightTriggerNormalized(double value) =>
      setRightTrigger(normalizeTrigger(value));

  /// Sets both triggers using normalized values (0.0 to 1.0).
  void setTriggersNormalized(double left, double right) {
    _bLeftTrigger = normalizeTrigger(left);
    _bRightTrigger = normalizeTrigger(right);
    _maybeAutoUpdate();
  }

  // ==========================================
  // Thumbstick & Axis Controls
  // ==========================================

  /// Sets raw Left Thumbstick X position (-32768..32767).
  void setLeftThumbX(int rawValue) {
    _sThumbLX = rawValue.clamp(thumbMin, thumbMax);
    _maybeAutoUpdate();
  }

  /// Sets raw Left Thumbstick Y position (-32768..32767).
  void setLeftThumbY(int rawValue) {
    _sThumbLY = rawValue.clamp(thumbMin, thumbMax);
    _maybeAutoUpdate();
  }

  /// Sets both Left Thumbstick axes (-32768..32767).
  void setLeftThumb(int x, int y) {
    _sThumbLX = x.clamp(thumbMin, thumbMax);
    _sThumbLY = y.clamp(thumbMin, thumbMax);
    _maybeAutoUpdate();
  }

  /// Sets Left Thumbstick X with normalized value (-1.0 to +1.0).
  void setLeftThumbXNormalized(double value) =>
      setLeftThumbX(normalizeThumb(value));

  /// Sets Left Thumbstick Y with normalized value (-1.0 to +1.0).
  void setLeftThumbYNormalized(double value) =>
      setLeftThumbY(normalizeThumb(value));

  /// Sets Left Thumbstick (X, Y) with normalized values (-1.0 to +1.0).
  void setLeftThumbNormalized(double x, double y) {
    _sThumbLX = normalizeThumb(x);
    _sThumbLY = normalizeThumb(y);
    _maybeAutoUpdate();
  }

  /// Sets raw Right Thumbstick X position (-32768..32767).
  void setRightThumbX(int rawValue) {
    _sThumbRX = rawValue.clamp(thumbMin, thumbMax);
    _maybeAutoUpdate();
  }

  /// Sets raw Right Thumbstick Y position (-32768..32767).
  void setRightThumbY(int rawValue) {
    _sThumbRY = rawValue.clamp(thumbMin, thumbMax);
    _maybeAutoUpdate();
  }

  /// Sets both Right Thumbstick axes (-32768..32767).
  void setRightThumb(int x, int y) {
    _sThumbRX = x.clamp(thumbMin, thumbMax);
    _sThumbRY = y.clamp(thumbMin, thumbMax);
    _maybeAutoUpdate();
  }

  /// Sets Right Thumbstick X with normalized value (-1.0 to +1.0).
  void setRightThumbXNormalized(double value) =>
      setRightThumbX(normalizeThumb(value));

  /// Sets Right Thumbstick Y with normalized value (-1.0 to +1.0).
  void setRightThumbYNormalized(double value) =>
      setRightThumbY(normalizeThumb(value));

  /// Sets Right Thumbstick (X, Y) with normalized values (-1.0 to +1.0).
  void setRightThumbNormalized(double x, double y) {
    _sThumbRX = normalizeThumb(x);
    _sThumbRY = normalizeThumb(y);
    _maybeAutoUpdate();
  }

  // ==========================================
  // Steering Wheel & Pedal Mappings
  // ==========================================

  /// Steering wheel helper: maps normalized value (-1.0 to +1.0) to Left Thumb X.
  void setSteering(double normalizedValue) =>
      setLeftThumbXNormalized(normalizedValue);

  /// Throttle pedal helper: maps normalized value (0.0 to 1.0) to Right Trigger.
  void setThrottle(double normalizedValue) =>
      setRightTriggerNormalized(normalizedValue);

  /// Brake pedal helper: maps normalized value (0.0 to 1.0) to Left Trigger.
  void setBrake(double normalizedValue) =>
      setLeftTriggerNormalized(normalizedValue);

  /// Clutch pedal helper: maps normalized value (-1.0 to 1.0 or 0.0 to 1.0) to Left Thumb Y.
  void setClutch(double normalizedValue) =>
      setLeftThumbYNormalized(normalizedValue);

  /// Handbrake button helper: presses or releases [button] (default: A).
  void setHandbrake(
    bool isEngaged, {
    XusbButton button = XusbButton.XUSB_GAMEPAD_A,
  }) {
    setButton(button, isEngaged);
  }

  // ==========================================
  // Resets
  // ==========================================

  /// Resets all controls (buttons, triggers, thumbsticks) to neutral/zero state.
  void reset() {
    _wButtons = 0;
    _bLeftTrigger = 0;
    _bRightTrigger = 0;
    _sThumbLX = 0;
    _sThumbLY = 0;
    _sThumbRX = 0;
    _sThumbRY = 0;
    _maybeAutoUpdate();
  }

  /// Resets all buttons to released state.
  void resetButtons() {
    _wButtons = 0;
    _maybeAutoUpdate();
  }

  /// Resets both triggers to 0.
  void resetTriggers() {
    _bLeftTrigger = 0;
    _bRightTrigger = 0;
    _maybeAutoUpdate();
  }

  /// Centers both thumbsticks.
  void resetThumbs() {
    _sThumbLX = 0;
    _sThumbLY = 0;
    _sThumbRX = 0;
    _sThumbRY = 0;
    _maybeAutoUpdate();
  }

  // ==========================================
  // State Submissions & Force Feedback Output
  // ==========================================

  /// Submits the current buffered controller state to the virtual device.
  void update() {
    _checkNotDisposed();

    _reportPtr.ref.wButtons = _wButtons;
    _reportPtr.ref.bLeftTrigger = _bLeftTrigger;
    _reportPtr.ref.bRightTrigger = _bRightTrigger;
    _reportPtr.ref.sThumbLX = _sThumbLX;
    _reportPtr.ref.sThumbLY = _sThumbLY;
    _reportPtr.ref.sThumbRX = _sThumbRX;
    _reportPtr.ref.sThumbRY = _sThumbRY;

    final result = vigem.ffi.vigemTargetX360Update(
      vigem.client,
      target,
      _reportPtr.ref,
    );
    VIGEM_SUCCESS_OR_THROW(result);
  }

  /// Directly sends a raw [XUSB_REPORT] struct to the virtual gamepad.
  void updateReport(XUSB_REPORT report) {
    _checkNotDisposed();

    _wButtons = report.wButtons;
    _bLeftTrigger = report.bLeftTrigger;
    _bRightTrigger = report.bRightTrigger;
    _sThumbLX = report.sThumbLX;
    _sThumbLY = report.sThumbLY;
    _sThumbRX = report.sThumbRX;
    _sThumbRY = report.sThumbRY;

    final result = vigem.ffi.vigemTargetX360Update(
      vigem.client,
      target,
      report,
    );
    VIGEM_SUCCESS_OR_THROW(result);
  }

  /// Queries the host force feedback (rumble motors) and LED indicator state.
  ///
  /// Returns [XusbOutput] containing motor speeds and quadrant LED index.
  XusbOutput getOutput() {
    _checkNotDisposed();
    final getOutputFunc = vigem.ffi.vigemTargetX360GetOutput;
    if (getOutputFunc == null) {
      return const XusbOutput();
    }

    final result = getOutputFunc(vigem.client, target, _outputPtr);
    if (!VigemErrors.fromInt(result).isSuccess) {
      return const XusbOutput();
    }

    return XusbOutput(
      largeMotor: _outputPtr.ref.LargeMotor,
      smallMotor: _outputPtr.ref.SmallMotor,
      ledNumber: _outputPtr.ref.LedNumber,
    );
  }

  @override
  String toString() =>
      'ViGEmPad(isAttached: $isAttached, userIndex: $userIndex, buttons: 0x${_wButtons.toRadixString(16)}, '
      'LT: $_bLeftTrigger, RT: $_bRightTrigger, LX: $_sThumbLX, LY: $_sThumbLY, RX: $_sThumbRX, RY: $_sThumbRY)';
}
