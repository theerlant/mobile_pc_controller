import 'package:desktop_client/services/vjoy/vJoy_interface.dart';
import 'package:desktop_client/services/win32/win_messagebox.dart';
import 'package:win32/win32.dart';

void main() {
  final interface = Vjoyinterface.instance;

  if (interface.vJoyEnabled()) {
    winMessageBox(
      message: "vJoy is enabled.",
      uType: MB_OK | MB_ICONINFORMATION,
    );
  } else {
    winMessageBox(
      message: "vJoy Driver is disabled.",
      uType: MB_OK | MB_ICONWARNING,
    );
  }
}
