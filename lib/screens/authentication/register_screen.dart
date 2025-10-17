import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shuttle_tracker/services/APIService.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _hasDisability = false;
  String? _disabilityType; // Hearing, Mobility, Cognitive, Other
  bool _requiresMinibus = false;
  bool _isSubmitting = false;

  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Regex patterns
  final RegExp _studentEmailRegex = RegExp(r'^[0-9]{9}@mycput\.ac\.za$');
  final RegExp _phoneRegex = RegExp(r'^[0-9+\-\s]{7,}$');
  final RegExp _studentIdRegex = RegExp(r'^[0-9]{9}$');

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _studentIdController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateStudentEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your student email';
    if (!_studentEmailRegex.hasMatch(value.trim().toLowerCase())) {
      return 'Email must be 9 digits @mycput.ac.za (e.g., 123456789@mycput.ac.za)';
    }
    return null;
  }

  String? _validateStudentId(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your student number';
    if (!_studentIdRegex.hasMatch(value)) return 'Student number must be 9 digits';
    return null;
  }

  Map<String, String> _splitFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return {'name': parts.first, 'surname': ''};
    }
    return {'name': parts.first, 'surname': parts.sublist(1).join(' ')};
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_agreeToTerms) return;
    setState(() => _isSubmitting = true);
    try {
      final fullName = _fullNameController.text;
      final email = _emailController.text.trim().toLowerCase();
      final studentId = _studentIdController.text.trim();
      final phone = _phoneController.text.trim();
      final nameParts = _splitFullName(fullName);
      final roleString = _hasDisability ? 'DISABLED_STUDENT' : 'STUDENT';

      final payload = {
        'name': nameParts['name'],
        'surname': nameParts['surname'],
        'email': email,
        'password': _passwordController.text,
        'phoneNumber': phone,
        'disability': _hasDisability,
        'role': roleString,
        'studentId': studentId,
        if (_hasDisability) 'disabilityType': _disabilityType ?? 'Other',
        if (_hasDisability) 'requiresMinibus': _requiresMinibus,
      };

      await APIService().registerUser(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful')));
      if (_hasDisability) {
        Navigator.pushReplacementNamed(context, '/student/disabled/dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/student/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _logo(BuildContext context) {
    return CircleAvatar(
      radius: 60,
      // use withAlpha instead of deprecated withOpacity
      backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((0.1 * 255).round()),
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
      // use withAlpha to avoid deprecated withOpacity
      Theme.of(context).colorScheme.primary.withAlpha((0.85 * 255).round()),
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(child: _logo(context)),
              const SizedBox(height: 20),
              Text('Create an Account', style: TextStyle(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Register to access university shuttle services.', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          hintText: 'Enter your full name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Please enter your full name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Enter your student email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: _validateStudentEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _studentIdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter your student number',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: _validateStudentId,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Enter your phone number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your phone number';
                          if (!_phoneRegex.hasMatch(v)) return 'Enter a valid phone number';
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
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter your password'
                            : (v.length < 6 ? 'Password must be at least 6 characters' : null),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_confirmPasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Confirm your password',
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_confirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Do you have a disability?'),
                        value: _hasDisability,
                        onChanged: (v) => setState(() => _hasDisability = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_hasDisability) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _disabilityType,
                          items: const [
                            DropdownMenuItem(value: 'Hearing', child: Text('Hearing')),
                            DropdownMenuItem(value: 'Mobility', child: Text('Mobility')),
                            DropdownMenuItem(value: 'Cognitive', child: Text('Cognitive')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (v) => setState(() => _disabilityType = v),
                          decoration: InputDecoration(
                            hintText: 'Select Disability Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => _hasDisability && (v == null || v.isEmpty) ? 'Please select disability type' : null,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Requires Minibus'),
                          value: _requiresMinibus,
                          onChanged: (v) => setState(() => _requiresMinibus = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Checkbox(
                            value: _agreeToTerms,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (bool? value) {
                              setState(() {
                                _agreeToTerms = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text('By registering, you agree to our Terms and Conditions.', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _gradientButton(label: 'Register', onPressed: _isSubmitting ? null : _submit),
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
                            text: 'Already have an account? ',
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              TextSpan(
                                text: 'Login',
                                style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                                recognizer: TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, '/login'),
                              ),
                            ],
                          ),
                        ),
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

