import 'package:flutter_test/flutter_test.dart';
import 'package:nex_app/services/streak_service.dart';

void main() {
  group('StreakService', () {
    test('increments streak from yesterday and unlocks milestone rewards', () {
      final result = StreakService.evaluateCheckIn(
        currentStreak: 2,
        bestStreak: 2,
        lastCheckInDate: '2026-07-13',
        milestonesReached: const [],
        now: DateTime(2026, 7, 14),
      );

      expect(result.currentStreak, 3);
      expect(result.bestStreak, 3);
      expect(result.rewardAmount, 500);
      expect(result.milestoneUnlocked, isTrue);
      expect(result.milestonesReached, contains('3'));
    });

    test('resets streak after a missed day', () {
      final result = StreakService.evaluateCheckIn(
        currentStreak: 5,
        bestStreak: 5,
        lastCheckInDate: '2026-07-10',
        milestonesReached: const ['3', '7'],
        now: DateTime(2026, 7, 14),
      );

      expect(result.currentStreak, 1);
      expect(result.bestStreak, 5);
      expect(result.rewardAmount, 100);
      expect(result.milestoneUnlocked, isFalse);
    });

    test('prevents double-checking the same day', () {
      final result = StreakService.evaluateCheckIn(
        currentStreak: 4,
        bestStreak: 4,
        lastCheckInDate: '2026-07-14',
        milestonesReached: const ['3'],
        now: DateTime(2026, 7, 14),
      );

      expect(result.currentStreak, 4);
      expect(result.bestStreak, 4);
      expect(result.rewardAmount, 0);
      expect(result.checkedInToday, isTrue);
    });
  });
}
