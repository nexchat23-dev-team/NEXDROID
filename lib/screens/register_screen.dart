import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/token_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/cyber_background.dart';
import 'home_screen.dart';
import 'mode_selection_screen.dart';

class RegisterScreen extends StatefulWidget {
  static const routeName = '/register';
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  String _selectedMode = 'Normal';
  String _selectedTrack = 'Junior';
  String _selectedLevel = 'Elementary';
  String _selectedTopic = 'General';
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  String errorMessage = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animController;

  String? _detectedCountry;
  String? _detectedIp;

  @override
  void initState() {
    super.initState();
    _detectCountry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        setState(() {
          _selectedMode = args['selectedMode']?.toString() ?? 'Normal';
          _selectedTrack = args['selectedTrack']?.toString() ?? 'Junior';
          _selectedLevel = args['selectedLevel']?.toString() ?? 'Elementary';
          _selectedTopic = args['selectedTopic']?.toString() ?? 'General';
        });
      }
    });
    _animController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _animController.forward();
  }

  Future<void> signUp() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      // Validation logic
      if (usernameController.text.trim().isEmpty) {
        throw Exception('USERNAME_REQUIRED: @Username cannot be empty.');
      }
      if (nameController.text.trim().isEmpty) {
        throw Exception('NAME_REQUIRED: @Name cannot be empty.');
      }
      if (emailController.text.trim().isEmpty) {
        throw Exception('EMAIL_REQUIRED: @Gmail cannot be empty.');
      }
      if (!emailController.text.contains('@') || !emailController.text.contains('.')) {
        throw Exception('INVALID_EMAIL: Please enter a valid email address.');
      }
      if (ageController.text.trim().isEmpty) {
        throw Exception('AGE_REQUIRED: Age is required.');
      }
      final ageValue = int.tryParse(ageController.text.trim());
      if (ageValue == null || ageValue <= 0 || ageValue > 120) {
        throw Exception('INVALID_AGE: Please enter a valid age between 1 and 120.');
      }
      if (passwordController.text.length < 6) {
        throw Exception('PASSWORD_SHORT: Password must be 6+ characters.');
      }
      if (passwordController.text != confirmPasswordController.text) {
        throw Exception('MISMATCH_ERROR: Passwords do not match.');
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final tokenProvider = Provider.of<TokenProvider>(context, listen: false);

      await authService.signUp(
        emailController.text.trim(),
        passwordController.text.trim(),
        usernameController.text.trim(),
        displayName: nameController.text.trim(),
        age: ageValue,
        ipAddress: _detectedIp,
        country: _detectedCountry,
      );
      if (!mounted) return;

      final selectedMode = _selectedMode;
      final selectedTrack = _selectedTrack;
      final selectedLevel = _selectedLevel;
      final selectedTopic = _selectedTopic;
      final detectedIp = _detectedIp;
      final detectedCountry = _detectedCountry;

      setState(() {
        isLoading = false;
      });

      // Account creation is complete. Do not make navigation wait for optional profile sync.
      unawaited(_finishProfileSetup(
        authService,
        tokenProvider,
        age: ageValue,
        mode: selectedMode,
        track: selectedTrack,
        level: selectedLevel,
        topic: selectedTopic,
        ipAddress: detectedIp,
        country: detectedCountry,
      ));

      if (authService.user?.emailVerified == false) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            content: const Text('Please verify your email address.', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.yellowAccent,
            actions: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('DISMISS', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully! Redirecting to home...')),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, HomeScreen.routeName, (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _finishProfileSetup(
    AuthService authService,
    TokenProvider tokenProvider, {
    required int age,
    required String mode,
    required String track,
    required String level,
    required String topic,
    String? ipAddress,
    String? country,
  }) async {
    try {
      await authService.updateProfileData(
        role: mode,
        modeTrack: track,
        modeLevel: level,
        modeTopic: topic,
        age: age,
        ipAddress: ipAddress,
        country: country,
      );
    } catch (e) {
      debugPrint('Profile data update warning: $e');
    }

    try {
      await authService.syncFirebaseTokenState(tokenProvider);
    } catch (e) {
      debugPrint('Token state sync warning: $e');
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    nameController.dispose();
    emailController.dispose();
    ageController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberBackground(
              backgroundColors: [
                Color(0xFF03050A),
                Color(0xFF080A16),
                Color(0xFF0E1120),
                Color(0xFF04060D),
              ],
              leftAuroraColors: [
                Color(0xFF00F0B6),
                Color(0xFF5A50FF),
                Color(0x00000000),
              ],
              rightAuroraColors: [
                Color(0xFFB14BFF),
                Color(0xFF3B82F6),
                Color(0x00000000),
              ],
              fogColor: Color(0x1EFFFFFF),
              leftAuroraCenter: Alignment(-0.22, -0.24),
              rightAuroraCenter: Alignment(0.8, -0.18),
            ),
          ),
          Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0x660D1E36), Color(0x00070B14)],
                center: Alignment.topCenter,
                radius: 1.5,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    if (errorMessage.isNotEmpty) _buildErrorBanner(),
                    _buildModeSummaryCard(),
                    const SizedBox(height: 18),
                    _buildInputLabel('@USERNAME'),
                    _buildStyledField(
                      controller: usernameController,
                      hint: 'letters, numbers, underscore',
                      icon: Icons.person_add_alt_1_rounded,
                      color: kNeonBlue,
                    ),
                    const SizedBox(height: 18),
                    _buildInputLabel('@NAME'),
                    _buildStyledField(
                      controller: nameController,
                      hint: 'your full name',
                      icon: Icons.badge_rounded,
                      color: kNeonBlue,
                    ),
                    const SizedBox(height: 18),
                    _buildInputLabel('@GMAIL'),
                    _buildStyledField(
                      controller: emailController,
                      hint: 'your@email.com',
                      icon: Icons.alternate_email_rounded,
                      color: kNeonBlue,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    _buildInputLabel('AGE'),
                    _buildStyledField(
                      controller: ageController,
                      hint: 'Enter your age',
                      icon: Icons.cake_rounded,
                      color: kNeonPurple,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 18),
                    _buildInputLabel('PASSWORD'),
                    _buildStyledField(
                      controller: passwordController,
                      hint: 'Min 6 characters',
                      icon: Icons.security_rounded,
                      color: kNeonGreen,
                      isPassword: true,
                      obscure: _obscurePassword,
                      toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 18),
                    _buildInputLabel('CONFIRM PASSWORD'),
                    _buildStyledField(
                      controller: confirmPasswordController,
                      hint: 'confirm your password',
                      icon: Icons.check_circle_rounded,
                      color: kNeonGreen,
                      isPassword: true,
                      obscure: _obscureConfirmPassword,
                      toggleObscure: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (!isLoading)
                            BoxShadow(
                              color: kNeonGreen.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kNeonGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'AUTHORIZE_ENTRY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'RECOGNIZED_USER? ',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/login'),
                          child: const Text(
                            'LOG_IN',
                            style: TextStyle(
                              color: kNeonBlue,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Pro UI Component Helpers ---

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROTOCOL: REGISTER',
          style: TextStyle(
              color: kNeonGreen,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2),
        ),
        SizedBox(height: 12),
        Text(
          'Establish New Identity',
          style: TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildModeSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E36).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeonBlue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: kNeonBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected Mode: $_selectedMode', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _selectedMode == 'Developer'
                      ? 'Track: $_selectedTrack • Topic: $_selectedTopic'
                      : _selectedMode == 'Gaming'
                          ? 'Level: $_selectedLevel • Topic: $_selectedTopic'
                          : 'Path: $_selectedMode',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, ModeSelectionScreen.routeName),
            child: const Text('EDIT', style: TextStyle(color: kNeonGreen, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildStyledField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color color,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1E36).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white12),
          prefixIcon: Icon(icon, color: color, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white24,
                      size: 18),
                  onPressed: toggleObscure,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }

  Future<void> _detectCountry() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _detectedIp = body['ip']?.toString();
            _detectedCountry = body['country_name']?.toString() ?? body['country']?.toString();
          });
        }
      }
    } catch (e) {
      debugPrint('IP lookup failed: $e');
    }
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage.toUpperCase(),
              style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
