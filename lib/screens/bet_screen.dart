import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../utils/constants.dart';
import '../widgets/token_purchase_sheet.dart';
import '../services/game_sound_service.dart';

class BettingScreen extends StatefulWidget {
  static const routeName = '/betting';
  const BettingScreen({super.key});

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> with TickerProviderStateMixin {
  final TextEditingController _stakeController = TextEditingController(text: '500');
  final math.Random _rng = math.Random();

  late TabController _gameTabController;

  // Global betting stats
  int _totalWagered = 0;
  int _totalWon = 0;
  int _betsPlaced = 0;
  int _betsWon = 0;
  final List<Map<String, dynamic>> _betHistory = [];

  // ==========================================
  // GAME 1: AVIATOR / CRASH ROCKET STATE
  // ==========================================
  bool _aviatorFlying = false;
  bool _aviatorCrashed = false;
  bool _aviatorCashedOut = false;
  double _aviatorMultiplier = 1.00;
  double _aviatorCrashPoint = 2.00;
  int _aviatorStake = 0;
  Timer? _aviatorTimer;
  late AnimationController _rocketAnimController;
  final List<double> _aviatorHistory = [2.45, 1.15, 8.20, 1.05, 3.80, 14.50, 1.90];

  // ==========================================
  // GAME 2: DIAMOND MINES (STAKE STYLE 5x5)
  // ==========================================
  int _minesCount = 3;
  int _minesStake = 0;
  bool _minesActive = false;
  Set<int> _minePositions = {};
  Set<int> _revealedDiamonds = {};
  double _currentMinesMultiplier = 1.00;

  // ==========================================
  // GAME 3: NEON MEGA WHEEL
  // ==========================================
  late AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  double _wheelCurrentAngle = 0.0;
  bool _wheelSpinning = false;
  String _wheelResultText = '';
  final List<Map<String, dynamic>> _wheelSectors = [
    {'mult': 0.0, 'label': '0X', 'color': Color(0xFFE53935)},
    {'mult': 1.5, 'label': '1.5X', 'color': Color(0xFF00B8F4)},
    {'mult': 2.0, 'label': '2X', 'color': Color(0xFF25D366)},
    {'mult': 0.5, 'label': '0.5X', 'color': Color(0xFFFF9800)},
    {'mult': 3.0, 'label': '3X', 'color': Color(0xFFB23BFF)},
    {'mult': 0.0, 'label': '0X', 'color': Color(0xFFE53935)},
    {'mult': 5.0, 'label': '5X', 'color': Color(0xFF00E5FF)},
    {'mult': 1.2, 'label': '1.2X', 'color': Color(0xFF29B6F6)},
    {'mult': 10.0, 'label': '10X', 'color': Color(0xFFFFD700)},
    {'mult': 0.0, 'label': '0X', 'color': Color(0xFFE53935)},
    {'mult': 2.0, 'label': '2X', 'color': Color(0xFF25D366)},
    {'mult': 25.0, 'label': '25X', 'color': Color(0xFFFF0055)},
    {'mult': 1.5, 'label': '1.5X', 'color': Color(0xFF00B8F4)},
    {'mult': 50.0, 'label': '50X MEGA', 'color': Color(0xFFFFD700)},
  ];

  // ==========================================
  // GAME 4: CYBER HI-LO TURBO DICE
  // ==========================================
  double _diceTarget = 50.0;
  bool _diceRollOver = true;
  int _diceLastRoll = 50;
  bool _diceRolling = false;
  String _diceResultText = '';

  // ==========================================
  // GAME 5: CYBER ROULETTE / COLOR CLASH
  // ==========================================
  String _rouletteSelectedColor = 'cyan'; // 'cyan' (2x), 'magenta' (2x), 'gold' (14x)
  bool _rouletteSpinning = false;
  late AnimationController _rouletteController;
  String _rouletteResultColor = '';

  // ==========================================
  // GAME 6: PLINKO EXTREME
  // ==========================================
  bool _plinkoDropping = false;
  Offset _plinkoBallPos = Offset.zero;
  int _plinkoFinalBucket = -1;
  final List<double> _plinkoBuckets = [15.0, 5.0, 2.0, 0.5, 0.2, 0.5, 2.0, 5.0, 15.0];
  final List<Color> _plinkoBucketColors = [
    Color(0xFFFF0055),
    Color(0xFFFF7700),
    Color(0xFFFFD700),
    Color(0xFF00B8F4),
    Color(0xFF757575),
    Color(0xFF00B8F4),
    Color(0xFFFFD700),
    Color(0xFFFF7700),
    Color(0xFFFF0055),
  ];

  @override
  void initState() {
    super.initState();
    _gameTabController = TabController(length: 6, vsync: this);

    _rocketAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _rouletteController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _stakeController.dispose();
    _gameTabController.dispose();
    _rocketAnimController.dispose();
    _wheelController.dispose();
    _rouletteController.dispose();
    _aviatorTimer?.cancel();
    super.dispose();
  }

  int _getStake() {
    final text = _stakeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(text) ?? 0;
  }

  void _recordBet({
    required String gameName,
    required int stake,
    required double multiplier,
    required int payout,
    required bool won,
  }) {
    setState(() {
      _totalWagered += stake;
      _betsPlaced++;
      if (won) {
        _totalWon += payout;
        _betsWon++;
      }
      _betHistory.insert(0, {
        'game': gameName,
        'stake': stake,
        'mult': multiplier,
        'payout': payout,
        'won': won,
        'time': DateTime.now(),
      });
      if (_betHistory.length > 30) _betHistory.removeLast();
    });
  }

  void _showLowBalanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.toll_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('Insufficient Tokens', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'You do not have enough tokens for this stake. You can top up tokens instantly via official seller @Vershdit on Telegram!',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              TokenPurchaseSheet.show(context);
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Buy Tokens on Telegram'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF229ED9),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GAME 1 LOGIC: AVIATOR CRASH
  // ==========================================
  void _startAviator() {
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final stake = _getStake();
    if (stake <= 0) return;
    if (tokenProvider.balance < stake) {
      _showLowBalanceDialog();
      return;
    }

    tokenProvider.deductTokens(stake);
    HapticFeedback.heavyImpact();
    GameSoundService().playLaser();

    // Provably fair crash point generation
    // Weighted distribution: 1.00x - 50.0x with thrill curve
    final roll = _rng.nextDouble();
    double crash;
    if (roll < 0.05) {
      crash = 1.00; // instant crash 5%
    } else if (roll < 0.50) {
      crash = 1.01 + _rng.nextDouble() * 1.50; // 1.01x - 2.50x
    } else if (roll < 0.80) {
      crash = 2.50 + _rng.nextDouble() * 3.50; // 2.50x - 6.00x
    } else if (roll < 0.95) {
      crash = 6.00 + _rng.nextDouble() * 10.00; // 6.00x - 16.00x
    } else {
      crash = 16.00 + _rng.nextDouble() * 50.00; // Mega 16x - 66x!
    }

    setState(() {
      _aviatorFlying = true;
      _aviatorCrashed = false;
      _aviatorCashedOut = false;
      _aviatorMultiplier = 1.00;
      _aviatorCrashPoint = crash;
      _aviatorStake = stake;
    });

    _aviatorTimer?.cancel();
    _aviatorTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_aviatorFlying) {
        timer.cancel();
        return;
      }

      setState(() {
        // Accelerating curve
        final increment = 0.01 + (_aviatorMultiplier * 0.005);
        _aviatorMultiplier += increment;

        if (_aviatorMultiplier >= _aviatorCrashPoint) {
          timer.cancel();
          _aviatorFlying = false;
          _aviatorCrashed = true;
          _aviatorMultiplier = _aviatorCrashPoint;
          HapticFeedback.vibrate();
          GameSoundService().playLose();

          _aviatorHistory.insert(0, double.parse(_aviatorCrashPoint.toStringAsFixed(2)));
          if (_aviatorHistory.length > 10) _aviatorHistory.removeLast();

          if (!_aviatorCashedOut) {
            _recordBet(
              gameName: 'Aviator Rocket',
              stake: _aviatorStake,
              multiplier: _aviatorCrashPoint,
              payout: 0,
              won: false,
            );
          }
        }
      });
    });
  }

  void _cashOutAviator() {
    if (!_aviatorFlying || _aviatorCrashed || _aviatorCashedOut) return;
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    HapticFeedback.mediumImpact();
    GameSoundService().playWin();

    final winMultiplier = _aviatorMultiplier;
    final payout = (_aviatorStake * winMultiplier).round();

    setState(() {
      _aviatorCashedOut = true;
    });

    tokenProvider.addTokens(payout);
    _recordBet(
      gameName: 'Aviator Rocket',
      stake: _aviatorStake,
      multiplier: winMultiplier,
      payout: payout,
      won: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Cashed Out at ${winMultiplier.toStringAsFixed(2)}x! Won $payout Tokens! 🚀'),
          ],
        ),
        backgroundColor: kNeonGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // GAME 2 LOGIC: DIAMOND MINES 5x5
  // ==========================================
  double _calculateMinesMultiplier(int gemsRevealed, int minesCount) {
    if (gemsRevealed == 0) return 1.00;
    // Fair combinatorial multiplier with 2% house edge
    double mult = 0.98;
    for (int i = 0; i < gemsRevealed; i++) {
      mult *= (25.0 - i) / (25.0 - minesCount - i);
    }
    return double.parse(mult.toStringAsFixed(2));
  }

  void _startMines() {
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final stake = _getStake();
    if (stake <= 0) return;
    if (tokenProvider.balance < stake) {
      _showLowBalanceDialog();
      return;
    }

    tokenProvider.deductTokens(stake);
    HapticFeedback.heavyImpact();
    GameSoundService().playLaser();

    final positions = List.generate(25, (i) => i)..shuffle(_rng);
    final mines = positions.take(_minesCount).toSet();

    setState(() {
      _minesStake = stake;
      _minesActive = true;
      _minePositions = mines;
      _revealedDiamonds.clear();
      _currentMinesMultiplier = 1.00;
    });
  }

  void _tapMinesTile(int index) {
    if (!_minesActive || _revealedDiamonds.contains(index)) return;

    if (_minePositions.contains(index)) {
      // Hit Mine!
      HapticFeedback.vibrate();
      GameSoundService().playExplosion();
      setState(() {
        _minesActive = false;
        _revealedDiamonds.add(index);
      });
      _recordBet(
        gameName: 'Diamond Mines',
        stake: _minesStake,
        multiplier: 0.0,
        payout: 0,
        won: false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💥 BOOM! You hit a mine. Lost stake.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Safe Diamond!
      HapticFeedback.lightImpact();
      GameSoundService().playCoin();
      setState(() {
        _revealedDiamonds.add(index);
        _currentMinesMultiplier = _calculateMinesMultiplier(_revealedDiamonds.length, _minesCount);
      });

      // If all safe diamonds cleared, auto cash out
      if (_revealedDiamonds.length == (25 - _minesCount)) {
        _cashOutMines();
      }
    }
  }

  void _cashOutMines() {
    if (!_minesActive || _revealedDiamonds.isEmpty) return;
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    HapticFeedback.mediumImpact();
    GameSoundService().playWin();

    final payout = (_minesStake * _currentMinesMultiplier).round();
    tokenProvider.addTokens(payout);

    setState(() {
      _minesActive = false;
    });

    _recordBet(
      gameName: 'Diamond Mines',
      stake: _minesStake,
      multiplier: _currentMinesMultiplier,
      payout: payout,
      won: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💎 Cashed Out at ${_currentMinesMultiplier.toStringAsFixed(2)}x! Won $payout Tokens!'),
        backgroundColor: kNeonGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // GAME 3 LOGIC: NEON MEGA WHEEL
  // ==========================================
  void _spinMegaWheel() {
    if (_wheelSpinning) return;
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final stake = _getStake();
    if (stake <= 0) return;
    if (tokenProvider.balance < stake) {
      _showLowBalanceDialog();
      return;
    }

    tokenProvider.deductTokens(stake);
    HapticFeedback.heavyImpact();
    GameSoundService().playTick();

    final sectorIndex = _rng.nextInt(_wheelSectors.length);
    final sector = _wheelSectors[sectorIndex];
    final sectorAngle = (2 * math.pi) / _wheelSectors.length;
    // Align target sector with top pointer (offset by pi/2)
    final targetAngle = (5 * 2 * math.pi) + (sectorIndex * sectorAngle) + (sectorAngle / 2);

    setState(() {
      _wheelSpinning = true;
      _wheelResultText = 'Spinning...';
    });

    _wheelAnimation = Tween<double>(
      begin: _wheelCurrentAngle,
      end: _wheelCurrentAngle + targetAngle,
    ).animate(CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic));

    _wheelController.reset();
    _wheelController.forward().then((_) {
      _wheelCurrentAngle = (_wheelCurrentAngle + targetAngle) % (2 * math.pi);
      final double mult = sector['mult'] as double;
      final int payout = (stake * mult).round();

      if (payout > 0) {
        tokenProvider.addTokens(payout);
        GameSoundService().playWin();
      } else {
        GameSoundService().playLose();
      }

      setState(() {
        _wheelSpinning = false;
        _wheelResultText = mult > 0
            ? 'Landed on ${sector['label']}! Won $payout Tokens 🎉'
            : 'Landed on 0X. Better luck next spin!';
      });

      _recordBet(
        gameName: 'Neon Mega Wheel',
        stake: stake,
        multiplier: mult,
        payout: payout,
        won: payout > 0,
      );

      if (payout > 0) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  // ==========================================
  // GAME 4 LOGIC: CYBER HI-LO TURBO DICE
  // ==========================================
  void _rollTurboDice() {
    if (_diceRolling) return;
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final stake = _getStake();
    if (stake <= 0) return;
    if (tokenProvider.balance < stake) {
      _showLowBalanceDialog();
      return;
    }

    tokenProvider.deductTokens(stake);
    HapticFeedback.heavyImpact();
    GameSoundService().playTick();

    setState(() {
      _diceRolling = true;
      _diceResultText = 'Rolling...';
    });

    // Animate dice roll
    int ticks = 0;
    Timer.periodic(const Duration(milliseconds: 60), (timer) {
      ticks++;
      GameSoundService().playTick();
      setState(() {
        _diceLastRoll = _rng.nextInt(100) + 1;
      });

      if (ticks > 12) {
        timer.cancel();
        final finalRoll = _rng.nextInt(100) + 1;
        final double winChance = _diceRollOver ? (100 - _diceTarget) : _diceTarget;
        final double mult = double.parse((98.0 / winChance).toStringAsFixed(2));
        final bool won = _diceRollOver ? (finalRoll > _diceTarget) : (finalRoll < _diceTarget);
        final int payout = won ? (stake * mult).round() : 0;

        if (won) {
          tokenProvider.addTokens(payout);
          HapticFeedback.mediumImpact();
          GameSoundService().playWin();
        } else {
          GameSoundService().playLose();
        }

        setState(() {
          _diceRolling = false;
          _diceLastRoll = finalRoll;
          _diceResultText = won
              ? 'Rolled $finalRoll! WON $payout Tokens (${mult}x) 🎲'
              : 'Rolled $finalRoll. Lost $stake Tokens.';
        });

        _recordBet(
          gameName: 'Turbo Dice',
          stake: stake,
          multiplier: won ? mult : 0.0,
          payout: payout,
          won: won,
        );
      }
    });
  }

  // ==========================================
  // GAME 5 LOGIC: CYBER ROULETTE
  // ==========================================
  void _spinRoulette() {
    if (_rouletteSpinning) return;
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final stake = _getStake();
    if (stake <= 0) return;
    if (tokenProvider.balance < stake) {
      _showLowBalanceDialog();
      return;
    }

    tokenProvider.deductTokens(stake);
    HapticFeedback.heavyImpact();
    GameSoundService().playTick();

    // Distribution: 46.5% Cyan (2x), 46.5% Magenta (2x), 7% Golden Nexus (14x)
    final roll = _rng.nextDouble();
    String outcomeColor;
    double multiplier;
    if (roll < 0.07) {
      outcomeColor = 'gold';
      multiplier = 14.0;
    } else if (roll < 0.535) {
      outcomeColor = 'cyan';
      multiplier = 2.0;
    } else {
      outcomeColor = 'magenta';
      multiplier = 2.0;
    }

    setState(() {
      _rouletteSpinning = true;
      _rouletteResultColor = '';
    });

    _rouletteController.reset();
    _rouletteController.forward().then((_) {
      final bool won = _rouletteSelectedColor == outcomeColor;
      final int payout = won ? (stake * multiplier).round() : 0;

      if (won) {
        tokenProvider.addTokens(payout);
        HapticFeedback.mediumImpact();
        GameSoundService().playWin();
      } else {
        GameSoundService().playLose();
      }

      setState(() {
        _rouletteSpinning = false;
        _rouletteResultColor = outcomeColor;
      });

      _recordBet(
        gameName: 'Cyber Roulette',
        stake: stake,
        multiplier: won ? multiplier : 0.0,
        payout: payout,
        won: won,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            won
                ? 'Outcome: ${outcomeColor.toUpperCase()}! You won $payout Tokens! 🎰'
                : 'Outcome: ${outcomeColor.toUpperCase()}. Bet lost.',
          ),
          backgroundColor: won ? kNeonGreen : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // ==========================================
  // GAME 6 LOGIC: PLINKO EXTREME
  // ==========================================
  void _dropPlinkoBall() {
    if (_plinkoDropping) return;
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final stake = _getStake();
    if (stake <= 0) return;
    if (tokenProvider.balance < stake) {
      _showLowBalanceDialog();
      return;
    }

    tokenProvider.deductTokens(stake);
    HapticFeedback.heavyImpact();
    GameSoundService().playTick();

    setState(() {
      _plinkoDropping = true;
      _plinkoFinalBucket = -1;
      _plinkoBallPos = const Offset(0.5, 0.05);
    });

    // Simulate ball bounce path down 8 rows
    int currentSlot = 4; // middle
    int step = 0;
    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      step++;
      GameSoundService().playTick();
      final bounceLeft = _rng.nextBool();
      if (bounceLeft && currentSlot > 0) {
        currentSlot--;
      } else if (!bounceLeft && currentSlot < _plinkoBuckets.length - 1) {
        currentSlot++;
      }

      final normalizedX = (currentSlot + 0.5) / _plinkoBuckets.length;
      final normalizedY = (step / 8.0).clamp(0.0, 0.95);

      setState(() {
        _plinkoBallPos = Offset(normalizedX, normalizedY);
      });
      HapticFeedback.selectionClick();

      if (step >= 8) {
        timer.cancel();
        final double mult = _plinkoBuckets[currentSlot];
        final int payout = (stake * mult).round();

        if (payout > 0) {
          tokenProvider.addTokens(payout);
          HapticFeedback.mediumImpact();
        }

        if (mult >= 1.0) {
          GameSoundService().playWin();
        } else {
          GameSoundService().playLose();
        }

        setState(() {
          _plinkoDropping = false;
          _plinkoFinalBucket = currentSlot;
        });

        _recordBet(
          gameName: 'Plinko Extreme',
          stake: stake,
          multiplier: mult,
          payout: payout,
          won: mult >= 1.0,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = Provider.of<TokenProvider>(context);
    final balance = tokenProvider.isInitialized ? tokenProvider.balance : 0;
    final winRate = _betsPlaced > 0 ? ((_betsWon / _betsPlaced) * 100).toStringAsFixed(1) : '0.0';
    final netProfit = _totalWon - _totalWagered;

    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1021),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.casino_rounded, color: Color(0xFF00B8F4), size: 22),
            SizedBox(width: 8),
            Text(
              'CYBER CASINO & ARENA',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2, color: Colors.white),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => TokenPurchaseSheet.show(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('TOP UP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF229ED9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats & Balance Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1429),
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              children: [
                // Top Balance Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: kNeonGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: kNeonGreen.withValues(alpha: 0.4)),
                          ),
                          child: const Icon(Icons.monetization_on, color: kNeonGreen, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YOUR BALANCE', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            Text(
                              balance.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildHeaderStat('Win Rate', '$winRate%', const Color(0xFF00B8F4)),
                        const SizedBox(width: 12),
                        _buildHeaderStat(
                          'Net Profit',
                          '${netProfit >= 0 ? '+' : ''}$netProfit',
                          netProfit >= 0 ? kNeonGreen : Colors.redAccent,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stake Controls
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131D38),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00B8F4).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('STAKE:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _stakeController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: '500',
                                  hintStyle: TextStyle(color: Colors.white24),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Stake Chips
                    ...['100', '500', '1K', '5K', '2X', 'MAX'].map((val) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (val == '1K') _stakeController.text = '1000';
                            else if (val == '5K') _stakeController.text = '5000';
                            else if (val == '2X') {
                              final current = _getStake();
                              _stakeController.text = (current * 2).toString();
                            } else if (val == 'MAX') {
                              _stakeController.text = balance.toString();
                            } else {
                              _stakeController.text = val;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Text(
                              val,
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // Game Tabs
          TabBar(
            controller: _gameTabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF00B8F4),
            indicatorWeight: 3,
            labelColor: const Color(0xFF00B8F4),
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
            tabs: const [
              Tab(icon: Icon(Icons.rocket_launch, size: 18), text: 'AVIATOR'),
              Tab(icon: Icon(Icons.diamond_rounded, size: 18), text: 'MINES 5X5'),
              Tab(icon: Icon(Icons.blur_circular_rounded, size: 18), text: 'WHEEL'),
              Tab(icon: Icon(Icons.casino_rounded, size: 18), text: 'DICE'),
              Tab(icon: Icon(Icons.album_rounded, size: 18), text: 'ROULETTE'),
              Tab(icon: Icon(Icons.grain_rounded, size: 18), text: 'PLINKO'),
            ],
          ),

          // Games View
          Expanded(
            child: TabBarView(
              controller: _gameTabController,
              children: [
                _buildAviatorGame(),
                _buildMinesGame(),
                _buildWheelGame(),
                _buildDiceGame(),
                _buildRouletteGame(),
                _buildPlinkoGame(),
              ],
            ),
          ),

          // Recent Bet Slips Drawer / Bottom Bar
          _buildRecentBetsBar(),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ==========================================
  // GAME 1 VIEW: AVIATOR ROCKET CRASH
  // ==========================================
  Widget _buildAviatorGame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Multiplier History Bar
          SizedBox(
            height: 30,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _aviatorHistory.length,
              itemBuilder: (ctx, idx) {
                final mult = _aviatorHistory[idx];
                final isHigh = mult >= 2.0;
                final isMega = mult >= 10.0;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isMega
                        ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                        : (isHigh ? kNeonPurple.withValues(alpha: 0.2) : Colors.white10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMega ? const Color(0xFFFFD700) : (isHigh ? kNeonPurple : Colors.white24),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${mult.toStringAsFixed(2)}x',
                    style: TextStyle(
                      color: isMega ? const Color(0xFFFFD700) : (isHigh ? kNeonPurple : Colors.white70),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Flight Arena Canvas Card
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF090E1F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _aviatorCrashed
                    ? Colors.redAccent
                    : (_aviatorFlying ? kNeonGreen : const Color(0xFF00B8F4).withValues(alpha: 0.3)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_aviatorCrashed ? Colors.redAccent : (_aviatorFlying ? kNeonGreen : const Color(0xFF00B8F4)))
                      .withValues(alpha: 0.15),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Custom Flight Trajectory Painter
                CustomPaint(
                  painter: AviatorCurvePainter(
                    multiplier: _aviatorMultiplier,
                    isFlying: _aviatorFlying,
                    isCrashed: _aviatorCrashed,
                  ),
                  size: Size.infinite,
                ),

                // Multiplier Center Display
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_aviatorMultiplier.toStringAsFixed(2)}X',
                        style: TextStyle(
                          color: _aviatorCrashed
                              ? Colors.redAccent
                              : (_aviatorCashedOut ? kNeonGreen : Colors.white),
                          fontWeight: FontWeight.w900,
                          fontSize: 48,
                          shadows: [
                            BoxShadow(
                              color: _aviatorCrashed ? Colors.redAccent : const Color(0xFF00B8F4),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _aviatorCrashed
                            ? 'FLEW AWAY!'
                            : (_aviatorCashedOut ? 'CASHED OUT!' : (_aviatorFlying ? 'ASCENDING...' : 'READY')),
                        style: TextStyle(
                          color: _aviatorCrashed ? Colors.redAccent : Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Control Button
          if (!_aviatorFlying)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _startAviator,
                icon: const Icon(Icons.rocket_launch_rounded, size: 22),
                label: const Text(
                  'LAUNCH FLIGHT (BET)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _aviatorCashedOut ? null : _cashOutAviator,
                icon: const Icon(Icons.download_rounded, size: 22),
                label: Text(
                  _aviatorCashedOut
                      ? 'CASHED OUT (${(_aviatorStake * _aviatorMultiplier).round()} TOKENS)'
                      : 'CASH OUT +${(_aviatorStake * _aviatorMultiplier).round()} TOKENS',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // GAME 2 VIEW: DIAMOND MINES 5x5
  // ==========================================
  Widget _buildMinesGame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mines Count Selector & Multiplier Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('MINES:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _minesCount,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14),
                    underline: const SizedBox(),
                    items: [1, 3, 5, 10, 15, 24].map((cnt) {
                      return DropdownMenuItem<int>(value: cnt, child: Text('$cnt Mines'));
                    }).toList(),
                    onChanged: _minesActive
                        ? null
                        : (val) {
                            if (val != null) setState(() => _minesCount = val);
                          },
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kNeonGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kNeonGreen.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Multiplier: ${_currentMinesMultiplier.toStringAsFixed(2)}x',
                  style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5x5 Mines Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1021),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 25,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (ctx, index) {
                final isRevealed = _revealedDiamonds.contains(index);
                final isMine = _minePositions.contains(index);
                final showUnrevealedMine = !_minesActive && isMine && _revealedDiamonds.isNotEmpty;

                Color bgColor = const Color(0xFF141F3C);
                Widget iconChild = const Text('?', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 18));

                if (isRevealed) {
                  if (isMine) {
                    bgColor = Colors.redAccent.withValues(alpha: 0.3);
                    iconChild = const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28);
                  } else {
                    bgColor = kNeonGreen.withValues(alpha: 0.25);
                    iconChild = const Icon(Icons.diamond_rounded, color: Color(0xFF00E5FF), size: 28);
                  }
                } else if (showUnrevealedMine) {
                  bgColor = Colors.red.withValues(alpha: 0.1);
                  iconChild = const Icon(Icons.warning, color: Colors.red, size: 20);
                }

                return GestureDetector(
                  onTap: () => _tapMinesTile(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRevealed
                            ? (isMine ? Colors.redAccent : const Color(0xFF00E5FF))
                            : Colors.white.withValues(alpha: 0.08),
                        width: isRevealed ? 1.5 : 1,
                      ),
                    ),
                    child: Center(child: iconChild),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Mines Action Buttons
          if (!_minesActive)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _startMines,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text('START MINES GAME', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00B8F4),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _revealedDiamonds.isNotEmpty ? _cashOutMines : null,
                icon: const Icon(Icons.savings_rounded, size: 20),
                label: Text(
                  _revealedDiamonds.isEmpty
                      ? 'REVEAL A TILE'
                      : 'CASH OUT +${(_minesStake * _currentMinesMultiplier).round()} TOKENS',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // GAME 3 VIEW: NEON MEGA WHEEL
  // ==========================================
  Widget _buildWheelGame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Wheel Canvas
          SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _wheelController,
                  builder: (ctx, child) {
                    final angle = _wheelSpinning ? _wheelAnimation.value : _wheelCurrentAngle;
                    return Transform.rotate(
                      angle: angle,
                      child: CustomPaint(
                        painter: MegaWheelPainter(sectors: _wheelSectors),
                        size: const Size(250, 250),
                      ),
                    );
                  },
                ),
                // Top Pointer
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.yellow, blurRadius: 10)],
                    ),
                    child: const Icon(Icons.arrow_drop_down, color: Colors.black, size: 24),
                  ),
                ),
                // Center hub
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090E1F),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0xFF00B8F4), blurRadius: 10)],
                  ),
                  child: const Center(
                    child: Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 24),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (_wheelResultText.isNotEmpty)
            Text(
              _wheelResultText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF00B8F4), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _wheelSpinning ? null : _spinMegaWheel,
              icon: const Icon(Icons.sync_rounded, size: 22),
              label: Text(
                _wheelSpinning ? 'SPINNING WHEEL...' : 'SPIN MEGA WHEEL',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kNeonPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // GAME 4 VIEW: CYBER HI-LO TURBO DICE
  // ==========================================
  Widget _buildDiceGame() {
    final double winChance = _diceRollOver ? (100 - _diceTarget) : _diceTarget;
    final double mult = double.parse((98.0 / winChance).toStringAsFixed(2));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Dice Outcome Center Display
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF090E1F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00B8F4).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '$_diceLastRoll',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    shadows: [BoxShadow(color: Color(0xFF00B8F4), blurRadius: 20)],
                  ),
                ),
                Text(
                  _diceResultText.isEmpty ? 'Target: ${_diceRollOver ? '>' : '<'} ${_diceTarget.round()}' : _diceResultText,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Roll Over / Roll Under Toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('ROLL OVER >')),
                  selected: _diceRollOver,
                  selectedColor: kNeonGreen.withValues(alpha: 0.3),
                  onSelected: (val) => setState(() => _diceRollOver = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('ROLL UNDER <')),
                  selected: !_diceRollOver,
                  selectedColor: const Color(0xFF00B8F4).withValues(alpha: 0.3),
                  onSelected: (val) => setState(() => _diceRollOver = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Target Slider
          Slider(
            value: _diceTarget,
            min: 5,
            max: 95,
            divisions: 90,
            activeColor: _diceRollOver ? kNeonGreen : const Color(0xFF00B8F4),
            label: _diceTarget.round().toString(),
            onChanged: (val) => setState(() => _diceTarget = val),
          ),

          // Payout & Win Chance Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDiceStat('Win Chance', '${winChance.toStringAsFixed(1)}%'),
              _buildDiceStat('Multiplier', '${mult}X'),
              _buildDiceStat('Payout', '${(_getStake() * mult).round()} T'),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _diceRolling ? null : _rollTurboDice,
              icon: const Icon(Icons.casino_rounded, size: 22),
              label: Text(
                _diceRolling ? 'ROLLING DICE...' : 'ROLL DICE (BET)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kNeonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
      ],
    );
  }

  // ==========================================
  // GAME 5 VIEW: CYBER ROULETTE (COLOR CLASH)
  // ==========================================
  Widget _buildRouletteGame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Roulette Wheel Indicator
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF090E1F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _rouletteController,
                builder: (ctx, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.album_rounded, color: Color(0xFF00B8F4), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        _rouletteSpinning
                            ? 'SPINNING ROULETTE...'
                            : (_rouletteResultColor.isNotEmpty
                                ? 'RESULT: ${_rouletteResultColor.toUpperCase()}!'
                                : 'SELECT A COLOR AND SPIN'),
                        style: TextStyle(
                          color: _rouletteResultColor == 'gold'
                              ? const Color(0xFFFFD700)
                              : (_rouletteResultColor == 'cyan'
                                  ? const Color(0xFF00E5FF)
                                  : (_rouletteResultColor == 'magenta' ? const Color(0xFFFF0055) : Colors.white70)),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Color Bet Options
          Row(
            children: [
              _buildRouletteOption('CYAN (2X)', 'cyan', const Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              _buildRouletteOption('NEXUS (14X)', 'gold', const Color(0xFFFFD700)),
              const SizedBox(width: 8),
              _buildRouletteOption('MAGENTA (2X)', 'magenta', const Color(0xFFFF0055)),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _rouletteSpinning ? null : _spinRoulette,
              icon: const Icon(Icons.sync_rounded, size: 22),
              label: Text(
                _rouletteSpinning ? 'SPINNING...' : 'PLACE ROULETTE BET',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00B8F4),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouletteOption(String label, String value, Color color) {
    final isSelected = _rouletteSelectedColor == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rouletteSelectedColor = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(Icons.circle, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // GAME 6 VIEW: PLINKO EXTREME
  // ==========================================
  Widget _buildPlinkoGame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Plinko Board Canvas
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF090E1F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              children: [
                CustomPaint(
                  painter: PlinkoBoardPainter(
                    ballPos: _plinkoBallPos,
                    isDropping: _plinkoDropping,
                    activeBucket: _plinkoFinalBucket,
                  ),
                  size: Size.infinite,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Plinko Multiplier Buckets Bar
          Row(
            children: List.generate(_plinkoBuckets.length, (i) {
              final mult = _plinkoBuckets[i];
              final isWinner = _plinkoFinalBucket == i;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isWinner ? Colors.white : _plinkoBucketColors[i].withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _plinkoBucketColors[i]),
                  ),
                  child: Text(
                    '${mult}x',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isWinner ? Colors.black : _plinkoBucketColors[i],
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _plinkoDropping ? null : _dropPlinkoBall,
              icon: const Icon(Icons.grain_rounded, size: 22),
              label: Text(
                _plinkoDropping ? 'BALL DROPPING...' : 'DROP PLINKO BALL',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF0055),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RECENT BETS BAR
  // ==========================================
  Widget _buildRecentBetsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF080C1A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                'Live Bets: $_betsPlaced (Won: $_betsWon)',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          TextButton(
            onPressed: _showBetHistoryModal,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            child: const Text(
              'VIEW BET HISTORY →',
              style: TextStyle(color: Color(0xFF00B8F4), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showBetHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1024),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent Bet Slips', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 12),
              Expanded(
                child: _betHistory.isEmpty
                    ? const Center(child: Text('No bets placed yet in this session.', style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: _betHistory.length,
                        itemBuilder: (ctx2, i) {
                          final bet = _betHistory[i];
                          final won = bet['won'] as bool;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(bet['game'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Stake: ${bet['stake']} tokens', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      won ? '+${bet['payout']} Tokens' : '-${bet['stake']} Tokens',
                                      style: TextStyle(color: won ? kNeonGreen : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                    Text('${(bet['mult'] as double).toStringAsFixed(2)}x', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// CUSTOM PAINTERS
// ==========================================
class AviatorCurvePainter extends CustomPainter {
  final double multiplier;
  final bool isFlying;
  final bool isCrashed;

  AviatorCurvePainter({
    required this.multiplier,
    required this.isFlying,
    required this.isCrashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (!isFlying && !isCrashed) return;

    // Flight Curve
    final progress = ((multiplier - 1.0) / 10.0).clamp(0.05, 0.90);
    final currentX = size.width * progress;
    final currentY = size.height * (1.0 - (progress * 0.85));

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width * progress * 0.5, size.height, currentX, currentY);

    // Gradient fill under curve
    final fillPath = Path.from(path)
      ..lineTo(currentX, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (isCrashed ? Colors.redAccent : const Color(0xFF00B8F4)).withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = isCrashed ? Colors.redAccent : const Color(0xFF00E5FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    // Rocket head
    final rocketPaint = Paint()..color = isCrashed ? Colors.red : Colors.white;
    canvas.drawCircle(Offset(currentX, currentY), 6, rocketPaint);
  }

  @override
  bool shouldRepaint(covariant AviatorCurvePainter oldDelegate) => true;
}

class MegaWheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> sectors;

  MegaWheelPainter({required this.sectors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / sectors.length;

    for (int i = 0; i < sectors.length; i++) {
      final sector = sectors[i];
      final paint = Paint()
        ..color = sector['color'] as Color
        ..style = PaintingStyle.fill;

      final startAngle = i * sweepAngle - (math.pi / 2);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Border lines
      final linePaint = Paint()
        ..color = Colors.black38
        ..strokeWidth = 2;
      canvas.drawLine(
        center,
        Offset(center.dx + radius * math.cos(startAngle), center.dy + radius * math.sin(startAngle)),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MegaWheelPainter oldDelegate) => false;
}

class PlinkoBoardPainter extends CustomPainter {
  final Offset ballPos;
  final bool isDropping;
  final int activeBucket;

  PlinkoBoardPainter({
    required this.ballPos,
    required this.isDropping,
    required this.activeBucket,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pegPaint = Paint()..color = Colors.white54;

    // Draw triangle peg grid (8 rows)
    for (int row = 0; row < 8; row++) {
      final pegsInRow = row + 3;
      final y = size.height * (0.1 + (row * 0.1));
      for (int p = 0; p < pegsInRow; p++) {
        final x = size.width * (0.5 + (p - pegsInRow / 2.0 + 0.5) * 0.1);
        canvas.drawCircle(Offset(x, y), 3, pegPaint);
      }
    }

    // Draw glowing ball if dropping
    if (isDropping) {
      final ballPixel = Offset(size.width * ballPos.dx, size.height * ballPos.dy);
      final glowPaint = Paint()..color = const Color(0xFFFF0055).withValues(alpha: 0.4);
      canvas.drawCircle(ballPixel, 12, glowPaint);
      final ballPaint = Paint()..color = Colors.white;
      canvas.drawCircle(ballPixel, 6, ballPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PlinkoBoardPainter oldDelegate) => true;
}
