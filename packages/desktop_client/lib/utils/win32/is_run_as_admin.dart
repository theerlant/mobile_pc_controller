import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Returns true if the process is running with administrative privileges.
bool isRunAsAdmin({HANDLE? handle}) {
  bool result = false;

  final pHToken = calloc<Pointer<Void>>();
  pHToken.value = nullptr;

  // Open the primary access token for the current process
  if (OpenProcessToken(
    handle ?? GetCurrentProcess(),
    TOKEN_QUERY,
    pHToken,
  ).value) {
    final pElevation = calloc<TOKEN_ELEVATION>();
    final cbSize = sizeOf<TOKEN_ELEVATION>();

    final pCbSize = calloc<Uint32>();
    pCbSize.value = cbSize;

    // Query the elevation status of the token
    if (GetTokenInformation(
      pHToken.value as HANDLE,
      TokenElevation,
      pElevation,
      cbSize,
      pCbSize,
    ).value) {
      result = pElevation.ref.TokenIsElevated != 0;
    }

    // Clean up
    calloc.free(pElevation);
    calloc.free(pCbSize);
  }

  // Clean up token handle
  if (pHToken.isNotNull) {
    CloseHandle(pHToken.value as HANDLE);
  }

  // Clean up
  calloc.free(pHToken);

  return result;
}
