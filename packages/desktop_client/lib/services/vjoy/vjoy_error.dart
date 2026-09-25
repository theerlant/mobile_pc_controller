sealed class VjoyError implements Exception {
  final String message;
  const VjoyError(this.message);

  @override
  String toString() => "vJoyError: $message";
}

final class VjoyNotInstalled extends VjoyError {
  const VjoyNotInstalled()
    : super('vJoy is not installed as its registry key is not found');
}

final class VjoyArchUnsupported extends VjoyError {
  const VjoyArchUnsupported()
    : super('Only 64 bit version of vJoy is supported');
}

final class VjoyInterfaceMissing extends VjoyError {
  const VjoyInterfaceMissing(String dllPath)
    : super('vJoyInterface.dll is not found in "$dllPath"');
}

final class VjoyDeviceInvalid extends VjoyError {
  final int deviceId;
  const VjoyDeviceInvalid(this.deviceId)
    : super('vJoy device index $deviceId is out of valid range (1-16)');
}

final class VjoyDeviceAcquisitionFailed extends VjoyError {
  final int deviceId;
  const VjoyDeviceAcquisitionFailed(this.deviceId)
    : super('Failed to acquire vJoy device $deviceId (status busy, missing, or already owned elsewhere)');
}

final class VjoyConfigException extends VjoyError {
  final int? exitCode;
  final String details;
  const VjoyConfigException(this.details, [this.exitCode])
    : super('vJoy configuration command failed: $details${exitCode != null ? ' (exit code: $exitCode)' : ''}');
}

