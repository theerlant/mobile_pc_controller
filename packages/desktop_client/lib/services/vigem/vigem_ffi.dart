import 'dart:ffi';

import 'package:desktop_client/services/vigem/vigem_types_common.dart';
import 'package:desktop_client/services/vigem/vigem_types_xusb.dart';

typedef CVigemAlloc = PVIGEM_CLIENT Function();
typedef DartVigemAlloc = CVigemAlloc;

typedef CVigemFree = Void Function(PVIGEM_CLIENT vigem);
typedef DartVigemFree = void Function(PVIGEM_CLIENT vigem);

typedef CVigemConnect = Int32 Function(PVIGEM_CLIENT vigem);
typedef DartVigemConnect = int Function(PVIGEM_CLIENT vigem);

typedef CVigemDisconnect = CVigemFree;
typedef DartVigemDisconnect = DartVigemFree;

typedef CVigemTargetX360Alloc = PVIGEM_TARGET Function();
typedef DartVigemTargetX360Alloc = CVigemTargetX360Alloc;

typedef CVigemTargetFree = Void Function(PVIGEM_TARGET target);
typedef DartVigemTargetFree = void Function(PVIGEM_TARGET target);

typedef CVigemTargetAdd = Int32 Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
);
typedef DartVigemTargetAdd = int Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
);

typedef CVigemTargetRemove = CVigemTargetAdd;
typedef DartVigemTargetRemove = DartVigemTargetAdd;

typedef CVigemTargetSetVID = Void Function(PVIGEM_TARGET target, Uint16 vid);
typedef DartVigemTargetSetVID = void Function(PVIGEM_TARGET target, int vid);

typedef CVigemTargetSetPID = CVigemTargetSetVID;
typedef DartVigemTargetSetPID = DartVigemTargetSetVID;

typedef CVigemTargetGetVID = Uint16 Function(PVIGEM_TARGET target);
typedef DartVigemTargetGetVID = int Function(PVIGEM_TARGET target);

typedef CVigemTargetGetPID = CVigemTargetGetVID;
typedef DartVigemTargetGetPID = DartVigemTargetGetVID;

typedef CVigemTargetX360Update = Int32 Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
  XUSB_REPORT report,
);
typedef DartVigemTargetX360Update = int Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
  XUSB_REPORT report,
);

typedef CVigemTargetIsAttached = Int32 Function(PVIGEM_TARGET);
typedef DartVigemTargetIsAttached = int Function(PVIGEM_TARGET);

typedef CVigemTargetX360GetUserIndex = Int32 Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
  Pointer<Uint32> index,
);

typedef DartVigemTargetX360GetUserIndex = int Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
  Pointer<Uint32> index,
);

typedef CVigemTargetX360GetOutput = Int32 Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
  PXUSB_OUTPUT_DATA output,
);
typedef DartVigemTargetX360GetOutput = int Function(
  PVIGEM_CLIENT vigem,
  PVIGEM_TARGET target,
  PXUSB_OUTPUT_DATA output,
);

/// Low-level binding wrapper for ViGEmClient.dll C functions.
class ViGEmFFI {
  /// The loaded native dynamic library.
  final DynamicLibrary library;

  late final DartVigemAlloc vigemAlloc;
  late final DartVigemFree vigemFree;
  late final DartVigemConnect vigemConnect;
  late final DartVigemDisconnect vigemDisconnect;

  late final DartVigemTargetX360Alloc vigemTargetX360Alloc;
  late final DartVigemTargetFree vigemTargetFree;
  late final DartVigemTargetAdd vigemTargetAdd;
  late final DartVigemTargetRemove vigemTargetRemove;

  late final DartVigemTargetSetVID vigemTargetSetVID;
  late final DartVigemTargetSetPID vigemTargetSetPID;
  late final DartVigemTargetGetVID vigemTargetGetVID;
  late final DartVigemTargetGetPID vigemTargetGetPID;

