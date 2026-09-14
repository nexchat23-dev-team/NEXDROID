import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/token_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/cyber_background.dart';
import '../l10n/app_localizations.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String errorMessage = '';
  bool _isSupabaseReady = true;

  @override
  void initState() {
    super.initState();
    _restoreBiometricPreference();
  }

  Future<void> _restoreBiometricPreference() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final available = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('biometricLogin') ?? true;
      final saved = await authService.getSavedCredentials();

      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = available && (saved != null || authService.user != null || enabled);
      });
    } catch (e) {
      debugPrint('Biometric check note: $e');
    }
  }

  Future<void> _handleBiometricLogin() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);

    try {
      HapticFeedback.mediumImpact();
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock NEXDROID with biometric authentication',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!authenticated) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Biometric authentication cancelled.')),
        );
        return;
      }

      setState(() => isLoading = true);

      // 1. Try saved credentials in secure storage
      final success = await authService.signInWithSavedCredentials();
      if (success && mounted) {
        try {
          await authService.syncFirebaseTokenState(tokenProvider);
        } catch (_) {}
        if (!mounted) return;
        if (!tokenProvider.hasTokens) tokenProvider.setBalance(2000);
        Navigator.pushReplacementNamed(context, HomeScreen.routeName);
        return;
      }

      // 2. Check if Firebase currentUser session already active
      if (authService.user != null && mounted) {
        try {
          await authService.fetchUserProfile();
          await authService.syncFirebaseTokenState(tokenProvider);
        } catch (_) {}
        if (!mounted) return;
        if (!tokenProvider.hasTokens) tokenProvider.setBalance(2000);
        Navigator.pushReplacementNamed(context, HomeScreen.routeName);
        return;
      }

      // 3. If no saved credentials yet, check if fields have text or inform user
      if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
        await _signIn();
        return;
      }

      if (!mounted) return;
      setState(() => isLoading = false);
      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text('Please sign in with email & password once to link biometrics.'),
        duration: Duration(seconds: 4),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Biometric unlock error: $e'),
      ));
    }
  }

  Future<void> _signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'Email and password are required.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);

    try {
      await authService.signIn(email, password);
      if (!mounted) return;

      unawaited(authService.syncFirebaseTokenState(tokenProvider));
      unawaited(authService.syncPendingReferralRewards(tokenProvider));
      if (!tokenProvider.hasTokens) {
        tokenProvider.setBalance(2000);
      }

      if (_biometricAvailable && !_biometricEnabled) {
        try {
          await _confirmEnableBiometrics(email, password);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _isSupabaseReady = true;
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in successfully! Redirecting to home...')),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, HomeScreen.routeName, (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = _friendlyAuthError(error);
        isLoading = false;
      });
    }
  }

  Future<void> _signInWithPhone() async {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      final phone = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: kSurfaceColor,
          title: const Text('Phone sign-in', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '+1 555 123 4567',
              hintStyle: TextStyle(color: Colors.white54),
              labelText: 'Phone number with country code',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, phoneController.text.trim()), child: const Text('SEND CODE')),
          ],
        ),
      );
      if (phone == null || phone.isEmpty || !mounted) return;
      setState(() { isLoading = true; errorMessage = ''; });
      final verificationId = await authService.sendPhoneVerificationCode(phone);
      if (!mounted) return;
      if (verificationId.isEmpty && authService.user != null) {
        setState(() => isLoading = false);
        Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (route) => false);
        return;
      }
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: kSurfaceColor,
          title: const Text('Enter verification code', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'SMS code'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, codeController.text.trim()), child: const Text('VERIFY')),
          ],
        ),
      );
      if (code == null || code.isEmpty || !mounted) return;
      await authService.signInWithPhoneCode(verificationId: verificationId, smsCode: code);
      if (!mounted) return;
      setState(() => isLoading = false);
      Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = _friendlyAuthError(error);
        isLoading = false;
      });
    } finally {
      phoneController.dispose();
      codeController.dispose();
    }
  }

  Future<void> _confirmEnableBiometrics(String email, String password) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enable quick unlock?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
            'Use biometrics to log in faster on this device. Your credentials are stored securely.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (result != true) return;

    await authService.saveCredentials(email, password);
    final saved = await authService.getSavedCredentials();
    if (saved == null) {
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Could not enable biometric login.')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometricLogin', true);
    if (!mounted) return;
    setState(() => _biometricEnabled = true);
    scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Biometric login enabled.')));
  }

  String _friendlyAuthError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('cancel') ||
        message.contains('canceled') ||
        message.contains('cancelled') ||
        message.contains('popup_closed') ||
        message.contains('popup-closed')) {
      return '';
    }
    if (message.contains('apiexception 10') ||
        message.contains('apiexception: 10') ||
        message.contains('sha-1')) {
      return 'Google Sign-In setup note: Please add your SHA-1 fingerprint to the Firebase Console project settings.';
    }
    if (message.contains('account-exists-with-different-credential')) {
      return 'An account already exists with this email address under a different login method.';
    }
    if (message.contains('wrong-password') ||
        message.contains('invalid password') ||
        message.contains('user-not-found') ||
        message.contains('password') ||
        message.contains('email')) {
      return 'Wrong email or password. Please try again.';
    }
    if (message.contains('network_error') ||
        message.contains('network error') ||
        message.contains('network') ||
        message.contains('timeout')) {
      return 'A network issue occurred. Please try again later.';
    }
    final cleanMsg = error.toString().replaceAll('Exception:', '').trim();
    return cleanMsg.isNotEmpty ? cleanMsg : 'Unable to sign in. Please try again.';
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackground(
              backgroundColors: [
                Color(0xFF010308),
                Color(0xFF050816),
                Color(0xFF081122),
                Color(0xFF02040D),
              ],
              leftAuroraColors: [
                Color(0xFF0A84FF),
                Color(0xFF5A50FF),
                Color(0x00000000),
              ],
              rightAuroraColors: [
                Color(0xFF6A3DFF),
                Color(0xFF00C2FF),
                Color(0x00000000),
              ],
              fogColor: Color(0x1AFFFFFF),
              leftAuroraCenter: Alignment(-0.26, -0.28),
              rightAuroraCenter: Alignment(0.82, -0.16),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 28),
                  if (!_isSupabaseReady)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kNeonGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kNeonGreen.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        'Connected to Firebase. Sign in to access your multi-purpose account.',
                        style: TextStyle(color: kNeonGreen, fontSize: 13),
                      ),
                    ),
                  _buildCredentialFields(),
                  const SizedBox(height: 20),
                  if (errorMessage.isNotEmpty) _buildErrorCard(),
                  _buildSignInButton(),
                  const SizedBox(height: 14),
                  _buildOAuthButtons(),
                  if (_biometricAvailable) ...[
                    const SizedBox(height: 18),
                    _buildBiometricPrompt(),
                  ],
                  const SizedBox(height: 28),
                  _buildRegisterLink(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kNeonPurple.withValues(alpha: 0.1),
            kNeonBlue.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: kNeonPurple.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [kNeonPurple, kNeonBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).get('welcomeBack'),
            style: const TextStyle(
              color: kNeonGreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).get('secureAccess'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).get('signInDescription'),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Email',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
              hintText: 'you@example.com',
              icon: Icons.email,
              iconColor: kNeonBlue),
        ),
        const SizedBox(height: 18),
        const Text('Password',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            hintText: 'Enter your password',
            icon: Icons.lock,
            iconColor: kNeonGreen,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.pushNamed(context, '/reset-password'),
            child: Text(AppLocalizations.of(context).get('forgotPassword'),
                style:
                    const TextStyle(color: kNeonBlue, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    required Color iconColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white30),
      prefixIcon: Icon(icon, color: iconColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: kSurfaceColor,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: iconColor, width: 2)),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.26)),
      ),
      child: Text(errorMessage,
          style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
    );
  }

  Widget _buildSignInButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : _signIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: kNeonPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(AppLocalizations.of(context).get('signIn'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOAuthButtons() {
    // All providers in one ordered list: supported first, then coming-soon
    final allProviders = [
      {'label': 'Google',    'color': kNeonBlue,                      'icon': Icons.login,            'supported': true},
      {'label': 'GitHub',    'color': const Color(0xFF6E5494),        'icon': Icons.code,             'supported': true},
      {'label': 'Microsoft', 'color': const Color(0xFF2F96E8),        'icon': Icons.window,           'supported': true},
      {'label': 'Discord',   'color': const Color(0xFF7289DA),        'icon': Icons.headset_mic,      'supported': true},
      {'label': 'Twitter',   'color': const Color(0xFF1DA1F2),        'icon': Icons.travel_explore,   'supported': true},
      {'label': 'Phone',     'color': kNeonGreen,                     'icon': Icons.phone_android_rounded, 'supported': true, 'isPhone': true},
      {'label': 'Instagram', 'color': const Color(0xFFE1306C),        'icon': Icons.camera_alt,       'supported': false},
      {'label': 'Snapchat',  'color': const Color(0xFFE8C800),        'icon': Icons.camera,           'supported': false},
    ];

    // Build pairs for a 2-column grid
    final List<Widget> rows = [];
    for (int i = 0; i < allProviders.length; i += 2) {
      final left  = allProviders[i];
      final right = i + 1 < allProviders.length ? allProviders[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _buildOAuthButton(
              left['label'] as String,
              left['color'] as Color,
              left['icon'] as IconData,
              left['supported'] as bool,
              isPhone: (left['isPhone'] as bool?) ?? false,
            )),
            const SizedBox(width: 10),
            if (right != null)
              Expanded(child: _buildOAuthButton(
                right['label'] as String,
                right['color'] as Color,
                right['icon'] as IconData,
                right['supported'] as bool,
                isPhone: (right['isPhone'] as bool?) ?? false,
              ))
            else
              const Spacer(),
          ],
        ),
      );
      if (i + 2 < allProviders.length) rows.add(const SizedBox(height: 10));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
        ...rows,
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Instagram & Snapchat coming soon',
            style: TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildOAuthButton(
    String label,
    Color color,
    IconData icon,
    bool supported, {
    bool isPhone = false,
  }) {
    return OutlinedButton.icon(
      onPressed: isLoading || !supported
          ? null
          : () async {
              if (isPhone) {
                await _signInWithPhone();
              } else {
                await _handleProviderSignIn(label.toLowerCase());
              }
            },
      icon: Icon(icon, color: supported ? Colors.white : Colors.white38, size: 18),
      label: Text(
        label,
        style: TextStyle(color: supported ? Colors.white : Colors.white38, fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: supported ? color.withValues(alpha: 0.17) : Colors.white.withValues(alpha: 0.05),
        side: BorderSide(
          color: supported ? color.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.1),
          width: 1.4,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  Future<void> _handleProviderSignIn(String provider) async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await authService.signInWithOAuthProvider(provider);
      if (!mounted) return;
      if (!success) {
        // User closed or dismissed the authentication prompt
        setState(() {
          isLoading = false;
        });
        return;
      }
      // Show quick debug feedback indicating who signed in
      final signedInUid = authService.user?.uid;
      if (signedInUid != null) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Signed in: $signedInUid')));
      }
      try {
        await authService.syncPendingReferralRewards(tokenProvider);
      } catch (_) {}
      if (!mounted) return;
      if (!tokenProvider.hasTokens) tokenProvider.setBalance(2000);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in successfully! Redirecting to home...')),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, HomeScreen.routeName, (route) => false);
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyAuthError(error);
      setState(() {
        errorMessage = message;
        isLoading = false;
      });
      if (message.isNotEmpty) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Widget _buildBiometricPrompt() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kNeonPurple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kNeonPurple.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, color: kNeonPurple),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Tap to unlock with biometrics',
                    style: TextStyle(color: Colors.white70)),
              ),
              IconButton(
                onPressed: _handleBiometricLogin,
                icon: const Icon(Icons.arrow_forward_ios, color: kNeonGreen),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Don\'t have an account?',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/mode-selection'),
          child: Text(AppLocalizations.of(context).get('createAccount'),
              style: const TextStyle(color: kNeonGreen, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
