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
