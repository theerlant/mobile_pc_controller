import 'dart:io';

import 'package:desktop_client/services/vigem/vigem.dart';
import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';

/// This must be run [flutter run -d windows]
/// Because its depend on ViGEmClient.dll alongside the executable.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final vigem = ViGEm();

  // Create a pad and connects it.
  final padOne = vigem.createPad(
    vendorId: 0xDEAD,
    productId: 0xBEEF,
    autoConnect: true,
    autoUpdate: true,
  );

  // Find it with gamepads
  final detectedPads = await Gamepads.list();
  String? gamepadId;
  for (final pad in detectedPads) {
    if (pad.vendorId == 0xDEAD && pad.productId == 0xBEEF) {
      gamepadId = pad.id;
      debugPrint("gamepads detected at ${pad.id}!");
      break;
    }
  }

  if (gamepadId == null) {
    debugPrint("[ERROR] Cannot find pad with vendor: 0xDEAD & product: 0xBEEF");
    return;
  }

  // Add a listener to capture normalized events
  bool isAPressed = false;
  final subscription = Gamepads.normalizedEvents.listen((event) {
    if (event.gamepadId == gamepadId) {
      if (event.button == GamepadButton.a) {
        isAPressed = event.value > 0.1;
      }
    }
  });

  // Give the native gamepads listener/polling thread a moment to initialize
  await Future.delayed(const Duration(milliseconds: 1000));

  // Update the gamepad state by pressing 'A'
  padOne.setA(true);
  padOne.setLeftThumb(32767, 32767);

  // Wait for the event to be captured by the listener
  await Future.delayed(const Duration(seconds: 2));

  if (!isAPressed) {
    debugPrint(
      "[ERROR] a is not pressed even though vigem pad update is called!",
    );
  } else {
    debugPrint("[SUCCESS] A button press was successfully detected!");
  }

  await Future.delayed(const Duration(seconds: 5));

  await subscription.cancel();
  padOne.dispose();
  vigem.dispose();

  exit(isAPressed ? 0 : 1);
}
