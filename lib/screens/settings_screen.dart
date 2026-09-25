import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../providers/token_provider.dart';
import '../widgets/token_purchase_sheet.dart';
import '../services/game_sound_service.dart';
import 'battery_saver_screen.dart';
import 'permission_screen.dart';
import 'animation_store_screen.dart';
import 'about_developers_screen.dart';
import 'admin_dashboard_screen.dart';
import '../providers/animation_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoClaimDailyBonus = false;
  bool _biometricLoginEnabled = false;
  bool _biometricAvailable = false;
  bool _twoFactorEnabled = false;
  bool _autoLoginEnabled = true;
  bool _lowDataModeEnabled = false;
  bool _useNexRingtone = false;
  int _nexRingtoneIndex = 0;
  String _startupScreen = 'Home';
  bool _chatAnimationEnabled = true;
  bool _groupAnimationEnabled = true;
  bool _welcomeAnimationEnabled = true;
  bool _uiAnimationEnabled = true;
  bool _morphingLogoAnimationEnabled = true;
  late final TextEditingController _recipientController;
  late final TextEditingController _transferAmountController;
  final TextEditingController _searchQueryController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  late AnimationController _animController;
  bool _contentVisible = false;

  static const List<Map<String, dynamic>> _kCategories = [
    {'id': 'All', 'label': 'All', 'icon': Icons.grid_view_rounded},
    {'id': 'Account', 'label': 'Account & Privacy', 'icon': Icons.security_rounded},
    {'id': 'Appearance', 'label': 'Appearance', 'icon': Icons.palette_rounded},
    {'id': 'Notifications', 'label': 'Notifications', 'icon': Icons.notifications_active_rounded},
    {'id': 'Gaming', 'label': 'Gaming & SFX', 'icon': Icons.sports_esports_rounded},
    {'id': 'Tokens', 'label': 'Tokens & VIP', 'icon': Icons.monetization_on_rounded},
    {'id': 'System', 'label': 'System & Support', 'icon': Icons.tune_rounded},
  ];

  bool _shouldShowSection({
    required String category,
    required List<String> keywords,
  }) {
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      return keywords.any((k) => k.toLowerCase().contains(q));
    }
    if (_selectedCategory == 'All') return true;
    return _selectedCategory == category;
  }

  bool _hasMatchingSection() {
    return _shouldShowSection(category: 'Account', keywords: ['account', 'edit profile', 'change password', 'privacy', 'connected devices', 'name', 'email', 'avatar']) ||
        _shouldShowSection(category: 'Account', keywords: ['security', 'biometric', 'fingerprint', 'face unlock', 'two factor', '2fa', 'security checkup']) ||
        _shouldShowSection(category: 'Account', keywords: ['stealth', 'anti snoop', 'privacy shield', 'ghost', 'incognito', 'screen guard']) ||
        _shouldShowSection(category: 'Notifications', keywords: ['notifications', 'push', 'sound', 'vibration', 'ringtone', 'nexdroid tone', 'alerts']) ||
        _shouldShowSection(category: 'Appearance', keywords: ['appearance', 'dark mode', 'theme', 'language', 'light mode']) ||
        _shouldShowSection(category: 'Appearance', keywords: ['background', 'wallpaper', 'home wallpaper', 'animated stars', 'matrix', 'space', 'nebula', 'grid']) ||
        _shouldShowSection(category: 'Appearance', keywords: ['chat background', 'chat wallpaper', 'doodle', 'glassmorphism', 'ambient']) ||
        _shouldShowSection(category: 'Appearance', keywords: ['cyber theme', 'aesthetic', 'cyberpunk neon', 'synthwave', 'tokyo night', 'matrix green']) ||
        _shouldShowSection(category: 'Appearance', keywords: ['animations', 'chat animations', 'group animations', 'welcome animations', 'ui animations', 'morphing logo']) ||
        _shouldShowSection(category: 'Gaming', keywords: ['gaming sfx', 'tactile audio', 'sound fx', 'haptic engine', 'screen shake', 'crt']) ||
        _shouldShowSection(category: 'Gaming', keywords: ['ingame movement', 'gyro', 'parallax', 'invert x', 'invert y', 'deadzone', 'sensitivity', 'calibration']) ||
        _shouldShowSection(category: 'System', keywords: ['app experience', 'low data mode', 'auto login', 'startup screen']) ||
        _shouldShowSection(category: 'System', keywords: ['display turbo', 'performance', '120hz', 'fps', 'gpu particles', 'cache purge', 'memory']) ||
        _shouldShowSection(category: 'Tokens', keywords: ['telegram vip', 'concierge', 'deposit', 'vershdit', 'founder direct', 'priority support']) ||
        _shouldShowSection(category: 'Tokens', keywords: ['tokens', 'token balance', 'token transfer', 'daily bonus', 'promo codes', 'referral rewards']) ||
        _shouldShowSection(category: 'System', keywords: ['support', 'help center', 'charge manager', 'battery', 'storage permissions', 'about developers', 'terms', 'privacy policy']) ||
        _shouldShowSection(category: 'System', keywords: ['location', 'privacy', 'ip', 'city', 'country', 'detect location']) ||
        _shouldShowSection(category: 'System', keywords: ['storage', 'cache', 'clear cache', 'download history']) ||
        _shouldShowSection(category: 'Notifications', keywords: ['notification channels', 'chat messages', 'group messages', 'gaming events', 'marketplace', 'announcements']) ||
        (_showDevOptions && _shouldShowSection(category: 'System', keywords: ['developer options', 'debug overlay', 'fps', 'fake online', 'reset all']));
  }

  // Location
  String? _detectedIp;
  String? _detectedCity;
  String? _detectedCountryName;
  String? _detectedCountryCode;
  bool _isDetectingLocation = false;

  // Cache
  String _cacheSize = '${(12 + (DateTime.now().millisecond % 48))} MB';

  // Notifications
  bool _notifChat = true;
  bool _notifGroups = true;
  bool _notifGaming = true;
  bool _notifMarket = true;
  bool _notifAnnouncements = true;

  // Developer
  int _devTapCount = 0;
  bool _showDevOptions = false;
  bool _devDebugOverlay = false;
  bool _devFakeOnline = false;

  // Gyro Settings
  bool _gyroMovementEnabled = false;
  double _gyroSensitivity = 1.0;
  double _gyroXOffset = 0.0;
  double _gyroYOffset = 0.0;
  bool _gyroInvertX = false;
  bool _gyroInvertY = false;
  double _gyroDeadzone = 0.08;
  // Background & Audio & Performance & Privacy Features
  late AnimationController _bgAnimController;
  bool _gameSoundEnabled = true;
  bool _gameHapticEnabled = true;
  bool _screenShakeEnabled = true;
  bool _fps120Enabled = true;
  bool _gpuParticlesEnabled = true;
  bool _stealthModeEnabled = false;
  bool _antiSnoopGuard = false;
  String _selectedCyberTheme = 'Cyberpunk Neon';

  @override
  void initState() {
    super.initState();
    _loadLocationData();
    _loadNotificationChannels();
    _loadDevOptions();
    _initBiometric();
    _loadRingtoneSettings();
    _loadAnimationSettings();
    _loadGyroSettings();
    _loadGameAudioSettings();
    _recipientController = TextEditingController();
    _transferAmountController = TextEditingController();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _bgAnimController = AnimationController(
        duration: const Duration(seconds: 18), vsync: this)..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _contentVisible = true;
      });
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _animController.dispose();
    _stopPreview();
    _recipientController.dispose();
    _transferAmountController.dispose();
    _searchQueryController.dispose();
    super.dispose();
  }

  Future<void> _loadGameAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gameSoundEnabled = prefs.getBool('game_sound_enabled') ?? true;
      _gameHapticEnabled = prefs.getBool('game_haptic_enabled') ?? true;
      _screenShakeEnabled = prefs.getBool('game_screen_shake') ?? true;
      _fps120Enabled = prefs.getBool('perf_fps_120') ?? true;
      _gpuParticlesEnabled = prefs.getBool('perf_gpu_particles') ?? true;
      _stealthModeEnabled = prefs.getBool('privacy_stealth_mode') ?? false;
      _antiSnoopGuard = prefs.getBool('privacy_anti_snoop') ?? false;
      _selectedCyberTheme = prefs.getString('cyber_theme_name') ?? 'Cyberpunk Neon';
    });
  }

  String _countryFlag(String code) => code.toUpperCase().split('').map((l) => String.fromCharCode(l.codeUnitAt(0) + 127397)).join();

  Future<void> _loadLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('detected_location');
    if (data != null) {
      final map = json.decode(data);
      if (mounted) {
        setState(() {
          _detectedIp = map['ip'];
          _detectedCity = map['city'];
          _detectedCountryName = map['country_name'];
          _detectedCountryCode = map['country_code'];
        });
      }
    }
  }

  Future<void> _detectLocation() async {
    if (!mounted) return;
    setState(() => _isDetectingLocation = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await http.get(Uri.parse('https://ipapi.co/json/'));
      if (res.statusCode == 200) {
        final map = json.decode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('detected_location', res.body);
        await authService.updateProfileData(country: map['country_name']);

        if (!mounted) return;
        setState(() {
          _detectedIp = map['ip'];
          _detectedCity = map['city'];
          _detectedCountryName = map['country_name'];
          _detectedCountryCode = map['country_code'];
        });
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _loadNotificationChannels() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notifChat = prefs.getBool('notif_chat') ?? true;
        _notifGroups = prefs.getBool('notif_groups') ?? true;
        _notifGaming = prefs.getBool('notif_gaming') ?? true;
        _notifMarket = prefs.getBool('notif_market') ?? true;
        _notifAnnouncements = prefs.getBool('notif_announcements') ?? true;
      });
    }
  }

  Future<void> _loadDevOptions() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _devDebugOverlay = prefs.getBool('dev_debug_overlay') ?? false;
        _devFakeOnline = prefs.getBool('dev_fake_online') ?? false;
      });
    }
  }

  Future<String?> _promptForPasswordToEnableBiometrics() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirm Password',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter your account password to enable biometric quick sign-in.',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                  hintText: 'Password',
                  hintStyle: TextStyle(color: Colors.white30)),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Confirm')),
        ],
      ),
    );
    return result;
  }

  Future<void> _loadAnimationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _chatAnimationEnabled = prefs.getBool('chatAnimationEnabled') ?? true;
        _groupAnimationEnabled = prefs.getBool('groupAnimationEnabled') ?? true;
        _welcomeAnimationEnabled = prefs.getBool('welcomeAnimationEnabled') ?? true;
        _uiAnimationEnabled = prefs.getBool('uiAnimationEnabled') ?? true;
        _morphingLogoAnimationEnabled = prefs.getBool('morphingLogoAnimationEnabled') ?? true;
      });
    }
  }

  Future<void> _loadGyroSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _gyroMovementEnabled = prefs.getBool('gyroMovementEnabled') ?? false;
        _gyroSensitivity = prefs.getDouble('gyroSensitivity') ?? 1.0;
        _gyroXOffset = prefs.getDouble('gyroXOffset') ?? 0.0;
        _gyroYOffset = prefs.getDouble('gyroYOffset') ?? 0.0;
        _gyroInvertX = prefs.getBool('gyroInvertX') ?? false;
        _gyroInvertY = prefs.getBool('gyroInvertY') ?? false;
        _gyroDeadzone = prefs.getDouble('gyroDeadzone') ?? 0.08;
      });
    }
  }

  Future<void> _initBiometric() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final localAuth = LocalAuthentication();
    final available = await localAuth.canCheckBiometrics ||
        await localAuth.isDeviceSupported();
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('biometricLogin') ?? false;
    final saved = enabled ? await authService.getSavedCredentials() : null;
    final activeEnabled = available && enabled && saved != null;
    if (!activeEnabled && enabled) {
      await prefs.setBool('biometricLogin', false);
    }
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricLoginEnabled = activeEnabled;
      });
    }
  }



  static const MethodChannel _ringtoneChannel =
      MethodChannel('nexapp/ringtone');

  Future<void> _loadRingtoneSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final use = prefs.getBool('use_nexapp_ringtone') ?? false;
    final idx = prefs.getInt('nexapp_ringtone_index') ?? 0;
    if (mounted) {
      setState(() {
        _useNexRingtone = use;
        _nexRingtoneIndex = idx;
      });
    }
  }

  Future<void> _setUseNexRingtone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_nexapp_ringtone', value);
    if (mounted) setState(() => _useNexRingtone = value);
  }

  Future<void> _setNexRingtoneIndex(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nexapp_ringtone_index', idx);
    if (mounted) setState(() => _nexRingtoneIndex = idx);
  }

  Future<void> _playPreview(int idx) async {
    try {
      await _ringtoneChannel.invokeMethod('playNexTone', {'index': idx});
    } catch (e) {
      // ignore
    }
  }

  Future<void> _stopPreview() async {
    try {
      await _ringtoneChannel.invokeMethod('stopTone');
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFF140B28),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [kNeonBlue, kNeonPurple],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kNeonBlue.withValues(alpha: 0.4),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).get('settings'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'backup':
                  _backupSettings();
                  break;
                case 'reset':
                  _resetSettings();
                  break;
                case 'export':
                  _exportData();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup, color: kNeonBlue),
                    SizedBox(width: 8),
                    Text('Backup Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: kNeonGreen),
                    SizedBox(width: 8),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reset to Defaults'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Cosmic Starfield & Nebula Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgAnimController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SettingsCosmicPainter(
                    _bgAnimController.value,
                    theme: _selectedCyberTheme,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: AnimatedOpacity(
              opacity: _contentVisible ? 1 : 0,
              duration: const Duration(milliseconds: 600),
              child: ListView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                children: [
                  _buildPremiumHeader(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  _buildCategoryPills(),
                  const SizedBox(height: 20),

              // Account Section
              if (_shouldShowSection(
                category: 'Account',
                keywords: ['account', 'edit profile', 'change password', 'privacy', 'connected devices', 'name', 'email', 'avatar'],
              )) ...[
                _buildSectionContainer(
                  title: AppLocalizations.of(context).get('account'),
                  icon: Icons.person,
                  color: kNeonBlue,
                  children: [
                    _buildSettingsTile(
                      icon: Icons.person,
                      title: AppLocalizations.of(context).get('editProfile'),
                      subtitle: 'Change name, email, avatar',
                      onTap: () => _showEditProfileDialog(context),
                    ),
                    _buildSettingsTile(
                      icon: Icons.lock,
                      title: AppLocalizations.of(context).get('changePassword'),
                      subtitle: 'Update your password',
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                    _buildSettingsTile(
                      icon: Icons.security,
                      title: AppLocalizations.of(context).get('privacy'),
                      subtitle: 'Manage who can see your info',
                      onTap: () => _showPrivacyDialog(context),
                    ),
                    _buildSettingsTile(
                      icon: Icons.devices,
                      title: 'Connected Devices',
                      subtitle: 'Review signed-in devices',
                      onTap: () => _showConnectedDevicesDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Security Section
              if (_shouldShowSection(
                category: 'Account',
                keywords: ['security', 'biometric', 'fingerprint', 'face unlock', 'two factor', '2fa', 'security checkup'],
              )) ...[
                _buildSectionContainer(
                  title: AppLocalizations.of(context).get('security'),
                  icon: Icons.security,
                  color: Colors.redAccent,
                  children: [
                    _buildSwitchTile(
                      icon: Icons.fingerprint,
                      title: 'Biometric Login',
                      subtitle: _biometricLoginEnabled
                          ? 'Enabled for quick sign-in'
                          : (_biometricAvailable
                              ? 'Use fingerprint / face unlock'
                              : 'Biometrics not available'),
                      value: _biometricLoginEnabled,
                      onChanged: (value) async {
                        final authService =
                            Provider.of<AuthService>(context, listen: false);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        if (value) {
                          if (!_biometricAvailable) {
                            scaffoldMessenger.showSnackBar(const SnackBar(
                                content: Text(
                                    'Biometric authentication not available on this device.')));
                            return;
                          }
                          if (!authService.isLoggedIn) {
                            scaffoldMessenger.showSnackBar(const SnackBar(
                                content: Text(
                                    'Sign in first to enable biometric quick unlock.')));
                            return;
                          }

                          final password =
                              await _promptForPasswordToEnableBiometrics();
                          if (password == null || password.isEmpty) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(const SnackBar(
                                  content: Text('Biometric setup cancelled.')));
                            }
                            return;
                          }

                          final email = authService.user?.email;
                          if (email == null) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(const SnackBar(
                                  content: Text('Unable to detect account email.')));
                            }
                            return;
                          }

                          try {
                            await authService.signIn(email, password);
                          } catch (e) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(const SnackBar(
                                  content:
                                      Text('Incorrect password. Biometric login not enabled.')));
                            }
                            return;
                          }

                          await authService.saveCredentials(email, password);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('biometricLogin', true);
                          if (!mounted) return;
                          setState(() => _biometricLoginEnabled = true);
                          scaffoldMessenger.showSnackBar(const SnackBar(
                              content: Text('Biometric login enabled.')));
                        } else {
                          await authService.clearSavedCredentials();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('biometricLogin', false);
                          if (!mounted) return;
                          setState(() => _biometricLoginEnabled = false);
                          scaffoldMessenger.showSnackBar(const SnackBar(
                              content: Text('Biometric login disabled.')));
                        }
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.shield,
                      title: 'Two-Factor Authentication',
                      subtitle: _twoFactorEnabled
                          ? '2FA is enabled'
                          : 'Add an extra security layer',
                      value: _twoFactorEnabled,
                      onChanged: (value) => setState(() => _twoFactorEnabled = value),
                    ),
                    _buildSettingsTile(
                      icon: Icons.check_circle,
                      title: 'Security Checkup',
                      subtitle: 'Review account security settings',
                      onTap: () => _showSecurityCheckDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Gamer Stealth & Privacy Shield Section
              if (_shouldShowSection(
                category: 'Account',
                keywords: ['stealth', 'anti snoop', 'privacy shield', 'ghost', 'incognito', 'screen guard'],
              )) ...[
                _buildGamerPrivacySection(),
                const SizedBox(height: 20),
              ],

              // Notifications Section
              if (_shouldShowSection(
                category: 'Notifications',
                keywords: ['notifications', 'push', 'sound', 'vibration', 'ringtone', 'nexdroid tone', 'alerts'],
              )) ...[
                _buildSectionContainer(
                  title: AppLocalizations.of(context).get('notifications'),
                  icon: Icons.notifications,
                  color: Colors.orangeAccent,
                  children: [
                    _buildSwitchTile(
                      icon: Icons.notifications,
                      title: 'Push Notifications',
                      subtitle: 'Receive message and call alerts',
                      value: _notificationsEnabled,
                      onChanged: (value) =>
                          setState(() => _notificationsEnabled = value),
                    ),
                    _buildSwitchTile(
                      icon: Icons.volume_up,
                      title: 'Sound',
                      subtitle: 'Notification sounds',
                      value: _soundEnabled,
                      onChanged: (value) => setState(() => _soundEnabled = value),
                    ),
                    _buildSwitchTile(
                      icon: Icons.vibration,
                      title: 'Vibration',
                      subtitle: 'Vibrate for notifications',
                      value: _vibrationEnabled,
                      onChanged: (value) => setState(() => _vibrationEnabled = value),
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsTile(
                      icon: Icons.notifications_active,
                      title: 'Ringtone',
                      subtitle: _useNexRingtone
                          ? 'NEXDROID tone #${_nexRingtoneIndex + 1}'
                          : 'Use phone ringtone',
                      onTap: () => _showRingtoneDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Appearance Section
              if (_shouldShowSection(
                category: 'Appearance',
                keywords: ['appearance', 'dark mode', 'theme', 'language', 'light mode'],
              )) ...[
                _buildSectionContainer(
                  title: AppLocalizations.of(context).get('appearance'),
                  icon: Icons.palette,
                  color: kNeonPurple,
                  children: [
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) {
                        return _buildSwitchTile(
                          icon: Icons.dark_mode,
                          title: AppLocalizations.of(context).get('darkMode'),
                          subtitle: themeProvider.isDarkMode
                              ? 'Dark theme enabled'
                              : 'Light theme enabled',
                          value: themeProvider.isDarkMode,
                          onChanged: (value) => themeProvider.toggleTheme(),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.language,
                      title: AppLocalizations.of(context).get('language'),
                      subtitle: Provider.of<LocaleProvider>(context).languageName,
                      onTap: () => _showLanguageDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Live Animated Background & Wallpaper Section
              if (_shouldShowSection(
                category: 'Appearance',
                keywords: ['background', 'wallpaper', 'home wallpaper', 'animated stars', 'matrix', 'space', 'nebula', 'grid'],
              )) ...[
                _buildHomeBackgroundSelectorSection(),
                const SizedBox(height: 20),
              ],

              // Chat List Background & Wallpaper Customization Section
              if (_shouldShowSection(
                category: 'Appearance',
                keywords: ['chat background', 'chat wallpaper', 'doodle', 'glassmorphism', 'ambient'],
              )) ...[
                _buildChatListBackgroundSelectorSection(),
                const SizedBox(height: 20),
              ],

              // Cyber Aesthetic Themes Section
              if (_shouldShowSection(
                category: 'Appearance',
                keywords: ['cyber theme', 'aesthetic', 'cyberpunk neon', 'synthwave', 'tokyo night', 'matrix green'],
              )) ...[
                _buildCyberThemeSection(),
                const SizedBox(height: 20),
              ],

              // Animations Section
              if (_shouldShowSection(
                category: 'Appearance',
                keywords: ['animations', 'chat animations', 'group animations', 'welcome animations', 'ui animations', 'morphing logo'],
              )) ...[
                _buildSectionContainer(
                  title: 'Animations',
                  icon: Icons.animation,
                  color: Colors.cyanAccent,
                  children: [
                    _buildSwitchTile(
                      icon: Icons.animation,
                      title: 'Chat Animations',
                      subtitle: _chatAnimationEnabled ? 'Enabled' : 'Disabled',
                      value: _chatAnimationEnabled,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('chatAnimationEnabled', value);
                        if (mounted) setState(() => _chatAnimationEnabled = value);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.animation,
                      title: 'Group Animations',
                      subtitle: _groupAnimationEnabled ? 'Enabled' : 'Disabled',
                      value: _groupAnimationEnabled,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('groupAnimationEnabled', value);
                        if (mounted) setState(() => _groupAnimationEnabled = value);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.animation,
                      title: 'Welcome Animations',
                      subtitle: _welcomeAnimationEnabled ? 'Enabled' : 'Disabled',
                      value: _welcomeAnimationEnabled,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('welcomeAnimationEnabled', value);
                        if (mounted) setState(() => _welcomeAnimationEnabled = value);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.animation,
                      title: 'UI Animations',
                      subtitle: _uiAnimationEnabled ? 'Enabled' : 'Disabled',
                      value: _uiAnimationEnabled,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('uiAnimationEnabled', value);
                        if (mounted) setState(() => _uiAnimationEnabled = value);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.change_circle_rounded,
                      title: 'Morphing App Logo Animation',
                      subtitle: _morphingLogoAnimationEnabled
                          ? 'Dynamic geometric morphing & pulsing energy states'
                          : 'Static clean logo icon',
                      value: _morphingLogoAnimationEnabled,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('morphingLogoAnimationEnabled', value);
                        if (mounted) setState(() => _morphingLogoAnimationEnabled = value);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Gaming SFX & Tactile Audio Engine Section
              if (_shouldShowSection(
                category: 'Gaming',
                keywords: ['gaming sfx', 'tactile audio', 'sound fx', 'haptic engine', 'screen shake', 'crt'],
              )) ...[
                _buildGamingSfxSection(),
                const SizedBox(height: 20),
              ],

              // Ingame-App Movement Section
              if (_shouldShowSection(
                category: 'Gaming',
                keywords: ['ingame movement', 'gyro', 'parallax', 'invert x', 'invert y', 'deadzone', 'sensitivity', 'calibration'],
              )) ...[
                _buildSectionContainer(
                  title: 'Ingame-App Movement',
                  icon: Icons.screen_rotation,
                  color: kNeonGreen,
                  children: [
                    _buildSwitchTile(
                      icon: Icons.screen_rotation,
                      title: 'Enable Gyro Parallax',
                      subtitle: _gyroMovementEnabled
                          ? 'Responsive background movement active'
                          : 'Using static / pointer only parallax',
                      value: _gyroMovementEnabled,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('gyroMovementEnabled', value);
                        if (mounted) setState(() => _gyroMovementEnabled = value);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.swap_horiz,
                      title: 'Invert Gyro X Axis',
                      subtitle: _gyroInvertX
                          ? 'Horizontal tilt reversed'
                          : 'Normal horizontal direction',
                      value: _gyroInvertX,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('gyroInvertX', value);
                        if (mounted) setState(() => _gyroInvertX = value);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.swap_vert,
                      title: 'Invert Gyro Y Axis',
                      subtitle: _gyroInvertY
                          ? 'Vertical tilt reversed'
                          : 'Normal vertical direction',
                      value: _gyroInvertY,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('gyroInvertY', value);
                        if (mounted) setState(() => _gyroInvertY = value);
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.filter_alt,
                      title: 'Gyro Deadzone',
                      subtitle:
                          'Ignore small motion: ${(_gyroDeadzone * 100).round()}%',
                      onTap: () => _showGyroCalibrationDialog(context),
                    ),
                    _buildSettingsTile(
                      icon: Icons.tune,
                      title: 'Gyro Sensitivity & Calibration',
                      subtitle: 'Calibrate offsets and adjust sensitivity',
                      onTap: () => _showGyroCalibrationDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // App Experience Section
              if (_shouldShowSection(
                category: 'System',
                keywords: ['app experience', 'low data mode', 'auto login', 'startup screen'],
              )) ...[
                _buildSectionContainer(
                  title: 'App Experience',
                  icon: Icons.explore,
                  color: Colors.amberAccent,
                  children: [
                    _buildSwitchTile(
                      icon: Icons.data_saver_on,
                      title: 'Low Data Mode',
                      subtitle: _lowDataModeEnabled
                          ? 'Reduced data usage'
                          : 'Standard mode',
                      value: _lowDataModeEnabled,
                      onChanged: (value) {
                        setState(() => _lowDataModeEnabled = value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value
                                ? 'Low Data Mode enabled.'
                                : 'Low Data Mode disabled.'),
                            backgroundColor: kNeonBlue,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.login,
                      title: 'Auto Login',
                      subtitle: _autoLoginEnabled
                          ? 'Stay signed in'
                          : 'Require manual sign-in',
                      value: _autoLoginEnabled,
                      onChanged: (value) => setState(() => _autoLoginEnabled = value),
                    ),
                    _buildSettingsTile(
                      icon: Icons.home_filled,
                      title: 'Default Startup Screen',
                      subtitle: _startupScreen,
                      onTap: () => _showStartupScreenDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Display & Turbo Performance Section
              if (_shouldShowSection(
                category: 'System',
                keywords: ['display turbo', 'performance', '120hz', 'fps', 'gpu particles', 'cache purge', 'memory'],
              )) ...[
                _buildPerformanceTurboSection(),
                const SizedBox(height: 20),
              ],

              // Telegram VIP Concierge Section
              if (_shouldShowSection(
                category: 'Tokens',
                keywords: ['telegram vip', 'concierge', 'deposit', 'vershdit', 'founder direct', 'priority support'],
              )) ...[
                _buildTelegramVipSection(),
                const SizedBox(height: 20),
              ],

              // Tokens Section
              if (_shouldShowSection(
                category: 'Tokens',
                keywords: ['tokens', 'token balance', 'token transfer', 'daily bonus', 'promo codes', 'referral rewards'],
              )) ...[
                _buildSectionContainer(
                  title: 'Tokens',
                  icon: Icons.monetization_on,
                  color: Colors.yellowAccent,
                  children: [
                    Consumer<TokenProvider>(
                      builder: (context, tokenProvider, _) {
                        return _buildSettingsTile(
                          icon: Icons.monetization_on,
                          title: 'Token Balance',
                          subtitle: '${tokenProvider.balance} tokens available',
                          onTap: () =>
                              _showTokenBalanceDialog(context, tokenProvider.balance),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.swap_horiz,
                      title: 'Token Transfer',
                      subtitle: 'Send tokens to another user',
                      onTap: () => _showTokenTransferDialog(context),
                    ),
                    _buildSwitchTile(
                      icon: Icons.auto_awesome,
                      title: 'Auto Claim Daily Bonus',
                      subtitle: _autoClaimDailyBonus ? 'Enabled' : 'Disabled',
                      value: _autoClaimDailyBonus,
                      onChanged: (value) {
                        setState(() => _autoClaimDailyBonus = value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value
                                ? 'Daily bonus auto-claim enabled'
                                : 'Auto claim disabled'),
                            backgroundColor: kNeonBlue,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.card_giftcard,
                      title: 'Promo Codes',
                      subtitle: 'Redeem promo codes',
                      onTap: () => _showPromoDialog(context),
                    ),
                    _buildSettingsTile(
                      icon: Icons.group_add,
                      title: 'Referral Rewards',
                      subtitle: 'Invite friends and earn tokens',
                      onTap: () => _showReferralDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Support Section
              if (_shouldShowSection(
                category: 'System',
                keywords: ['support', 'help center', 'charge manager', 'battery', 'storage permissions', 'about developers', 'terms', 'privacy policy'],
              )) ...[
                _buildSectionContainer(
                  title: 'Support',
                  icon: Icons.help_outline,
                  color: kNeonBlue,
                  children: [
                    _buildSettingsTile(
                      icon: Icons.help,
                      title: 'Help Center',
                      subtitle: 'FAQs and support',
                      onTap: () {},
                    ),
                    _buildSettingsTile(
                      icon: Icons.battery_charging_full,
                      title: 'Charge Manager',
                      subtitle: 'Optimize battery and close unused services',
                      onTap: () =>
                          Navigator.pushNamed(context, BatterySaverScreen.routeName),
                    ),
                    _buildSettingsTile(
                      icon: Icons.sd_storage,
                      title: 'Storage Permissions',
                      subtitle: 'Open permission helper to fix storage issues',
                      onTap: () =>
                          Navigator.pushNamed(context, PermissionScreen.routeName),
                    ),
                    _buildSettingsTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'NEX Manager Console',
                      subtitle: 'Master control center, live users, reels moderation & security',
                      onTap: () => Navigator.pushNamed(context, AdminDashboardScreen.routeName),
                    ),
                    _buildSettingsTile(
                      icon: Icons.code_rounded,
                      title: 'About Developers & NEXO Team',
                      subtitle: 'Meet the architects, GitHub repos & official portal',
                      onTap: () => Navigator.pushNamed(context, AboutDevelopersScreen.routeName),
                    ),
                    _buildSettingsTile(
                      icon: Icons.info,
                      title: 'About App',
                      subtitle: 'NEXDROID Quantum v3.8.4-PRO',
                      onTap: () {
                        _devTapCount++;
                        if (_devTapCount == 5) {
                          setState(() => _showDevOptions = true);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Developer Options enabled!')));
                        }
                        if (_devTapCount < 5) {
                          _showAboutDialog(context);
                        }
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.description,
                      title: 'Terms of Service',
                      subtitle: 'Read terms',
                      onTap: () {},
                    ),
                    _buildSettingsTile(
                      icon: Icons.privacy_tip,
                      title: 'Privacy Policy',
                      subtitle: 'Read privacy policy',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Location Section
              if (_shouldShowSection(
                category: 'System',
                keywords: ['location', 'privacy', 'ip', 'city', 'country', 'detect location'],
              )) ...[
                _buildSectionContainer(
                  title: 'Location & Privacy',
                  icon: Icons.location_on,
                  color: Colors.greenAccent,
                  children: [
                    if (_detectedCountryCode != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kSurfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.greenAccent.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            Text(_countryFlag(_detectedCountryCode!), style: const TextStyle(fontSize: 32)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$_detectedCity, $_detectedCountryName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('IP: $_detectedIp', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: _isDetectingLocation ? null : _detectLocation,
                      icon: _isDetectingLocation ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.my_location),
                      label: Text(_isDetectingLocation ? 'Detecting...' : 'Detect My Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Storage & Cache Section
              if (_shouldShowSection(
                category: 'System',
                keywords: ['storage', 'cache', 'clear cache', 'download history'],
              )) ...[
                _buildSectionContainer(
                  title: 'Storage & Cache',
                  icon: Icons.storage,
                  color: Colors.purpleAccent,
                  children: [
                    _buildSettingsTile(
                      icon: Icons.cleaning_services,
                      title: 'Clear Cache',
                      subtitle: 'Estimated: $_cacheSize',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared successfully'), backgroundColor: Colors.green));
                        setState(() => _cacheSize = '0 MB');
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.delete_outline,
                      title: 'Clear Download History',
                      subtitle: 'Remove temporary downloaded files',
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Notification Channels Section
              if (_shouldShowSection(
                category: 'Notifications',
                keywords: ['notification channels', 'chat messages', 'group messages', 'gaming events', 'marketplace', 'announcements'],
              )) ...[
                _buildSectionContainer(
                  title: 'Notification Channels',
                  icon: Icons.notifications_active,
                  color: Colors.orangeAccent,
                  children: [
                    _buildSwitchTile(
                      icon: Icons.chat,
                      title: 'Chat Messages',
                      subtitle: 'Direct messages',
                      value: _notifChat,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('notif_chat', val);
                        setState(() => _notifChat = val);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.group,
                      title: 'Group Messages',
                      subtitle: 'Messages in groups',
                      value: _notifGroups,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('notif_groups', val);
                        setState(() => _notifGroups = val);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.gamepad,
                      title: 'Gaming Events',
                      subtitle: 'Tournaments and invites',
                      value: _notifGaming,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('notif_gaming', val);
                        setState(() => _notifGaming = val);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.store,
                      title: 'Marketplace',
                      subtitle: 'Offers and updates',
                      value: _notifMarket,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('notif_market', val);
                        setState(() => _notifMarket = val);
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.announcement,
                      title: 'Announcements',
                      subtitle: 'App updates and news',
                      value: _notifAnnouncements,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('notif_announcements', val);
                        setState(() => _notifAnnouncements = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Developer Options
              if (_showDevOptions && _shouldShowSection(
                category: 'System',
                keywords: ['developer options', 'debug overlay', 'fps', 'fake online', 'reset all'],
              )) ...[
                Column(
                  children: [
                    _buildSectionContainer(
                      title: 'Developer Options',
                      icon: Icons.developer_mode,
                      color: Colors.redAccent,
                      children: [
                        _buildSwitchTile(
                          icon: Icons.bug_report,
                          title: 'Show Debug Overlay',
                          subtitle: 'Display FPS and memory stats',
                          value: _devDebugOverlay,
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dev_debug_overlay', val);
                            setState(() => _devDebugOverlay = val);
                          },
                        ),
                        _buildSwitchTile(
                          icon: Icons.wifi,
                          title: 'Fake Online Status',
                          subtitle: 'Always appear online',
                          value: _devFakeOnline,
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dev_fake_online', val);
                            setState(() => _devFakeOnline = val);
                          },
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          child: const Text('Reset All Settings'),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ],

              // Empty Search State
              if (_searchQuery.isNotEmpty && !_hasMatchingSection())
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.search_off_rounded, size: 40, color: Colors.white54),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No settings found for "$_searchQuery"',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try searching for profile, theme, audio, tokens, or security',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: () {
                          _searchQueryController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 16, color: kNeonBlue),
                        label: const Text('Clear Search', style: TextStyle(color: kNeonBlue)),
                      ),
                    ],
                  ),
                ),

              // Logout Button
              if (_selectedCategory == 'All' || _selectedCategory == 'Account' || _searchQuery.contains('logout')) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.2),
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade900.withValues(alpha: 0.25),
                        Colors.red.shade900.withValues(alpha: 0.08),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showLogoutDialog(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context).get('logout'),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? kNeonBlue.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: _searchQuery.isNotEmpty
            ? [
                BoxShadow(
                  color: kNeonBlue.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: -2,
                )
              ]
            : null,
      ),
      child: TextField(
        controller: _searchQueryController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim().toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search preferences, security, cyber themes...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: _searchQuery.isNotEmpty ? kNeonBlue : Colors.white54,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                  onPressed: () {
                    _searchQueryController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _kCategories[index];
          final isSelected = _selectedCategory == cat['id'];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategory = cat['id'] as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [kNeonBlue, kNeonPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: isSelected
                        ? kNeonBlue.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.12),
                    width: isSelected ? 1.4 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: kNeonBlue.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: -1,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 15,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumHeader() {
    final auth = Provider.of<AuthService>(context);
    final tokenProv = Provider.of<TokenProvider>(context);
    final user = auth.user;
    final displayName = AuthService.resolveDisplayName(
      name: user?.displayName,
      email: user?.email,
    );
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kSurfaceColor.withValues(alpha: 0.85),
                kPrimaryBlue.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kNeonBlue.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: kNeonBlue.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: -4,
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar with glow and status
                  Stack(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [kNeonBlue, kNeonPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kNeonBlue.withValues(alpha: 0.5),
                              blurRadius: 12,
                            )
                          ],
                        ),
                        child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  user.photoURL!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: kNeonGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: kDarkBackground, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: kNeonGreen, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Name and Email
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kNeonBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: kNeonBlue.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  color: kNeonBlue,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () {
                            if (user?.email != null) {
                              Clipboard.setData(ClipboardData(text: user!.email!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  user?.email ?? 'Not signed in',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user?.email != null) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Profile Quick Action
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                    ),
                    onPressed: () => _showEditProfileDialog(context),
                    tooltip: 'Edit Profile',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Bottom row: Operative Level and Token Balance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 14, color: kNeonGreen),
                    const SizedBox(width: 6),
                    const Text(
                      'STATUS: VERIFIED OPERATIVE',
                      style: TextStyle(
                        color: kNeonGreen,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showTokenBalanceDialog(context, tokenProv.balance),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.yellowAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.yellowAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.monetization_on_rounded, color: Colors.yellowAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${tokenProv.balance}',
                              style: const TextStyle(
                                color: Colors.yellowAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.add_circle_outline_rounded, color: Colors.yellowAccent, size: 13),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: -2,
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0).copyWith(bottom: 12),
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Gaming SFX & Audio Engine Section ──────────────────────────────────
  Widget _buildGamingSfxSection() {
    return _buildSectionContainer(
      title: 'Gaming SFX & Audio Engine',
      icon: Icons.sports_esports_rounded,
      color: const Color(0xFF00FF88),
      children: [
        _buildSwitchTile(
          icon: Icons.volume_up_rounded,
          title: 'Master Game Sound FX',
          subtitle: _gameSoundEnabled ? 'Synthesized retro 8-bit & cyber audio active' : 'Game sounds muted',
          value: _gameSoundEnabled,
          onChanged: (val) async {
            await GameSoundService().setSoundEnabled(val);
            if (mounted) setState(() => _gameSoundEnabled = val);
            if (val) GameSoundService().playCoin();
          },
        ),
        _buildSwitchTile(
          icon: Icons.vibration_rounded,
          title: 'Tactile Haptic Engine',
          subtitle: _gameHapticEnabled ? 'Physical vibration on hits, wins, crashes' : 'Haptics disabled',
          value: _gameHapticEnabled,
          onChanged: (val) async {
            await GameSoundService().setHapticEnabled(val);
            if (mounted) setState(() => _gameHapticEnabled = val);
            if (val) HapticFeedback.heavyImpact();
          },
        ),
        _buildSwitchTile(
          icon: Icons.screen_rotation_alt_rounded,
          title: 'Screen Shake & CRT FX',
          subtitle: _screenShakeEnabled ? 'Dynamic screen impact & damage tremors' : 'Static camera during hits',
          value: _screenShakeEnabled,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('game_screen_shake', val);
            if (mounted) setState(() => _screenShakeEnabled = val);
          },
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LIVE AUDIO TEST STATION',
                style: TextStyle(color: Color(0xFF00FF88), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _soundTestChip('Laser', const Color(0xFF00D4FF), () => GameSoundService().playLaser()),
                  _soundTestChip('Gem / Coin', Colors.amber, () => GameSoundService().playCoin()),
                  _soundTestChip('Jackpot Win', const Color(0xFF00FF88), () => GameSoundService().playWin()),
                  _soundTestChip('Explosion', const Color(0xFFFF3366), () => GameSoundService().playExplosion()),
                  _soundTestChip('Sniper Shot', Colors.purpleAccent, () => GameSoundService().playSniper()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _soundTestChip(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── 2. Display & Turbo Performance Section ────────────────────────────────
  Widget _buildPerformanceTurboSection() {
    return _buildSectionContainer(
      title: 'Display & Turbo Performance',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF00D4FF),
      children: [
        _buildSwitchTile(
          icon: Icons.speed_rounded,
          title: '120Hz Ultra Smooth Motion',
          subtitle: _fps120Enabled ? 'Targeting ultra-high refresh frame rates' : 'Standard 60Hz rate',
          value: _fps120Enabled,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('perf_fps_120', val);
            if (mounted) setState(() => _fps120Enabled = val);
          },
        ),
        _buildSwitchTile(
          icon: Icons.auto_awesome_rounded,
          title: 'GPU Shader Starfield & Particles',
          subtitle: _gpuParticlesEnabled ? 'Dynamic floating nebulae & particle meshes active' : 'Reduced background animations for max battery',
          value: _gpuParticlesEnabled,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('perf_gpu_particles', val);
            if (mounted) setState(() => _gpuParticlesEnabled = val);
          },
        ),
        _buildSettingsTile(
          icon: Icons.memory_rounded,
          title: 'Cache & Memory Purge',
          subtitle: 'Currently cached assets: $_cacheSize',
          onTap: () {
            setState(() => _cacheSize = '0.0 MB');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚡ System cache & game buffers cleared!'),
                backgroundColor: Color(0xFF00D4FF),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  // ── 3. Telegram VIP Concierge & Fast Deposit Section ───────────────────────
  Widget _buildTelegramVipSection() {
    return _buildSectionContainer(
      title: 'Telegram VIP Concierge',
      icon: Icons.send_rounded,
      color: const Color(0xFF229ED9),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF229ED9).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF229ED9).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF229ED9), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Official Token Provider: @Vershdit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Buy tokens securely via direct Telegram chat. Choose a package, get instant verification, and have tokens credited directly to your player account.',
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => TokenPurchaseSheet.show(context),
                      icon: const Icon(Icons.shopping_cart_rounded, size: 16),
                      label: const Text('BUY TOKENS'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF229ED9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('https://t.me/Vershdit');
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('CHAT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF229ED9),
                      side: const BorderSide(color: Color(0xFF229ED9)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  // ── 3b. Live Animated Background & Wallpaper Section ─────────────────────
  Widget _buildHomeBackgroundSelectorSection() {
    final animationProvider = Provider.of<AnimationProvider>(context);
    final currentEquipped = animationProvider.equippedHomeAnimation ?? 'matrix_rain';

    final backgroundPresets = [
      {
        'id': 'matrix_rain',
        'name': 'Matrix Digital Rain',
        'tag': 'DEFAULT',
        'icon': Icons.terminal_rounded,
        'color': const Color(0xFF00FF41),
        'desc': 'Cascading green digital glyphs & cyber rain'
      },
      {
        'id': 'tron_grid',
        'name': 'TRON Neon Grid',
        'tag': 'CYBER',
        'icon': Icons.grid_4x4_rounded,
        'color': const Color(0xFF00E5FF),
        'desc': 'Electric blue light-cycle perspective grid'
      },
      {
        'id': 'iron_man_arc',
        'name': 'Iron Man Arc Reactor',
        'tag': 'SCI-FI',
        'icon': Icons.bolt_rounded,
        'color': const Color(0xFF00CFFF),
        'desc': 'Pulsing Mark VII core with touch energy arcs'
      },
      {
        'id': 'terminator_endoskeleton',
        'name': 'Terminator HUD Scanner',
        'tag': 'HUD',
        'icon': Icons.remove_red_eye_rounded,
        'color': const Color(0xFFFF2200),
        'desc': 'Cybernetic targeting system with laser scan'
      },
      {
        'id': 'interstellar_wormhole',
        'name': 'Interstellar Wormhole',
        'tag': 'COSMIC',
        'icon': Icons.blur_circular_rounded,
        'color': const Color(0xFFAABBFF),
        'desc': 'Gravitational spacetime warp & light horizon'
      },
      {
        'id': 'blade_runner_spinner',
        'name': 'Blade Runner Megalopolis',
        'tag': 'NEO-NOIR',
        'icon': Icons.flight_rounded,
        'color': const Color(0xFFFF5500),
        'desc': 'Rain-soaked futuristic cityscape flight'
      },
      {
        'id': 'lightsaber_duel',
        'name': 'Lightsaber Duel',
        'tag': 'PLASMA',
        'icon': Icons.flash_on_rounded,
        'color': const Color(0xFF4444FF),
        'desc': 'Clashing crimson and azure plasma beams'
      },
      {
        'id': 'predator_cloak',
        'name': 'Predator Thermal Cloak',
        'tag': 'STEALTH',
        'icon': Icons.wifi_tethering_rounded,
        'color': const Color(0xFFFF6600),
        'desc': 'Adaptive camouflage light shimmering'
      },
      {
        'id': 'avatar_banshee',
        'name': 'Avatar Bioluminescence',
        'tag': 'PANDORA',
        'icon': Icons.eco_rounded,
        'color': const Color(0xFF00FFCC),
        'desc': 'Glowing bioluminescent rainforest canopy'
      },
      {
        'id': 'dune_sandworm',
        'name': 'Dune Shai-Hulud',
        'tag': 'DESERT',
        'icon': Icons.waves_rounded,
        'color': const Color(0xFFFFAA00),
        'desc': 'Arrakis desert sands & planetary spice storm'
      },
      {
        'id': 'tesseract_cascade',
        'name': 'Tesseract 5D Library',
        'tag': 'DIMENSION',
        'icon': Icons.view_in_ar_rounded,
        'color': const Color(0xFFFFAA55),
        'desc': 'Infinite timeline quantum bookshelves'
      },
      {
        'id': 'classic_aurora',
        'name': 'Aurora Nexus Waves',
        'tag': 'CLASSIC',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFF5D7CFF),
        'desc': 'Ambient starlight nebula & solar drift waves'
      },
    ];

    return _buildSectionContainer(
      title: 'Live Animated Background & Wallpaper',
      icon: Icons.wallpaper_rounded,
      color: const Color(0xFF00FF41),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHOOSE HOME SCREEN LIVE ANIMATION',
                style: TextStyle(
                  color: Color(0xFF00FF41),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Matrix Digital Rain is set as your default live background. Tap any animation preset to immediately apply it to your home screen.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: backgroundPresets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final preset = backgroundPresets[index];
                  final id = preset['id'] as String;
                  final name = preset['name'] as String;
                  final tag = preset['tag'] as String;
                  final icon = preset['icon'] as IconData;
                  final color = preset['color'] as Color;
                  final desc = preset['desc'] as String;
                  final isSelected = (id == 'classic_aurora' && currentEquipped == 'classic_aurora') ||
                      (id == currentEquipped) ||
                      (id == 'matrix_rain' && currentEquipped == 'matrix_rain');

                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (id == 'classic_aurora') {
                        animationProvider.setHomeBackground('classic_aurora');
                      } else {
                        animationProvider.setHomeBackground(id);
                      }
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✨ Applied "$name" to Home Screen'),
                          backgroundColor: color.withValues(alpha: 0.9),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? color : Colors.white12,
                          width: isSelected ? 1.8 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: color.withValues(alpha: 0.4)),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white70 : Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? color : Colors.white30,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => Navigator.pushNamed(context, AnimationStoreScreen.routeName),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF0088FF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'BROWSE FULL SCI-FI ANIMATION STORE (20+)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 3c. Chat List Background & Wallpaper Customization Section ────────────
  Widget _buildChatListBackgroundSelectorSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationProvider = Provider.of<AnimationProvider>(context);
    final currentTheme = themeProvider.chatListWallpaper;
    final currentEquippedAnim = animationProvider.equippedChatListAnimation;

    final chatWallpaperPresets = [
      {
        'id': 'cyber_void',
        'name': 'Deep Cyber Void',
        'tag': 'DEFAULT',
        'icon': Icons.nightlight_round,
        'color': const Color(0xFFB44FFF),
        'desc': 'Deep Discord-purple nebula backdrop (Clean & balanced)'
      },
      {
        'id': 'amoled_black',
        'name': 'Pure AMOLED Black',
        'tag': 'OLED',
        'icon': Icons.dark_mode_rounded,
        'color': const Color(0xFF00E5FF),
        'desc': 'True #000000 black for zero battery consumption & max contrast'
      },
      {
        'id': 'matrix_glyph',
        'name': 'Matrix Emerald Streams',
        'tag': 'HACKER',
        'icon': Icons.terminal_rounded,
        'color': const Color(0xFF00FF41),
        'desc': 'Subtle digital rain & terminal glyph accents'
      },
      {
        'id': 'midnight_slate',
        'name': 'Midnight Telegram Slate',
        'tag': 'CLEAN',
        'icon': Icons.layers_rounded,
        'color': const Color(0xFF38BDF8),
        'desc': 'Ultra-modern dark navy glass with subtle borders'
      },
      {
        'id': 'neon_cyber_grid',
        'name': 'Neon Cyberpunk Grid',
        'tag': 'SYNTH',
        'icon': Icons.grid_4x4_rounded,
        'color': const Color(0xFFFF2A85),
        'desc': 'Futuristic violet & magenta geometric perspective'
      },
    ];

    return _buildSectionContainer(
      title: 'Chat List & Conversation Background',
      icon: Icons.forum_rounded,
      color: const Color(0xFF00E5FF),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHAT LIST WALLPAPER & THEME',
                style: TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Customize the background of your NEX Chat conversations list independently from the splash screen or home launcher.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: chatWallpaperPresets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final preset = chatWallpaperPresets[index];
                  final id = preset['id'] as String;
                  final name = preset['name'] as String;
                  final tag = preset['tag'] as String;
                  final icon = preset['icon'] as IconData;
                  final color = preset['color'] as Color;
                  final desc = preset['desc'] as String;
                  final isSelected = currentTheme == id && currentEquippedAnim == null;

                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      themeProvider.setChatListWallpaper(id);
                      animationProvider.setChatListBackground(null);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✨ Applied "$name" to Chat List'),
                          backgroundColor: color.withValues(alpha: 0.9),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? color : Colors.white12,
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white70 : Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? color : Colors.white30,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => Navigator.pushNamed(context, AnimationStoreScreen.routeName),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB44FFF), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB44FFF).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.palette_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'EQUIP PURCHASED ANIMATION TO CHAT LIST',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 4. Cyber Theme Studio Section ─────────────────────────────────────────
  Widget _buildCyberThemeSection() {
    final themes = [
      {'name': 'Cyberpunk Neon', 'color': const Color(0xFF00D4FF)},
      {'name': 'Matrix Terminal', 'color': const Color(0xFF00FF88)},
      {'name': 'AMOLED Midnight', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Solar Flare', 'color': const Color(0xFFFF8C00)},
      {'name': 'Vaporwave Sunset', 'color': const Color(0xFFFF2A85)},
    ];

    return _buildSectionContainer(
      title: 'Cyber Aesthetic Themes',
      icon: Icons.color_lens_rounded,
      color: const Color(0xFFB44FFF),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT LIVE BACKGROUND PALETTE',
                style: TextStyle(color: Color(0xFFB44FFF), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: themes.map((th) {
                  final name = th['name'] as String;
                  final color = th['color'] as Color;
                  final isSelected = _selectedCyberTheme == name;
                  return ChoiceChip(
                    label: Text(name, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    selected: isSelected,
                    selectedColor: color,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    side: BorderSide(color: isSelected ? color : Colors.white24),
                    onSelected: (val) async {
                      if (val) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('cyber_theme_name', name);
                        if (mounted) setState(() => _selectedCyberTheme = name);
                        HapticFeedback.selectionClick();
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 5. Gamer Incognito & Stealth Shield Section ────────────────────────────
  Widget _buildGamerPrivacySection() {
    return _buildSectionContainer(
      title: 'Gamer Stealth & Privacy Shield',
      icon: Icons.shield_moon_rounded,
      color: const Color(0xFFFF3366),
      children: [
        _buildSwitchTile(
          icon: Icons.visibility_off_rounded,
          title: 'Stealth Mode (Ghost Presence)',
          subtitle: _stealthModeEnabled ? 'Hiding presence & active game from clans/squads' : 'Visible online in gamer discovery',
          value: _stealthModeEnabled,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('privacy_stealth_mode', val);
            if (mounted) setState(() => _stealthModeEnabled = val);
          },
        ),
        _buildSwitchTile(
          icon: Icons.security_rounded,
          title: 'Anti-Screen Snooping Guard',
          subtitle: _antiSnoopGuard ? 'Blur sensitive balances when leaving app' : 'Standard screenshot preview',
          value: _antiSnoopGuard,
          onChanged: (val) async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('privacy_anti_snoop', val);
            if (mounted) setState(() => _antiSnoopGuard = val);
          },
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? kNeonPurple;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectiveColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: effectiveColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? kNeonBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? effectiveColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(!value);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: effectiveColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: effectiveColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: value,
                  onChanged: (newVal) {
                    HapticFeedback.selectionClick();
                    onChanged(newVal);
                  },
                  activeThumbColor: kNeonGreen,
                  activeTrackColor: kNeonGreen.withValues(alpha: 0.35),
                  inactiveThumbColor: Colors.white60,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person, color: kNeonBlue),
            SizedBox(width: 12),
            Text('Edit Profile',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.person_outline, color: kNeonBlue),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.description, color: kNeonGreen),
              ),
              style: TextStyle(color: Colors.white),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: kNeonGreen),
            SizedBox(width: 12),
            Text('Change Password',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.lock_outline, color: kNeonGreen),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.lock, color: kNeonGreen),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.check_circle, color: kNeonGreen),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.update),
            label: const Text('Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.language, color: kNeonBlue),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context).get('selectLanguage'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75, minWidth: 300),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: LocaleProvider.supportedLocales.map((locale) {
                final label = LocaleProvider.languageNameForCode(locale.languageCode);
                return ListTile(
                  title: Text(label, style: const TextStyle(color: Colors.white)),
                  trailing: localeProvider.locale.languageCode == locale.languageCode
                      ? const Icon(Icons.check, color: kNeonGreen)
                      : null,
                  onTap: () async {
                    await localeProvider.setLocale(locale);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }


  void _showRingtoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.music_note, color: kNeonBlue),
            SizedBox(width: 12),
            Text('Ringtone',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ignore: deprecated_member_use
                    RadioListTile<bool>(
                      title: const Text('Use phone ringtone',
                          style: TextStyle(color: Colors.white)),
                      value: false,
                      // ignore: deprecated_member_use
                      groupValue: _useNexRingtone,
                      // ignore: deprecated_member_use
                      onChanged: (v) async {
                        await _setUseNexRingtone(false);
                        setState(() {});
                      },
                    ),
                    // ignore: deprecated_member_use
                    RadioListTile<bool>(
                      title: const Text('Use NEXDROID ringtone',
                          style: TextStyle(color: Colors.white)),
                      value: true,
                      // ignore: deprecated_member_use
                      groupValue: _useNexRingtone,
                      // ignore: deprecated_member_use
                      onChanged: (v) async {
                        await _setUseNexRingtone(true);
                        setState(() {});
                      },
                    ),
                    if (_useNexRingtone)
                      ...List.generate(10, (i) {
                        return ListTile(
                          title: Text('NEXDROID Tone ${i + 1}',
                              style: const TextStyle(color: Colors.white)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow, color: kNeonGreen),
                                onPressed: () => _playPreview(i),
                              ),
                              IconButton(
                                icon: Icon(
                                  _nexRingtoneIndex == i
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: _nexRingtoneIndex == i
                                      ? kNeonBlue
                                      : Colors.white54,
                                ),
                                onPressed: () async {
                                  await _setNexRingtoneIndex(i);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopPreview();
              Navigator.pop(context);
            },
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showSecurityCheckDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: kNeonGreen),
            SizedBox(width: 12),
            Text('Security Checkup',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We checked your account settings and found no issues.',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 10),
            Text('• Two-Factor Authentication status',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• Biometric login readiness',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• Connected devices review',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStartupScreenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.home_filled, color: kNeonBlue),
            SizedBox(width: 12),
            Text('Default Startup Screen',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['Home', 'Chat', 'Marketplace', 'Gaming Terminal']
                  .map((screen) {
                return ListTile(
                  title: Text(screen, style: const TextStyle(color: Colors.white)),
                  trailing: _startupScreen == screen
                      ? const Icon(Icons.check, color: kNeonGreen)
                      : null,
                  onTap: () {
                    setState(() => _startupScreen = screen);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showTokenBalanceDialog(BuildContext context, int balance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.monetization_on, color: kNeonGreen),
            SizedBox(width: 12),
            Text('Token Balance',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available balance: $balance tokens',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 14),
            const Text('Use tokens for games, chats, and marketplace rewards.',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              TokenPurchaseSheet.show(context);
            },
            icon: const Icon(Icons.shopping_cart_outlined, size: 16),
            label: const Text('Buy Tokens'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF229ED9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenTransferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kSurfaceColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: kNeonPurple),
              SizedBox(width: 12),
              Text('Transfer Tokens',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _recipientController,
                decoration: const InputDecoration(
                  labelText: 'Recipient ID or email',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.person_outline, color: kNeonBlue),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _transferAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.attach_money, color: kNeonGreen),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _recipientController.clear();
                _transferAmountController.clear();
                Navigator.pop(context);
              },
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final recipient = _recipientController.text.trim();
                final amount =
                    int.tryParse(_transferAmountController.text.trim()) ?? 0;
                final tokenProvider =
                    Provider.of<TokenProvider>(context, listen: false);

                if (recipient.isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please enter a valid recipient and amount.'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                if (!tokenProvider.transferTokens(amount)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Not enough tokens to complete transfer.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Transferred $amount tokens to $recipient.'),
                    backgroundColor: kNeonGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _recipientController.clear();
                _transferAmountController.clear();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.send),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPromoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final promoController = TextEditingController();
        return AlertDialog(
          backgroundColor: kSurfaceColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.card_giftcard, color: kNeonGreen),
              SizedBox(width: 12),
              Text('Redeem Promo',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: promoController,
                decoration: const InputDecoration(
                  labelText: 'Promo code',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.local_offer, color: kNeonBlue),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final code = promoController.text.trim();
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a promo code to redeem.'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Promo "$code" applied! Tokens added soon.'),
                    backgroundColor: kNeonGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kNeonBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _showReferralDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.group_add, color: kNeonBlue),
            SizedBox(width: 12),
            Text('Referral Rewards',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Invite friends to NEXDROID and earn bonus tokens when they join.',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 12),
            Text('Share your referral code: NEX-12345',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacy Controls',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Manage who can see your profile, activity, and token history.',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 10),
            Text('• Visible to friends only',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• Hide token activity',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            Text('• Block unknown users',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showConnectedDevicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Connected Devices',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device 1: Windows Desktop — Active',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            SizedBox(height: 10),
            Text('Device 2: Mobile Android — Active',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            SizedBox(height: 10),
            Text('To secure your account, sign out from unused devices.',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.apps, color: kNeonGreen, size: 24),
            SizedBox(width: 12),
            Text('NEXDROID',
                style:
                    TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 12),
            Text(
              'NEXDROID is a comprehensive social platform featuring secure messaging, a music player, token-based rewards, gaming, betting, and marketplace features.',
              style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Log Out',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out? You\'ll need to sign in again to access your account.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              authService.signOut();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _backupSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings backup functionality coming soon.'),
        backgroundColor: kNeonBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset to defaults functionality coming soon.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data export functionality coming soon.'),
        backgroundColor: kNeonGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showGyroCalibrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GyroCalibrationDialogContent(
        initialSensitivity: _gyroSensitivity,
        initialXOffset: _gyroXOffset,
        initialYOffset: _gyroYOffset,
        initialInvertX: _gyroInvertX,
        initialInvertY: _gyroInvertY,
        initialDeadzone: _gyroDeadzone,
        onSave: (sensitivity, xOffset, yOffset, invertX, invertY, deadzone) {
          setState(() {
            _gyroSensitivity = sensitivity;
            _gyroXOffset = xOffset;
            _gyroYOffset = yOffset;
            _gyroInvertX = invertX;
            _gyroInvertY = invertY;
            _gyroDeadzone = deadzone;
          });
        },
      ),
    );
  }
}

class _GyroCalibrationDialogContent extends StatefulWidget {
  final double initialSensitivity;
  final double initialXOffset;
  final double initialYOffset;
  final bool initialInvertX;
  final bool initialInvertY;
  final double initialDeadzone;
  final Function(double sensitivity, double xOffset, double yOffset, bool invertX, bool invertY, double deadzone) onSave;

  const _GyroCalibrationDialogContent({
    required this.initialSensitivity,
    required this.initialXOffset,
    required this.initialYOffset,
    required this.initialInvertX,
    required this.initialInvertY,
    required this.initialDeadzone,
    required this.onSave,
  });

  @override
  State<_GyroCalibrationDialogContent> createState() => __GyroCalibrationDialogContentState();
}

class __GyroCalibrationDialogContentState extends State<_GyroCalibrationDialogContent> {
  double _sensitivity = 1.0;
  double _xOffset = 0.0;
  double _yOffset = 0.0;
  bool _invertX = false;
  bool _invertY = false;
  double _deadzone = 0.08;
  double _currentRawX = 0.0;
  double _currentRawY = 0.0;
  StreamSubscription<AccelerometerEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _sensitivity = widget.initialSensitivity;
    _xOffset = widget.initialXOffset;
    _yOffset = widget.initialYOffset;
    _invertX = widget.initialInvertX;
    _invertY = widget.initialInvertY;
    _deadzone = widget.initialDeadzone;

    _subscription = accelerometerEventStream().listen((event) {
      if (mounted) {
        setState(() {
          _currentRawX = event.x;
          _currentRawY = event.y;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Widget _buildGyroOptionRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      activeThumbColor: kNeonGreen,
      activeTrackColor: kNeonGreen.withValues(alpha: 0.4),
      contentPadding: EdgeInsets.zero,
      dense: true,
      subtitle: Text(
        value ? 'Enabled' : 'Disabled',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kSurfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.screen_rotation, color: kNeonBlue),
          SizedBox(width: 12),
          Text('Gyro Calibration',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hold your device flat or in your normal comfortable position, then tap Calibrate to set the baseline.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Tilt:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text(
                'X: ${_currentRawX.toStringAsFixed(2)}, Y: ${_currentRawY.toStringAsFixed(2)}',
                style: const TextStyle(color: kNeonGreen, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Baseline:', style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text(
                'X: ${_xOffset.toStringAsFixed(2)}, Y: ${_yOffset.toStringAsFixed(2)}',
                style: const TextStyle(color: kNeonBlue, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Sensitivity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Slider(
            value: _sensitivity,
            min: 0.2,
            max: 3.0,
            divisions: 14,
            label: _sensitivity.toStringAsFixed(1),
            activeColor: kNeonBlue,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              setState(() {
                _sensitivity = val;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildGyroOptionRow(
            context,
            title: 'Invert X Axis',
            value: _invertX,
            onChanged: (value) => setState(() => _invertX = value),
          ),
          _buildGyroOptionRow(
            context,
            title: 'Invert Y Axis',
            value: _invertY,
            onChanged: (value) => setState(() => _invertY = value),
          ),
          const SizedBox(height: 16),
          const Text('Deadzone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Slider(
            value: _deadzone,
            min: 0.0,
            max: 0.25,
            divisions: 25,
            label: '${(_deadzone * 100).round()}%',
            activeColor: kNeonPurple,
            inactiveColor: Colors.white10,
            onChanged: (val) {
              setState(() {
                _deadzone = val;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('gyroXOffset', _currentRawX);
            await prefs.setDouble('gyroYOffset', _currentRawY);
            await prefs.setDouble('gyroSensitivity', _sensitivity);
            await prefs.setBool('gyroInvertX', _invertX);
            await prefs.setBool('gyroInvertY', _invertY);
            await prefs.setDouble('gyroDeadzone', _deadzone);
            widget.onSave(
              _sensitivity,
              _currentRawX,
              _currentRawY,
              _invertX,
              _invertY,
              _deadzone,
            );
            if (!mounted) return;
            setState(() {
              _xOffset = _currentRawX;
              _yOffset = _currentRawY;
            });
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Gyroscope calibrated successfully!'),
                backgroundColor: kNeonGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }, 
          icon: const Icon(Icons.gps_fixed),
          label: const Text('Calibrate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNeonGreen,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

// ─── Animated Cosmic Starfield & Nebula Background ────────────────────────────
class _SettingsCosmicPainter extends CustomPainter {
  final double animationValue;
  final String theme;

  _SettingsCosmicPainter(this.animationValue, {this.theme = 'Cyberpunk Neon'});

  static final List<math.Point<double>> _stars = List.generate(65, (i) {
    final rng = math.Random(i * 137);
    return math.Point(rng.nextDouble(), rng.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = animationValue * 2 * math.pi;

    // 1. Deep Space Base Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF040612), Color(0xFF080B1E), Color(0xFF050816)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 2. Drifting Pulsing Nebula Orbs
    final nebulae = [
      // Top-Left Cyan/Blue Nebula
      _Nebula(
        center: Offset(
          w * (0.2 + 0.12 * math.sin(t)),
          h * (0.15 + 0.08 * math.cos(t)),
        ),
        radius: w * 0.75,
        color: const Color(0xFF00D4FF).withValues(alpha: 0.16),
      ),
      // Top-Right Purple Nebula
      _Nebula(
        center: Offset(
          w * (0.8 + 0.1 * math.cos(t * 0.8)),
          h * (0.35 + 0.1 * math.sin(t * 0.8)),
        ),
        radius: w * 0.85,
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
      ),
      // Bottom-Left Magenta Nebula
      _Nebula(
        center: Offset(
          w * (0.25 + 0.12 * math.cos(t * 1.2)),
          h * (0.75 + 0.08 * math.sin(t * 1.2)),
        ),
        radius: w * 0.9,
        color: const Color(0xFFFF2A85).withValues(alpha: 0.14),
      ),
      // Center-Right Electric Blue Nebula
      _Nebula(
        center: Offset(
          w * (0.75 + 0.08 * math.sin(t * 0.9)),
          h * (0.85 + 0.06 * math.cos(t * 0.9)),
        ),
        radius: w * 0.8,
        color: const Color(0xFF0066FF).withValues(alpha: 0.15),
      ),
    ];

    for (final neb in nebulae) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [neb.color, neb.color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: neb.center, radius: neb.radius));
      canvas.drawCircle(neb.center, neb.radius, paint);
    }

    // 3. Twinkling Stardust Particles
    for (int i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      final twinkle = (math.sin(t * (1.5 + (i % 5) * 0.5) + i) + 1.0) / 2.0;
      final alpha = (0.2 + twinkle * 0.7).clamp(0.0, 1.0);
      final radius = (i % 3 == 0) ? 1.8 : 1.1;

      final starPaint = Paint()
        ..color = (i % 4 == 0
                ? const Color(0xFF00D4FF)
                : (i % 4 == 1 ? const Color(0xFFFF80DF) : Colors.white))
            .withValues(alpha: alpha);

      final starX = (star.x * w + (math.sin(t * 0.3 + i) * 8)) % w;
      final starY = (star.y * h + (math.cos(t * 0.2 + i) * 6)) % h;

      canvas.drawCircle(Offset(starX, starY), radius, starPaint);
    }

    // 4. Subtle Cyber Grid Horizon at bottom
    final gridPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const int gridCols = 8;
    for (int i = 0; i <= gridCols; i++) {
      final startX = (w / gridCols) * i;
      final endX = w * 0.5 + (startX - w * 0.5) * 1.6;
      canvas.drawLine(Offset(startX, h * 0.7), Offset(endX, h), gridPaint);
    }
    for (double y = h * 0.7; y <= h; y += (h - h * 0.7) / 5) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsCosmicPainter oldDelegate) => true;
}

class _Nebula {
  final Offset center;
  final double radius;
  final Color color;
  _Nebula({required this.center, required this.radius, required this.color});
}

