import 'dart:convert';

const String magicString = "REMOTE_APP_BROADCAST";
final List<int> magicStringBytes = utf8.encode(magicString);
final int magicStringLength = magicStringBytes.length;
const int protocolVersion = 100; // v1.0.0

/// Validates that [sessionId] is an 8-digit positive number (10000000 to 99999999).
void verifySessionId(int sessionId) {
  if (sessionId < 10000000 || sessionId > 99999999) {
    throw ArgumentError.value(
      sessionId,
      "sessionId",
      "SessionID must be exactly an 8-digit positive number (10000000 to 99999999).",
    );
  }
}
