import 'dart:io';

import 'package:desktop_client/utils/win32/is_run_as_admin.dart';
import 'package:desktop_client/utils/win32/run_process.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:win32/win32.dart';

void main() {
  group('Running processes', () {
    test('Assert self running as normal process', () async {
      stdout.writeln(
        'NOTE: This might fail if you run the test command from an elevated terminal!',
      );
      await Future.delayed(Duration(seconds: 2));

      expect(isRunAsAdmin(), false);
    });
    test('Running a fire and forget normal process', () async {
      stdout.writeln("An empty command line window should open shortly.");
      await Future.delayed(Duration(seconds: 2));

      try {
        expect(
          runProcess("cmd.exe", asAdmin: false, parameters: "/c timeout /t 3"),
          true,
        );
      } catch (e) {
        rethrow;
      } finally {
        await Future.delayed(Duration(seconds: 3));
      }
    });

    test('Running a fire and forget administrator process', () async {
      stdout.writeln(
        "You must accept the elevation request for this test to complete",
      );
      await Future.delayed(Duration(seconds: 2));

      try {
        expect(
          runProcess("cmd.exe", asAdmin: true, parameters: "/c timeout /t 3"),
          true,
        );
      } catch (e) {
        rethrow;
      } finally {
        await Future.delayed(Duration(seconds: 3));
      }
    });

    test(
      'Running a fire and forget administrator process (Explicit fail)',
      () async {
        stdout.writeln(
          "You must deny the elevation request for this test to complete",
        );
        await Future.delayed(Duration(seconds: 2));

        expect(
          runProcess("cmd.exe", asAdmin: true, parameters: "/c timeout /t 3"),
          false,
        );

        await Future.delayed(Duration(seconds: 1));
      },
    );

    test('Running a tracked normal process', () async {
      stdout.writeln(
        "An empty command line window should open shortly. The window last 5 seconds before being closed",
      );
      await Future.delayed(Duration(seconds: 2));

      late HANDLE handle;
      try {
        handle = runProcessHandle(
          "cmd.exe",
          asAdmin: false,
          parameters: "/k echo This window is running without elevated permission. It will close shortly...",
        );
        expect(handle.isValid, true);
        await Future.delayed(Duration(seconds: 5));
      } catch (e) {
        rethrow;
      } finally {
        TerminateProcess(handle, 0);
        CloseHandle(handle);
      }
    });

    test('Running a tracked administrator process', () async {
      stdout.writeln(
        "You must accept the elevation request for this test to complete. The window last 5 seconds before being closed",
      );
      await Future.delayed(Duration(seconds: 2));

      late HANDLE handle;
      try {
        handle = runProcessHandle(
          "cmd.exe",
          asAdmin: true,
          parameters: "/k echo This window is running with elevated permission. It will close shortly...",
        );
        expect(handle.isValid, true);
        expect(isRunAsAdmin(handle: handle), true);

        await Future.delayed(Duration(seconds: 5));
      } catch (e) {
        rethrow;
      } finally {
        TerminateProcess(handle, 0);
        CloseHandle(handle);
      }
    });
  });
}
