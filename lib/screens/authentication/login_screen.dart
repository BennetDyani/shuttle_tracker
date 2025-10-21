import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shuttle_tracker/providers/auth_provider.dart';
import 'package:shuttle_tracker/services/logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _isSubmitting = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Fallback patterns (used only if backend doesn't return role)
  final RegExp _studentEmailRegex = RegExp(r'^[0-9]{9}@mycput\.ac\.za$');
  final RegExp _driverEmailRegex = RegExp(r'^.+@hgscput\.driver\.co\.za$');
  final RegExp _adminEmailRegex = RegExp(r'^.+@hgscput\.admin\.co\.za$');

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    // Decide fallback role before hitting backend
    String? fallbackRole;
    if (_adminEmailRegex.hasMatch(email)) {
      fallbackRole = 'ADMIN';
    } else if (_driverEmailRegex.hasMatch(email)) {
      fallbackRole = 'DRIVER';
    } else if (_studentEmailRegex.hasMatch(email)) {
      fallbackRole = 'STUDENT';
    }

    setState(() => _isSubmitting = true);
    try {
      AppLogger.info('Attempting student login', data: {'email': email});
      final role = await context.read<AuthProvider>().loginWithEmail(
            email,
            password,
            fallbackRole: fallbackRole,
          );
      if (!mounted) return;
      // Navigate based on normalized role
      if (role == 'ADMIN') {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else if (role == 'DRIVER') {
        Navigator.pushReplacementNamed(context, '/driver/dashboard');
      } else if (role == 'DISABLED_STUDENT') {
        Navigator.pushReplacementNamed(context, '/student/disabled/dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/student/dashboard');
      }
    } catch (e, st) {
      AppLogger.exception('Login failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _logo(BuildContext context) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Text(
        'CPUT',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }

  Widget _gradientButton({required String label, required VoidCallback? onPressed}) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
    ];
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        gradient: LinearGradient(colors: colors),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: _isSubmitting
            ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
            : Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: _logo(context)),
              const SizedBox(height: 20),
              Text('Welcome Back', style: TextStyle(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Login to continue using the CPUT Shuttle Service.', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your student email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!value.contains('@')) return 'Please enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Implement Forgot Password
                          },
                          child: Text('Forgot Password?', style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _gradientButton(label: 'Login', onPressed: _isSubmitting ? null : _handleLogin),
                      const SizedBox(height: 20),
                      Row(
                        children: const [
                          Expanded(child: Divider(color: Colors.grey)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('OR', style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Divider(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: "Don't have an account? ",
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              TextSpan(
                                text: 'Sign Up',
                                style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    // Navigate to registration screen so students can sign up
                                    Navigator.pushNamed(context, '/register');
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/login/staff'),
                          child: Text('Staff Login', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text('Powered by CPUT ICT Services', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
