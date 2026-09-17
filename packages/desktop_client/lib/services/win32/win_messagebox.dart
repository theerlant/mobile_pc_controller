import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

final MESSAGEBOX_STYLE MB_STYLE_ERROR_OK = MB_OK | MB_ICONERROR;
final MESSAGEBOX_STYLE MB_STYLE_WARNING_OK = MB_OK | MB_ICONWARNING;

void winMessageBox({
  String title = "PC Controller Client",
  required String message,
  MESSAGEBOX_STYLE uType = MB_OK,
}) {
  using((arena) {
    final Win32Result() = MessageBox(
      null,
      arena.pcwstr(message),
      arena.pcwstr(title),
      uType,
    );
  });
}
