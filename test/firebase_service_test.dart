import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/services/firebase_service.dart';

void main() {
  group('FirebaseService RTDB profile mapping', () {
    test('builds a user payload with the public RTDB field names', () {
      final payload = FirebaseService.buildRealtimeUserProfilePayload(
        uid: 'abc123',
        email: 'user@example.com',
        username: 'gravity',
        displayName: 'Gravity',
        photoUrl: 'https://cdn.example.com/avatar.png',
        tokenBalance: 2500,
        dailyBonusClaimed: true,
      );

      expect(payload['uid'], 'abc123');
      expect(payload['email'], 'user@example.com');
      expect(payload['username'], 'gravity');
      expect(payload['name'], 'Gravity');
      expect(payload['online'], isFalse);
      expect(payload['profilePicUrl'], 'https://cdn.example.com/avatar.png');
      expect(payload['tokens'], 2500);
      expect(payload['daily_bonus_claimed'], isTrue);
      expect(payload['created_at'], isA<String>());
      expect(payload['updated_at'], isA<String>());
    });
  });
}
