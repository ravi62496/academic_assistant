import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/snackbar_utils.dart';
import '../utils/validators.dart';
import '../widgets/brand_header.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_button.dart';
import 'forgot_password_screen.dart';
import 'main_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Signed in successfully!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOAuthLogin(OAuthProvider provider) async {
    try {
      await _authService.signInWithOAuth(provider);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandHeader(
                      title: 'Welcome Back',
                      subtitle: 'Sign in to access your courses, tasks, and schedule.',
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'student@university.edu',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 18),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      validator: Validators.validatePassword,
                      enabled: !_isLoading,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => const ForgotPasswordScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                );
                              },
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Log In',
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                      icon: Icons.login_rounded,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SocialButton(
                            label: 'Google',
                            icon: Icons.g_mobiledata_rounded,
                            iconColor: Colors.redAccent,
                            onPressed: () => _handleOAuthLogin(OAuthProvider.google),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SocialButton(
                            label: 'Apple',
                            icon: Icons.apple,
                            iconColor: Theme.of(context).colorScheme.onSurface,
                            onPressed: () => _handleOAuthLogin(OAuthProvider.apple),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.of(context).pushReplacement(
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => const SignUpScreen(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        return FadeTransition(opacity: animation, child: child);
                                      },
                                    ),
                                  );
                                },
                          child: const Text('Sign Up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
