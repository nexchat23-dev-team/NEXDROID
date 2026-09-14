import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nex_app/services/user_leveling_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserLevelingService Milestone Avatars', () {
    test('Milestone definitions exist for 100, 1000, 10000, 100000', () {
      const milestones = UserLevelingService.milestoneAvatars;
      expect(milestones.length, 4);

      final levels = milestones.map((m) => m['level'] as int).toList();
      expect(levels, containsAll([100, 1000, 10000, 100000]));

      for (final m in milestones) {
        expect(m['title'], isNotEmpty);
        expect(m['asset'], contains('assets/images/level_'));
        expect(m['powerRating'], isNotEmpty);
      }
    });

    test('Reaching level 100 auto-equips milestone avatar and notifies stream', () async {
      final leveling = UserLevelingService.instance;
      await leveling.initialize();

      Map<String, dynamic>? emittedMilestone;
      final sub = leveling.onMilestoneAvatarUnlockStream.listen((data) {
        emittedMilestone = data;
      });

      // Initially at level 1, no milestone avatar active
      expect(leveling.isMilestoneAvatarActive, false);
      expect(leveling.activeMilestoneAvatarAsset, null);

      // Add enough XP to pass level 100
      final xpNeeded = leveling.xpForLevel(100) - leveling.totalXP + 500;
      leveling.addXP(xpNeeded > 0 ? xpNeeded : 500);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(leveling.currentLevel >= 100, true);
      expect(leveling.isMilestoneAvatarActive, true);
      expect(leveling.activeMilestoneAvatarAsset, 'assets/images/level_100_avatar.jpg');
      expect(emittedMilestone?['level'], 100);

      // User chooses to revert if they do not like it
      leveling.revertToCustomAvatar();
      expect(leveling.isMilestoneAvatarActive, false);
      expect(leveling.activeMilestoneAvatarAsset, null);
      expect(leveling.useCustomUploadedAvatar, true);

      // User decides to re-equip any unlocked milestone skin
      leveling.equipMilestoneAvatar('assets/images/level_100_avatar.jpg');
      expect(leveling.isMilestoneAvatarActive, true);
      expect(leveling.activeMilestoneAvatarAsset, 'assets/images/level_100_avatar.jpg');

      await sub.cancel();
    });

    test('setAutoEquipMilestones toggles auto-equip setting', () async {
      final leveling = UserLevelingService.instance;
      await leveling.initialize();

      leveling.setAutoEquipMilestones(false);
      expect(leveling.autoEquipMilestones, false);

      leveling.setAutoEquipMilestones(true);
      expect(leveling.autoEquipMilestones, true);
    });
  });
}
