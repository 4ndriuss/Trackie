import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_button.dart';
import '../widgets/status_dialog.dart';
import 'signup_page.dart';
import 'onboarding_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<String> _resolvePostLoginRoute() async {
    final authProvider = context.read<AuthProvider>();
    final subProvider = context.read<SubscriptionProvider>();
    final uid = authProvider.user?.uid;
    if (uid != null) {
      await subProvider.initializeForUser(uid, forceRefresh: true);
      if (!subProvider.hasSeenSubscriptionPage) {
        return '/subscription-onboarding';
      }
    }
    return '/home';
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      if (!mounted) return;

      if (success) {
        final targetRoute = await _resolvePostLoginRoute();
        if (!mounted) return;
        setState(() => _isLoading = false);

        await showSuccessDialog(
          context,
          title: 'Welcome Back!',
          message: 'You have logged in successfully.',
          buttonText: 'Continue',
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              targetRoute,
              (route) => false,
            );
          },
        );
      } else {
        setState(() => _isLoading = false);
        await showErrorDialog(
          context,
          title: 'Login Failed',
          message: authProvider.error ?? 'Incorrect email or password.',
          buttonText: 'Try Again',
        );
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithGoogle();

    if (!mounted) return;

    if (success) {
      final targetRoute = await _resolvePostLoginRoute();
      if (!mounted) return;
      setState(() => _isLoading = false);

      await showSuccessDialog(
        context,
        title: 'Welcome Back!',
        message: 'You have logged in successfully with Google.',
        buttonText: 'Continue',
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            targetRoute,
            (route) => false,
          );
        },
      );
    } else {
      setState(() => _isLoading = false);
      if (authProvider.error != null) {
        await showErrorDialog(
          context,
          title: 'Google Login Failed',
          message: authProvider.error!,
          buttonText: 'Try Again',
        );
      }
    }
  }

  Future<void> _handleFacebookLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithFacebook();

    if (!mounted) return;

    if (success) {
      final targetRoute = await _resolvePostLoginRoute();
      if (!mounted) return;
      setState(() => _isLoading = false);

      await showSuccessDialog(
        context,
        title: 'Welcome Back!',
        message: 'You have logged in successfully with Facebook.',
        buttonText: 'Continue',
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            targetRoute,
            (route) => false,
          );
        },
      );
    } else {
      setState(() => _isLoading = false);
      if (authProvider.error != null && authProvider.error!.isNotEmpty) {
        await showErrorDialog(
          context,
          title: 'Facebook Login Failed',
          message: authProvider.error!,
          buttonText: 'Try Again',
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email to receive a password reset link.', style: GoogleFonts.urbanist(color: Colors.grey[700])),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'name@example.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.urbanist(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text('Send Link', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    emailController.dispose();

    if (!mounted || email == null || email.isEmpty) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await showSuccessDialog(
        context,
        title: 'Email Sent',
        message: 'A password reset link has been sent to $email.',
        buttonText: 'OK',
        onPressed: () => Navigator.of(context).pop(),
      );
    } else {
      await showErrorDialog(
        context,
        title: 'Reset Failed',
        message: authProvider.error ?? 'Failed to send reset email.',
        buttonText: 'Try Again',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingPage()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // App logo at top left
                      Row(
                        children: [
                          Icon(Icons.track_changes, color: AppTheme.primary, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            'Trackie',
                            style: GoogleFonts.urbanist(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Sign in to your\nAccount',
                        style: GoogleFonts.urbanist(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email and password to log in',
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomTextField(
                        label: 'Email',
                        hint: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        controller: _emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email cannot be empty';
                          if (!value.contains('@')) return 'Invalid email format';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Password',
                        hint: '••••••••',
                        isPassword: true,
                        controller: _passwordController,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password cannot be empty';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot Password ?',
                            style: GoogleFonts.urbanist(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: 'Log In',
                        onPressed: _handleLogin,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Or',
                              style: GoogleFonts.urbanist(
                                color: const Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SocialButton(
                        text: 'Continue with Google',
                        icon: const Icon(Icons.g_mobiledata, color: Colors.blue, size: 28),
                        onPressed: _handleGoogleLogin,
                      ),
                      const SizedBox(height: 16),
                      SocialButton(
                        text: 'Continue with Facebook',
                        icon: const Icon(Icons.facebook, color: Colors.blueAccent, size: 24),
                        onPressed: _handleFacebookLogin,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.urbanist(color: const Color(0xFF6B7280)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.urbanist(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
