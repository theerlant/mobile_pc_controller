import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

bool runAsAdmin(
  String executable, {
  String? parameters,
  String? workingDirectory,
}) {
  return using<bool>((arena) {
    final result = ShellExecute(
      null,
      arena.pcwstr('runas'),
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
