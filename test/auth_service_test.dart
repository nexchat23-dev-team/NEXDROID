import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/services/auth_service.dart';

void main() {
  group('AuthService display name resolution', () {
    test('prefers name, then username, then email local part', () {
      expect(
        AuthService.resolveDisplayName(name: 'Sam', username: 'sammy', email: 'sam@example.com'),
        'Sam',
      );
      expect(
        AuthService.resolveDisplayName(username: 'sammy', email: 'sam@example.com'),
        'sammy',
      );
      expect(
        AuthService.resolveDisplayName(email: 'sam@example.com'),
        'sam',
      );
      expect(
        AuthService.resolveDisplayName(),
        'NEX User',
      );
    });
  });
}
