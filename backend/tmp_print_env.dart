import 'dart:io';

void main() {
  print('SKIP_FIREBASE=' + (Platform.environment['SKIP_FIREBASE'] ?? 'null'));
  print('SKIP_DB=' + (Platform.environment['SKIP_DB'] ?? 'null'));
}
