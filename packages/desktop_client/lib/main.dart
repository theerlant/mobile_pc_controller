import 'dart:io';

import 'package:desktop_client/services/vjoy/vjoy.dart';
import 'package:desktop_client/utils/win32/run_as_admin.dart';
import 'package:desktop_client/utils/win32/win_messagebox.dart';

void main() async {
  late final Vjoy vjoy;
  try {
    vjoy = Vjoy.fromRegistry();
  } on VjoyError catch (err) {
    winMessageBox(message: err.message, uType: MB_STYLE_ERROR_OK);
    exit(-1);
  } catch (err) {
    winMessageBox(
      message: 'Failed to initialize vJoy: $err',
      uType: MB_STYLE_ERROR_OK,
    );
    exit(-1);
  }

  final interface = vjoy.ffi;

  if (!interface.vJoyEnabled()) {
    try {
      final target = vjoy.configExePath;

      if (!runAsAdmin(target, parameters: "enable on")) {
        winMessageBox(
          message: "Failed to run vJoyConfig.exe to enable vJoy device.\nTry enabling manually from 'Configure vJoy' or 'vJoyConf.exe'",
          uType: MB_STYLE_ERROR_OK,
        );
        exit(-1);
      }
    } catch (err) {
      print('Failed to run vJoyConfig.exe: $err');
    }
  }

  final vJoyInfo = (
    interface.getvJoyManufacturerString(),
    interface.getvJoyProductString(),
    interface.getvJoySerialNumberString(),
  );
  print(
    "Found vJoy Device -> Vendor: ${vJoyInfo.$1} | Product: ${vJoyInfo.$2} | S/N: ${vJoyInfo.$3}",
  );

  final (match: isVersionMatch, :dllVer, :drvVer) = interface.driverMatch();
  print("Driver version: $drvVer, Dll version: $dllVer");
  if (!isVersionMatch) {
    winMessageBox(
      message:
          "vJoyInterface version ($dllVer) do not match installed driver version ($drvVer).",
    );
  }

  exit(0);
}
