import 'dart:async';
import 'dart:io';

import 'package:desktop_client/services/vjoy/vjoy.dart' as vjoyApi;
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late final vjoyApi.Vjoy vJoy;
  try {
    vJoy = vjoyApi.Vjoy.fromRegistry();
  } catch (e) {
    print("Error loading vJoy from registry: $e");
  }

  if (!vJoy.isEnabled) {
    print("Enabling vJoy device driver...");

    final result = await vJoy.enableDriver();

    if (!result) {
      print("Failed enabling vJoy device driver!");
      exit(-1);
    }
  }
  assert(vJoy.isEnabled);
  print('vJoy device driver enabled');

  // Configure it with 32 btn, 4 axis, cont pov hats
  print("Configuring vJoy device on index 1...");
  await vJoy.configureDevice(
    1,
    numButtons: 32,
    numAnalogPovs: 1,
    numDiscretePovs: 0,
  );

  await Future.delayed(Duration(seconds: 3));
}
