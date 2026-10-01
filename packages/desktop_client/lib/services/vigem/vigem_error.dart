import 'package:desktop_client/services/vigem/vigem_types_common.dart';

/// Base class for all ViGEm-related exceptions.
abstract class ViGEmException implements Exception {
  final String message;
  const ViGEmException(this.message);

  @override
  String toString() => message;
}

/// Thrown when allocation of the native ViGEm client handle fails.
final class ViGEmClientAllocException extends ViGEmException {
  const ViGEmClientAllocException([
    super.message = 'Failed to allocate ViGEmClient handle',
  ]);
}

/// Thrown when attempting to create a gamepad when the maximum limit has been reached.
final class ViGEmPadFullException extends ViGEmException {
  const ViGEmPadFullException([
    super.message = 'Failed to create a new gamepad, limit exhausted',
  ]);
}

/// Thrown when a native ViGEm function call returns an error status code.
final class ViGEmNativeException extends ViGEmException {
  final VigemErrors errorCode;

  ViGEmNativeException(this.errorCode, [String? detail])
      : super(
          detail != null
              ? 'ViGEm native call failed: $errorCode (${errorCode.value}) - $detail'
              : 'ViGEm method failed with code error: $errorCode (${errorCode.value})',
        );
}

/// Thrown when attempting to perform an operation on a disposed ViGEm or ViGEmPad instance.
final class ViGEmDisposedException extends ViGEmException {
  const ViGEmDisposedException([
    super.message = 'Cannot perform operation on disposed ViGEm object',
  ]);
}

/// Thrown when an operation requires an active connection to the ViGEm driver bus.
final class ViGEmNotConnectedException extends ViGEmException {
  const ViGEmNotConnectedException([
    super.message = 'ViGEm client is not connected to driver bus',
  ]);
}
