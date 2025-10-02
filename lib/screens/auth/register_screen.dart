import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../models/disabled_student.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _userType = 'student';
  String? _disabilityType;
  bool _exposureMinibus = false;
  final _accessNeedsController = TextEditingController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Registration'),
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildUserTypeSelector(),
              const SizedBox(height: 20),
              _buildPersonalInfoSection(),
              if (_userType == 'disabled_student') ...[
                const SizedBox(height: 20),
                _buildDisabilityInfoSection(),
              ],
              const SizedBox(height: 20),
              _buildButtonSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'I am a:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Regular Student'),
                value: 'student',
                groupValue: _userType,
                onChanged: (value) {
                  setState(() {
                    _userType = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Disabled Student'),
                value: 'disabled_student',
                groupValue: _userType,
                onChanged: (value) {
                  setState(() {
                    _userType = value!;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDisabilityInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Disability Information',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _disabilityType,
          decoration: const InputDecoration(
            labelText: 'Disability Type',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'physical', child: Text('Physical')),
            DropdownMenuItem(value: 'visual', child: Text('Visual')),
            DropdownMenuItem(value: 'hearing', child: Text('Hearing')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) {
            setState(() {
              _disabilityType = value;
            });
          },
          validator: (value) {
            if (_userType == 'disabled_student' && (value == null || value.isEmpty)) {
              return 'Please select disability type';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        SwitchListTile(
          title: const Text('Require Minibus with Ramp'),
          value: _exposureMinibus,
          onChanged: (value) {
            setState(() {
              _exposureMinibus = value;
            });
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _accessNeedsController,
          decoration: const InputDecoration(
            labelText: 'Special Access Needs',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildButtonSection() {
    return Column(
      children: [
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
          onPressed: _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[900],
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text(
            'Register',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
        const SizedBox(height: 15),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
          child: const Text('Already have an account? Login here'),
        ),
      ],
    );
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final emailExists = await _authService.checkEmailExists(_emailController.text);
      if (emailExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email already exists')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final user = await _authService.registerUser(
        name: _nameController.text,
        surname: _surnameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        userType: _userType,
        disabilityType: _disabilityType,
        // In the registration method, change:
        exposureMinibus: _exposureMinibus, // CHANGE THIS from requiresMinibus // Changed from exposureMinibus to requiresMinibus
        accessNeeds: _accessNeedsController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration failed. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _accessNeedsController.dispose();
    super.dispose();
  }
}