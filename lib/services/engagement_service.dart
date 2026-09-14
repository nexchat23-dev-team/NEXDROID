class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.reward,
    this.completed = false,
  });

  final String id;
  final String title;
  final String description;
  final int reward;
  final bool completed;
}

class EngagementService {
  static List<DailyChallenge> buildDefaultChallenges() {
    return const [
      DailyChallenge(
        id: 'send_message',
        title: 'Send a message',
        description: 'Start a meaningful conversation today.',
        reward: 250,
      ),
      DailyChallenge(
        id: 'open_market',
        title: 'Explore the marketplace',
        description: 'Browse something new or post an offer.',
        reward: 300,
      ),
      DailyChallenge(
        id: 'check_in',
        title: 'Complete your check-in',
        description: 'Keep your streak alive and earn momentum.',
        reward: 400,
      ),
    ];
  }

  static List<DailyChallenge> withCompletionState(List<DailyChallenge> challenges, List<String> completedIds) {
    return challenges.map((challenge) {
      final completed = completedIds.contains(challenge.id);
      return DailyChallenge(
        id: challenge.id,
        title: challenge.title,
        description: challenge.description,
        reward: challenge.reward,
        completed: completed,
      );
    }).toList();
  }

  static int completedReward(List<DailyChallenge> challenges) {
    return challenges.where((challenge) => challenge.completed).fold<int>(0, (sum, challenge) => sum + challenge.reward);
  }
}
