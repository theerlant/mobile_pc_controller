import 'dart:math';

/// Generate an 8 digit ID from [10000000] to [99999999]
int generateSessionId() {
  return 10000000 + Random().nextInt(90000000);
}
