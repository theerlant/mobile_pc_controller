import 'dart:io';

import 'package:desktop_client/services/vjoy/vjoy.dart';
import 'package:desktop_client/utils/win32/run_as_admin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VjoyInterfaceFFI - Offline & Error Handling', () {
    test('throws VjoyInterfaceMissing when DLL path does not exist', () {
      expect(
        () => VjoyInterfaceFFI.fromPath(
          r'C:\non_existent_directory\vJoyInterface.dll',
        ),
        throwsA(isA<VjoyInterfaceMissing>()),
      );
    });
  });

  group('VjoyInterfaceFFI - Live Integration', () {
    late final Vjoy vjoy;
    late final VjoyInterfaceFFI ffi;
    bool isInstalled = false;

    setUpAll(() {
      try {
        vjoy = Vjoy.fromRegistry();
        ffi = vjoy.ffi;
        isInstalled = true;

        // If vJoy is disabled, attempt to enable it using the admin config utility
        if (!ffi.vJoyEnabled()) {
          final configPath = vjoy.configExePath;
          if (File(configPath).existsSync()) {
            final adminLaunched = runAsAdmin(
              configPath,
              parameters: 'enable on',
            );
            if (adminLaunched) {
              // Allow a brief moment for the driver service to update state
              sleep(const Duration(seconds: 3));
            }
          }
        }
      } on VjoyError {
        isInstalled = false;
      }
    });

    test('successfully loads DLL from registry installation path', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      expect(ffi, isNotNull);
      expect(ffi.library, isNotNull);
    });

    test('vJoyEnabled returns a boolean indicating driver state', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      final isEnabled = ffi.vJoyEnabled();
      expect(isEnabled, isA<bool>());
    });

    test('getvJoyVersion returns a valid non-zero version integer', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      final version = ffi.getvJoyVersion();
      expect(version, isA<int>());
      expect(version, isNonZero);
    });

    test('driverMatch returns driver and DLL version match details', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      final matchResult = ffi.driverMatch();
      expect(matchResult.match, isA<bool>());
      expect(matchResult.dllVer, isA<int>());
      expect(matchResult.drvVer, isA<int>());
      expect(matchResult.dllVer, isNonZero);
    });

    test('retrieves vendor, product, and serial string descriptors', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      final vendor = ffi.getvJoyManufacturerString();
      final product = ffi.getvJoyProductString();
      final serial = ffi.getvJoySerialNumberString();

      expect(vendor, anyOf(isNull, isA<String>()));
      expect(product, anyOf(isNull, isA<String>()));
      expect(serial, anyOf(isNull, isA<String>()));
    });

    test('isVJDExists and getVJDStatus return valid status for device 1', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      const deviceId = 1;
      final exists = ffi.isVJDExists(deviceId);
      expect(exists, isA<bool>());

      final status = ffi.getVJDStatus(deviceId);
      expect(status, isA<VjdStat>());
      expect(
        status,
        isIn([
          VjdStat.own,
          VjdStat.free,
          VjdStat.busy,
          VjdStat.miss,
          VjdStat.unkn,
        ]),
      );
    });

    test('getOwnerPid returns OwnerPID and raw PID integer', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      const deviceId = 1;
      final (ownerPID, rawPid) = ffi.getOwnerPid(deviceId);
      expect(ownerPID, isA<OwnerPID>());
      expect(rawPid, isA<int>());
    });

    test('getVJDButtonNumber, getVJDDiscPovNumber, getVJDContPovNumber return count', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      const deviceId = 1;
      final btnCount = ffi.getVJDButtonNumber(deviceId);
      final discPovCount = ffi.getVJDDiscPovNumber(deviceId);
      final contPovCount = ffi.getVJDContPovNumber(deviceId);

      expect(btnCount, isA<int>());
      expect(discPovCount, isA<int>());
      expect(contPovCount, isA<int>());
    });

    test('getVJDAxisExist checks axis availability without crashing', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      const deviceId = 1;
      final hasXAxis = ffi.getVJDAxisExist(deviceId, Axis.X);
      expect(hasXAxis, isA<bool>());
    });

    test('acquires, sets controls, resets, and relinquishes vJoy device 1 if available', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      const deviceId = 1;
      final status = ffi.getVJDStatus(deviceId);

      if (status == VjdStat.free) {
        final acquired = ffi.acquireVJD(deviceId);
        expect(acquired, isTrue);

        expect(ffi.getVJDStatus(deviceId), equals(VjdStat.own));

        // Test setting axis and button
        ffi.setAxis(16384, deviceId, Axis.X);
        ffi.setBtn(true, deviceId, 1);
        ffi.resetButtons(deviceId);
        ffi.resetPovs(deviceId);
        ffi.resetVJD(deviceId);

        // Clean up / relinquish device
        ffi.relinquishVJD(deviceId);
        expect(ffi.getVJDStatus(deviceId), isNot(equals(VjdStat.own)));
      }
    });

    test('high-level Vjoy discovery and device management methods work correctly', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      expect(vjoy.isEnabled, isA<bool>());
      expect(vjoy.version, isA<int>());
      expect(vjoy.productString, anyOf(isNull, isA<String>()));
      expect(vjoy.manufacturerString, anyOf(isNull, isA<String>()));
      expect(vjoy.serialNumberString, anyOf(isNull, isA<String>()));

      final existingIds = vjoy.getExistingDeviceIds();
      expect(existingIds, isA<List<int>>());

      final existingDevices = vjoy.getExistingDevices();
      expect(existingDevices.length, equals(existingIds.length));

      final device1 = vjoy.getDevice(1);
      expect(device1.deviceId, equals(1));
      expect(device1.exists, isA<bool>());
      expect(device1.status, isA<VjdStat>());
      expect(device1.availableAxes, isA<List<Axis>>());
    });

    test('high-level VjoyDevice control feeding and resets execute safely', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      final device1 = vjoy.getDevice(1);
      if (device1.isFree) {
        expect(device1.acquire(), isTrue);
        expect(device1.isOwned, isTrue);

        // Axis normalized writes
        device1.setXNormalized(0.0); // center
        device1.setXNormalized(-1.0); // full left
        device1.setXNormalized(1.0); // full right
        device1.setYNormalized(0.5);
        device1.setZNormalized(1.0);
        device1.setRxNormalized(0.0);
        device1.setRyNormalized(0.0);
        device1.setRzNormalized(0.0);
        device1.setSlider0Normalized(0.25);
        device1.setSlider1Normalized(0.75);
        device1.setWheelNormalized(0.0);

        // Button operations
        device1.pressButton(1);
        device1.releaseButton(1);
        device1.setButton(2, true);

        // POV operations
        device1.setContinuousPovAngle(1, 90.0);
        device1.setContinuousPovAngle(1, null); // center
        device1.setDiscretePov(1, DiscPov.North);
        device1.setDiscretePov(1, DiscPov.Neutral);

        // Resets
        device1.resetButtons();
        device1.resetPovs();
        device1.reset();
        vjoy.resetAll();

        // Relinquish
        device1.relinquish();
        expect(device1.isOwned, isFalse);
      }
    });

    test('invalid device IDs throw VjoyDeviceInvalid when getting device', () {
      if (!isInstalled) {
        markTestSkipped('vJoy is not installed on this machine.');
        return;
      }

      expect(() => vjoy.getDevice(0), throwsA(isA<VjoyDeviceInvalid>()));
      expect(() => vjoy.getDevice(17), throwsA(isA<VjoyDeviceInvalid>()));
      expect(() => vjoy.getDevice(-1), throwsA(isA<VjoyDeviceInvalid>()));
    });
  });

  group('VjoyDevice Unit & Value Math Tests', () {
    test('VjoyDevice bounds normalization calculations', () {
      // Bipolar (-1.0 .. +1.0)
      expect(VjoyDevice.normalizeBipolar(-1.0), equals(1));
      expect(VjoyDevice.normalizeBipolar(0.0), equals(16384));
      expect(VjoyDevice.normalizeBipolar(1.0), equals(32768));
      expect(VjoyDevice.normalizeBipolar(-2.0), equals(1)); // clamped
      expect(VjoyDevice.normalizeBipolar(2.0), equals(32768)); // clamped

      // Unipolar (0.0 .. 1.0)
      expect(VjoyDevice.normalizeUnipolar(0.0), equals(1));
      expect(VjoyDevice.normalizeUnipolar(1.0), equals(32768));
      expect(VjoyDevice.normalizeUnipolar(-0.5), equals(1)); // clamped
      expect(VjoyDevice.normalizeUnipolar(1.5), equals(32768)); // clamped
    });
  });
}
