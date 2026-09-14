class StreakCheckInResult {
  const StreakCheckInResult({
    required this.currentStreak,
    required this.bestStreak,
    required this.rewardAmount,
    required this.milestoneUnlocked,
    required this.checkedInToday,
    required this.milestonesReached,
    required this.message,
  });

  final int currentStreak;
  final int bestStreak;
  final int rewardAmount;
  final bool milestoneUnlocked;
  final bool checkedInToday;
  final List<String> milestonesReached;
  final String message;
}

class StreakService {
  static const int baseReward = 100;
  static const int milestoneReward = 500;
  static const List<int> milestoneDays = [3, 7, 14, 30];

  static String todayKey(DateTime now) {
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static StreakCheckInResult evaluateCheckIn({
    required int currentStreak,
    required int bestStreak,
    required String? lastCheckInDate,
    required List<String> milestonesReached,
    required DateTime now,
  }) {
    final today = todayKey(now);
    final lastDate = lastCheckInDate;

    if (lastDate == today) {
      return StreakCheckInResult(
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        rewardAmount: 0,
        milestoneUnlocked: false,
        checkedInToday: true,
        milestonesReached: milestonesReached,
        message: 'You already checked in today.',
      );
    }

    final lastCheckIn = lastDate == null ? null : DateTime.tryParse(lastDate);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final isConsecutive = lastCheckIn != null &&
        lastCheckIn.year == yesterday.year &&
        lastCheckIn.month == yesterday.month &&
        lastCheckIn.day == yesterday.day;

    var nextStreak = 1;
    if (isConsecutive) {
      nextStreak = currentStreak + 1;
    }

    var nextBestStreak = bestStreak;
    if (nextStreak > bestStreak) {
      nextBestStreak = nextStreak;
    }

    var unlocked = false;
    final updatedMilestones = List<String>.from(milestonesReached);
    for (final milestone in milestoneDays) {
      if (nextStreak >= milestone && !updatedMilestones.contains(milestone.toString())) {
        updatedMilestones.add(milestone.toString());
        unlocked = true;
        break;
      }
    }

    final reward = unlocked ? milestoneReward : baseReward;
    return StreakCheckInResult(
      currentStreak: nextStreak,
      bestStreak: nextBestStreak,
      rewardAmount: reward,
      milestoneUnlocked: unlocked,
      checkedInToday: false,
      milestonesReached: updatedMilestones,
      message: unlocked
          ? 'Milestone reached! Your streak bonus is live.'
          : 'Daily check-in complete. Keep the streak alive!',
    );
  }
}
