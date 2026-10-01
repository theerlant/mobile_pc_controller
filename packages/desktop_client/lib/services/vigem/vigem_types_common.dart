// ignore_for_file: non_constant_identifier_names, camel_case_types, constant_identifier_names

import 'dart:ffi';

import 'package:desktop_client/services/vigem/vigem_error.dart';

typedef VIGEM_ERROR = Int32;

/// Native ViGEm error codes defined by the ViGEmBus / ViGEmClient driver.
enum VigemErrors {
  VIGEM_ERROR_NONE(0x20000000),
  VIGEM_ERROR_BUS_NOT_FOUND(0xE0000001),
  VIGEM_ERROR_NO_FREE_SLOT(0xE0000002),
  VIGEM_ERROR_INVALID_TARGET(0xE0000003),
  VIGEM_ERROR_REMOVAL_FAILED(0xE0000004),
  VIGEM_ERROR_ALREADY_CONNECTED(0xE0000005),
  VIGEM_ERROR_TARGET_UNINITIALIZED(0xE0000006),
  VIGEM_ERROR_TARGET_NOT_PLUGGED_IN(0xE0000007),
  VIGEM_ERROR_BUS_VERSION_MISMATCH(0xE0000008),
  VIGEM_ERROR_BUS_ACCESS_FAILED(0xE0000009),
  VIGEM_ERROR_CALLBACK_ALREADY_REGISTERED(0xE0000010),
  VIGEM_ERROR_CALLBACK_NOT_FOUND(0xE0000011),
  VIGEM_ERROR_BUS_ALREADY_CONNECTED(0xE0000012),
  VIGEM_ERROR_BUS_INVALID_HANDLE(0xE0000013),
  VIGEM_ERROR_XUSB_USERINDEX_OUT_OF_RANGE(0xE0000014),
  VIGEM_ERROR_INVALID_PARAMETER(0xE0000015),
  VIGEM_ERROR_NOT_SUPPORTED(0xE0000016),
  VIGEM_ERROR_WINAPI(0xE0000017),
  VIGEM_ERROR_TIMED_OUT(0xE0000018),
  VIGEM_ERROR_IS_DISPOSING(0xE0000019),
  FROM_INT_UNDEFINED(0xFFFFFFFF);

  final int value;

  const VigemErrors(this.value);

  /// Convert raw int (supporting both signed and unsigned 32-bit values) to [VigemErrors].
  static VigemErrors fromInt(int value) {
    final unsignedVal = value & 0xFFFFFFFF;
    return VigemErrors.values.firstWhere(
      (err) => (err.value & 0xFFFFFFFF) == unsignedVal,
      orElse: () => VigemErrors.FROM_INT_UNDEFINED,
    );
  }

  /// Whether this error code represents a successful operation.
  bool get isSuccess => this == VigemErrors.VIGEM_ERROR_NONE;
}

typedef PVIGEM_CLIENT = Pointer<Void>;
typedef PVIGEM_TARGET = Pointer<Void>;

/// Asserts that a ViGEm native return code is [VigemErrors.VIGEM_ERROR_NONE],
/// or throws a [ViGEmNativeException].
void VIGEM_SUCCESS_OR_THROW(int value) {
  final errVal = VigemErrors.fromInt(value);
  if (errVal.isSuccess) return;

  throw ViGEmNativeException(errVal);
}
