import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shuttle_tracker/providers/auth_provider.dart';
import 'package:shuttle_tracker/services/logger.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staffIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _passwordVisible = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _staffIdController.dispose();
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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final staffId = _staffIdController.text.trim();
      AppLogger.info('Attempting staff login', data: {'staffId': staffId});
      final role = await context.read<AuthProvider>().loginStaff(
            staffId: staffId,
            password: _passwordController.text,
          );

      if (!mounted) return;
      if (role == 'ADMIN') {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else if (role == 'DRIVER') {
        Navigator.pushReplacementNamed(context, '/driver/dashboard');
      } else {
        throw Exception('Unsupported role: $role');
      }
    } catch (e, st) {
      AppLogger.exception('Staff login failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        title: Text('Staff Login', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: _logo(context)),
              const SizedBox(height: 20),
              Text('Welcome Staff', style: TextStyle(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Login using your Staff ID and password.', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _staffIdController,
                        decoration: InputDecoration(
                          hintText: 'Staff ID',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter your staff ID' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
                      ),
                      const SizedBox(height: 20),
                      _gradientButton(label: 'Login', onPressed: _isSubmitting ? null : _handleLogin),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pushNamed(context, '/register/admin'),
                        child: Text('New admin? Register here', style: TextStyle(color: theme.colorScheme.primary)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
