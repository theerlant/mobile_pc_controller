import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Run an executable
bool runProcess(
  String executable, {
  bool asAdmin = false,
  String? parameters,
  String? workingDirectory,
}) {
  return using<bool>((arena) {
    final result = ShellExecute(
      null,
      asAdmin ? arena.pcwstr('runas') : null,
      arena.pcwstr(executable),
      parameters == null ? null : arena.pcwstr(parameters),
      workingDirectory == null ? null : arena.pcwstr(workingDirectory),
      SW_SHOWNORMAL,
    );

    // ShellExecute returns a value > 32 on success. Values <= 32 are
    // Windows error codes (e.g. 5 = ERROR_ACCESS_DENIED when the user
    // cancels the UAC prompt). HINSTANCE wraps a native pointer, so we
    // compare its raw address.
    return result.address > 32;
  });
}

// ignore: constant_identifier_names
const SEE_MASK_NOCLOSEPROCESS = 0x00000040;

/// Run an executable and return the handle
HANDLE runProcessHandle(
  String executable, {
  bool asAdmin = false,
  String? parameters,
  String? workingDirectory,
  bool showWindow = true,
}) {
  return using<HANDLE>((arena) {
    // Register the struct to the arena so it is freed automatically when the block exits
    final pSei = arena.using(calloc<SHELLEXECUTEINFO>(), calloc.free);

    pSei.ref.cbSize = sizeOf<SHELLEXECUTEINFO>();
    pSei.ref.fMask = SEE_MASK_NOCLOSEPROCESS;
    pSei.ref.hwnd = nullptr as HWND;
    pSei.ref.lpVerb = asAdmin ? arena.pwstr('runas') : nullptr as PWSTR;
    pSei.ref.lpFile = arena.pwstr(executable);
    pSei.ref.lpParameters = parameters == null
        ? nullptr as PWSTR
        : arena.pwstr(parameters);
    pSei.ref.lpDirectory = workingDirectory == null
        ? nullptr as PWSTR
        : arena.pwstr(workingDirectory);
    pSei.ref.nShow = showWindow ? SW_SHOW : SW_HIDE;

    final execResult = ShellExecuteEx(pSei);

    if (!execResult.value) {
      throw RunAsAdminException(execResult.error.code);
    }

    if (pSei.ref.hProcess.isNull) {
      // Handle edge case where ShellExecuteEx succeeds but yields no process handle
      throw RunAsAdminException(-1);
    }

    // Safely returns the handle value out of the scope before the arena tears down pSei
    return pSei.ref.hProcess;
  });
}

class RunAsAdminException implements Exception {
  final int errorCode;
  RunAsAdminException(this.errorCode);

  @override
  String toString() => 'RunAsAdminException fails with error: $errorCode';
}
