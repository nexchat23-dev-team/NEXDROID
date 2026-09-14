import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/streak_service.dart';

class TokenProvider extends ChangeNotifier {
  int _balance = 0;
  bool _initialized = false;
  bool dailyBonusClaimed = false;
  int _streakCount = 0;
  int _bestStreak = 0;
  String? _lastCheckInDate;
  List<String> _milestonesReached = const [];
  List<String> _completedChallenges = const [];
  String _quickNotes = '';

  TokenProvider() {
    _loadState();
  }

  int get balance => _balance;
  bool get hasTokens => _balance > 0;
  bool get isInitialized => _initialized;
  int get streakCount => _streakCount;
  int get bestStreak => _bestStreak;
  String? get lastCheckInDate => _lastCheckInDate;
  List<String> get milestonesReached => List.unmodifiable(_milestonesReached);
  List<String> get completedChallenges => List.unmodifiable(_completedChallenges);
  String get quickNotes => _quickNotes;
  bool get hasCheckedInToday => _lastCheckInDate == StreakService.todayKey(DateTime.now());

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getInt('token_balance') ?? 0;
    dailyBonusClaimed = prefs.getBool('daily_bonus_claimed') ?? false;
    _streakCount = prefs.getInt('streak_count') ?? 0;
    _bestStreak = prefs.getInt('best_streak') ?? 0;
    _lastCheckInDate = prefs.getString('last_check_in_date');
    _milestonesReached = prefs.getStringList('streak_milestones_reached') ?? const [];
    _completedChallenges = prefs.getStringList('daily_challenges_completed') ?? const [];
    _quickNotes = prefs.getString('quick_notes') ?? '';
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('token_balance', _balance);
    await prefs.setBool('daily_bonus_claimed', dailyBonusClaimed);
    await prefs.setInt('streak_count', _streakCount);
    await prefs.setInt('best_streak', _bestStreak);
    if (_lastCheckInDate != null) {
      await prefs.setString('last_check_in_date', _lastCheckInDate!);
    } else {
      await prefs.remove('last_check_in_date');
    }
    await prefs.setStringList('streak_milestones_reached', _milestonesReached);
    await prefs.setStringList('daily_challenges_completed', _completedChallenges);
    await prefs.setString('quick_notes', _quickNotes);
  }

  void _persist() {
    _saveState();
  }

  Future<void> _persistToFirebase() async {
    try {
      await FirebaseService.initialize();
      final user = FirebaseService.auth.currentUser;
      if (user == null) return;
      await FirebaseService.updateUserProfile(uid: user.uid, data: {
        'token_balance': _balance,
        'daily_bonus_claimed': dailyBonusClaimed,
        'streak_count': _streakCount,
        'best_streak': _bestStreak,
        'last_check_in_date': _lastCheckInDate,
        'streak_milestones_reached': _milestonesReached,
        'daily_challenges_completed': _completedChallenges,
        'quick_notes': _quickNotes,
      });
      await FirebaseService.saveStreakData(
        uid: user.uid,
        streakCount: _streakCount,
        bestStreak: _bestStreak,
        lastCheckInDate: _lastCheckInDate,
        milestonesReached: _milestonesReached,
        completedChallenges: _completedChallenges,
        quickNotes: _quickNotes,
      );
    } catch (e) {
      debugPrint('Error syncing token state to Firebase: $e');
    }
  }

  void setBalance(int value) {
    _balance = value;
    _persist();
    unawaited(_persistToFirebase());
    notifyListeners();
  }

  Future<void> setDailyBonusClaimed(bool value) async {
    dailyBonusClaimed = value;
    await _saveState();
    await _persistToFirebase();
    notifyListeners();
  }

  void addTokens(int amount) {
    if (amount <= 0) return;
    _balance += amount;
    _persist();
    unawaited(_persistToFirebase());
    notifyListeners();
  }

  void deductTokens(int amount) {
    if (amount <= 0) return;
    _balance = (_balance - amount).clamp(0, double.infinity.toInt());
    _persist();
    unawaited(_persistToFirebase());
    notifyListeners();
  }

  bool transferTokens(int amount) {
    if (amount <= 0 || amount > _balance) {
      return false;
    }
    _balance -= amount;
    _persist();
    unawaited(_persistToFirebase());
    notifyListeners();
    return true;
  }

  Future<void> syncStreakState(Map<String, dynamic>? profile) async {
    if (profile == null) return;
    _streakCount = profile['streak_count'] is int ? profile['streak_count'] as int : 0;
    _bestStreak = profile['best_streak'] is int ? profile['best_streak'] as int : 0;
    _lastCheckInDate = profile['last_check_in_date']?.toString();
    final milestones = profile['streak_milestones_reached'];
    if (milestones is List) {
      _milestonesReached = milestones.whereType<String>().toList();
    } else {
      _milestonesReached = const [];
    }
    final completedChallenges = profile['daily_challenges_completed'];
    if (completedChallenges is List) {
      _completedChallenges = completedChallenges.whereType<String>().toList();
    } else {
      _completedChallenges = const [];
    }
    _quickNotes = profile['quick_notes']?.toString() ?? '';
    await _saveState();
    notifyListeners();
  }

  Future<void> updateQuickNotes(String notes) async {
    _quickNotes = notes;
    await _saveState();
    unawaited(_persistToFirebase());
    notifyListeners();
  }

  Future<void> completeChallenge(String challengeId) async {
    if (_completedChallenges.contains(challengeId)) return;
    _completedChallenges = [..._completedChallenges, challengeId];
    _balance += 250;
    await _saveState();
    unawaited(_persistToFirebase());
    notifyListeners();
  }

  Future<StreakCheckInResult> checkInToday({DateTime? now}) async {
    final currentTime = now ?? DateTime.now();
    final result = StreakService.evaluateCheckIn(
      currentStreak: _streakCount,
      bestStreak: _bestStreak,
      lastCheckInDate: _lastCheckInDate,
      milestonesReached: _milestonesReached,
      now: currentTime,
    );

    if (result.checkedInToday) {
      return result;
    }

    _streakCount = result.currentStreak;
    _bestStreak = result.bestStreak;
    _lastCheckInDate = StreakService.todayKey(currentTime);
    _milestonesReached = result.milestonesReached;
    _balance += result.rewardAmount;
    await _saveState();
    unawaited(_persistToFirebase());
    notifyListeners();
    return result;
  }

  void claimDailyBonus(int amount) {
    if (!dailyBonusClaimed && amount > 0) {
      _balance += amount;
      dailyBonusClaimed = true;
      _persist();
      unawaited(_persistToFirebase());
      notifyListeners();
    }
  }
}
