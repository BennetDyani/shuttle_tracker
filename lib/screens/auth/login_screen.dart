import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../models/disabled_student.dart';
import '../../screens/student/student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Login'),
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset(
                'assets/images/cput_logo.png',
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.directions_bus,
                    size: 100,
                    color: Colors.blue[900],
                  );
                },
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register');
                },
                child: const Text('Don\'t have an account? Register here'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/admin/login');
                },
                child: const Text('Admin Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = await _authService.loginUser(
          _emailController.text,
          _passwordController.text,
        );

        setState(() {
          _isLoading = false;
        });

        if (user != null) {
          print('Login successful. User type: ${user.userType}');

          if (user.userType == 'disabled_student') {
            print('🟢 User is disabled student, fetching details...');
            final disabledStudent = await _authService.getDisabledStudentDetails(user.userId);
            print('🟢 Disabled student details: ${disabledStudent != null ? "FOUND" : "NOT FOUND"}');

            if (disabledStudent != null) {
              print('🟢 Navigating with user: ${user.name}, disabled: ${disabledStudent.disabilityType}');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentDashboard(
                    user: user,
                    disabledStudent: disabledStudent,
                  ),
                ),
              );
            } else {
              print('🟡 No disabled details, using regular dashboard');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentDashboard(user: user),
                ),
              );
            }
          } else if (user.userType == 'student') {
            print('🟢 Regular student, navigating to dashboard');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDashboard(user: user),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please use student login')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid email or password')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        print('Login error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}