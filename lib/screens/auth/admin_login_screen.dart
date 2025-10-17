import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  _AdminLoginScreenState createState() => _AdminLoginScreenState();
}


class _AdminLoginScreenState extends State<AdminLoginScreen> {
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
        title: const Text('Admin Login'),
        backgroundColor: Colors.green[400], // Different color for admin
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 120,
                color: Colors.green[400],
              ),
              const SizedBox(height: 30),
              const Text(
                'Administrator Access',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Admin Email',
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
                      _obscurePassword ? Icons.visibility : Icons
                          .visibility_off,
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
                  backgroundColor: Colors.green[400],
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Admin Login',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/register');
                },
                child: const Text('Not registered yet? Register Admin here'),
              ),



              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text('Student Login'),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/register');
                },
                child: const Text('Need admin access? Register here'),
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

      final user = await _authService.loginUser(
        _emailController.text,
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (user != null) {
        if (user.userType == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access denied. Admin privileges required.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
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