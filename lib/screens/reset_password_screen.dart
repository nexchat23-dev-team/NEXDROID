import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/cyber_background.dart';

class ResetPasswordScreen extends StatefulWidget {
  static const routeName = '/reset-password';
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';
  String successMessage = '';

  Future<void> resetPassword() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your email address';
        isLoading = false;
      });
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.resetPassword(email);
      setState(() {
        successMessage = 'Password reset link sent. Check your email.';
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBackground,
      appBar: AppBar(
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF050816),
        elevation: 0,
        iconTheme: const IconThemeData(color: kNeonBlue),
      ),
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
                Color(0xFF00B8F4),
                Color(0xFF4C6FFF),
                Color(0x00000000),
              ],
              rightAuroraColors: [
                Color(0xFF00F0B6),
                Color(0xFF2563EB),
                Color(0x00000000),
              ],
              fogColor: Color(0x21FFFFFF),
              leftAuroraCenter: Alignment(-0.23, -0.26),
              rightAuroraCenter: Alignment(0.79, -0.17),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kNeonBlue.withValues(alpha: 0.2),
                          kNeonPurple.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kNeonBlue.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: kNeonBlue.withValues(alpha: 0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Forgot Your Password?', style: TextStyle(color: kNeonBlue, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('No worries', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Firebase will send a secure reset link to your email so you can recover your account quickly.', style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Email Address', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'your@email.com',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.email, color: kNeonBlue),
                      filled: true,
                      fillColor: kSurfaceColor.withValues(alpha: 0.8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kNeonBlue, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 2)),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13))),
                        ],
                      ),
                    ),
                  if (successMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: kNeonGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kNeonGreen.withValues(alpha: 0.3), width: 2)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: kNeonGreen, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(successMessage, style: const TextStyle(color: kNeonGreen, fontSize: 13))),
                        ],
                      ),
                    ),
                  if (errorMessage.isNotEmpty || successMessage.isNotEmpty) const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : resetPassword,
                    icon: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.mail),
                    label: Text(isLoading ? 'Sending Link...' : 'Send Reset Link'),
                    style: ElevatedButton.styleFrom(backgroundColor: kNeonBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 4),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Login'),
                    style: OutlinedButton.styleFrom(foregroundColor: kNeonGreen, side: const BorderSide(color: kNeonGreen, width: 2), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Icon(Icons.info, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Tip:', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))]),
                        SizedBox(height: 8),
                        Text('Check your spam folder if you do not see the email. The reset link will expire in 1 hour.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