  late final DartVigemTargetX360Update vigemTargetX360Update;
  late final DartVigemTargetIsAttached vigemTargetIsAttached;
  late final DartVigemTargetX360GetUserIndex vigemTargetX360GetUserIndex;
  late final DartVigemTargetX360GetOutput? vigemTargetX360GetOutput;

  /// Creates FFI bindings directly from a loaded [DynamicLibrary].
  ViGEmFFI.fromLibrary(this.library) {
    _registerMethods();
  }

  /// Attempts to load `ViGEmClient.dll` from [dllPath], the default DLL name,
  /// or from the current process.
  factory ViGEmFFI.open([String? dllPath]) {
    if (dllPath != null) {
      return ViGEmFFI.fromLibrary(DynamicLibrary.open(dllPath));
    }
    try {
      return ViGEmFFI.fromLibrary(DynamicLibrary.open('ViGEmClient.dll'));
    } catch (_) {
      return ViGEmFFI.fromLibrary(DynamicLibrary.executable());
    }
  }

  void _registerMethods() {
    vigemAlloc = library.lookupFunction<CVigemAlloc, DartVigemAlloc>(
      'vigem_alloc',
    );
    vigemFree = library.lookupFunction<CVigemFree, DartVigemFree>('vigem_free');
    vigemConnect = library.lookupFunction<CVigemConnect, DartVigemConnect>(
      'vigem_connect',
    );
    vigemDisconnect = library
        .lookupFunction<CVigemDisconnect, DartVigemDisconnect>(
          'vigem_disconnect',
        );

    vigemTargetX360Alloc = library
        .lookupFunction<CVigemTargetX360Alloc, DartVigemTargetX360Alloc>(
          'vigem_target_x360_alloc',
        );
    vigemTargetFree = library
        .lookupFunction<CVigemTargetFree, DartVigemTargetFree>(
          'vigem_target_free',
        );
    vigemTargetAdd = library
        .lookupFunction<CVigemTargetAdd, DartVigemTargetAdd>(
          'vigem_target_add',
        );
    vigemTargetRemove = library
        .lookupFunction<CVigemTargetRemove, DartVigemTargetRemove>(
          'vigem_target_remove',
        );

    vigemTargetSetVID = library
        .lookupFunction<CVigemTargetSetVID, DartVigemTargetSetVID>(
          'vigem_target_set_vid',
        );
    vigemTargetSetPID = library
        .lookupFunction<CVigemTargetSetPID, DartVigemTargetSetPID>(
          'vigem_target_set_pid',
        );
    vigemTargetGetVID = library
        .lookupFunction<CVigemTargetGetVID, DartVigemTargetGetVID>(
          'vigem_target_get_vid',
        );
    vigemTargetGetPID = library
        .lookupFunction<CVigemTargetGetPID, DartVigemTargetGetPID>(
          'vigem_target_get_pid',
        );

    vigemTargetX360Update = library
        .lookupFunction<CVigemTargetX360Update, DartVigemTargetX360Update>(
          'vigem_target_x360_update',
        );
    vigemTargetIsAttached = library
        .lookupFunction<CVigemTargetIsAttached, DartVigemTargetIsAttached>(
          'vigem_target_is_attached',
        );
    vigemTargetX360GetUserIndex = library
        .lookupFunction<
          CVigemTargetX360GetUserIndex,
          DartVigemTargetX360GetUserIndex
        >('vigem_target_x360_get_user_index');

    try {
      vigemTargetX360GetOutput = library
          .lookupFunction<
            CVigemTargetX360GetOutput,
            DartVigemTargetX360GetOutput
          >('vigem_target_x360_get_output');
    } catch (_) {
      try {
        vigemTargetX360GetOutput = library
            .lookupFunction<
              CVigemTargetX360GetOutput,
              DartVigemTargetX360GetOutput
            >('vigem_target_x360_await_output');
      } catch (_) {
        vigemTargetX360GetOutput = null;
      }
    }
  }
}
