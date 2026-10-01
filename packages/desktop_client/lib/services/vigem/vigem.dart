import 'dart:collection';
import 'dart:ffi';

import 'package:desktop_client/services/vigem/vigem_error.dart';
import 'package:desktop_client/services/vigem/vigem_ffi.dart';
import 'package:desktop_client/services/vigem/vigem_pad.dart';
import 'package:desktop_client/services/vigem/vigem_types_common.dart';

export 'vigem_error.dart';
export 'vigem_ffi.dart';
export 'vigem_pad.dart';
export 'vigem_types_common.dart';
export 'vigem_types_xusb.dart';

/// High-level ViGEm service, driver manager, and virtual gamepad factory.
class ViGEm {
  static ViGEm? _instance;

  /// Low-level FFI binding.
  final ViGEmFFI ffi;

  /// Main ViGEm client native pointer handle.
  late final PVIGEM_CLIENT client;

  /// Internal list of active virtual pads.
  final List<ViGEmPad> _pads = [];

  bool _isDisposed = false;
  bool _isConnected = false;

  /// Maximum number of concurrent virtual gamepads supported (default: 4 for XInput).
  final int maxPads;

  ViGEm._({required this.ffi, this.maxPads = 4}) {
    try {
      client = ffi.vigemAlloc();
      if (client == nullptr || client.address == 0) {
        throw const ViGEmClientAllocException();
      }

      final connectResult = ffi.vigemConnect(client);
      VIGEM_SUCCESS_OR_THROW(connectResult);
      _isConnected = true;
    } catch (e) {
      dispose();
      rethrow;
    }
  }

  /// Default singleton factory, loading `ViGEmClient.dll` or process library.
  factory ViGEm({int maxPads = 4}) {
    if (_instance == null || _instance!._isDisposed) {
      final ffi = ViGEmFFI.open();
      _instance = ViGEm._(ffi: ffi, maxPads: maxPads);
    }
    return _instance!;
  }

  /// Initialize ViGEm by explicitly opening the DLL at [dllPath].
  factory ViGEm.fromPath(String dllPath, {int maxPads = 4}) {
    final ffi = ViGEmFFI.open(dllPath);
    return ViGEm._(ffi: ffi, maxPads: maxPads);
  }

  /// Initialize ViGEm from an existing [DynamicLibrary].
  factory ViGEm.fromLibrary(DynamicLibrary library, {int maxPads = 4}) {
    final ffi = ViGEmFFI.fromLibrary(library);
    return ViGEm._(ffi: ffi, maxPads: maxPads);
  }

  /// Initialize ViGEm from an existing [ViGEmFFI] instance.
  factory ViGEm.fromFFI(ViGEmFFI ffi, {int maxPads = 4}) {
    return ViGEm._(ffi: ffi, maxPads: maxPads);
  }

  /// Reset the singleton instance (e.g. for testing or re-initialization).
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  // ==========================================
  // Client Status & Properties
  // ==========================================

  /// Whether this ViGEm manager has been disposed.
  bool get isDisposed => _isDisposed;

  /// Whether the client is currently connected to the ViGEmBus kernel driver.
  bool get isConnected => _isConnected && !_isDisposed;

  /// Unmodifiable view of currently active virtual pads managed by this instance.
  List<ViGEmPad> get pads => UnmodifiableListView(_pads);

  /// Number of active virtual pads.
  int get padCount => _pads.length;

  void _checkNotDisposed() {
    if (_isDisposed) {
      throw const ViGEmDisposedException();
    }
  }

  // ==========================================
  // Gamepad Allocation & Management
  // ==========================================

  /// Creates and allocates a new emulated Xbox 360 controller ([ViGEmPad]).
  ///
  /// - [vendorId]: Optional custom Vendor ID.
  /// - [productId]: Optional custom Product ID.
  /// - [autoConnect]: If true, immediately attaches/plugs the controller into Windows.
  /// - [autoUpdate]: If true, every axis/button setter automatically pushes updates to the pad.
  ///
  /// Throws [ViGEmPadFullException] if [padCount] has reached [maxPads].
  /// Throws [ViGEmNativeException] if target allocation or connection fails.
  ViGEmPad createPad({
    int? vendorId,
    int? productId,
    bool autoConnect = false,
    bool autoUpdate = false,
  }) {
    _checkNotDisposed();

    if (_pads.length >= maxPads) {
      throw const ViGEmPadFullException();
    }

    final target = ffi.vigemTargetX360Alloc();
    if (target == nullptr || target.address == 0) {
      throw const ViGEmClientAllocException('Failed to allocate ViGEm target');
    }

    if (vendorId != null) {
      ffi.vigemTargetSetVID(target, vendorId);
    }
    if (productId != null) {
      ffi.vigemTargetSetPID(target, productId);
    }

    final pad = ViGEmPad(
      this,
      target,
      autoConnect: autoConnect,
      autoUpdate: autoUpdate,
    );

    _pads.add(pad);
    return pad;
  }

  /// Internal callback used by [ViGEmPad.dispose] to unregister itself.
  void removePadInternal(ViGEmPad pad) {
    _pads.remove(pad);
  }

  /// Disposes and removes a specific [pad] from this manager.
  void removePad(ViGEmPad pad) {
    pad.dispose();
  }

  /// Resets all controls across all managed pads to neutral zero states and updates them.
  void resetAll() {
    _checkNotDisposed();
    for (final pad in _pads) {
      if (pad.isAttached) {
        pad.reset();
        pad.update();
      }
    }
  }

  /// Disconnects all active virtual pads without disposing them.
  void disconnectAll() {
    _checkNotDisposed();
    for (final pad in _pads) {
      pad.disconnect();
    }
  }

  /// Disconnects and disposes all virtual pads, disconnects from the ViGEm bus driver,
  /// and frees native client memory.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final pad in List<ViGEmPad>.from(_pads)) {
      pad.dispose();
    }
    _pads.clear();

    if (_isConnected) {
      try {
        ffi.vigemDisconnect(client);
      } catch (_) {}
      _isConnected = false;
    }

    try {
      ffi.vigemFree(client);
    } catch (_) {}

    if (_instance == this) {
      _instance = null;
    }
  }
}
