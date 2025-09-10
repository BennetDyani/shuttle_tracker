// import 'package:flutter/material.dart';
// //import 'package:shuttle_tracker/screens/authentication/admin_login_screen.dart';
//
// class RegisterScreen extends StatefulWidget {
//   const RegisterScreen({super.key});
//
//   @override
//   State<RegisterScreen> createState() => _RegisterScreenState();
// }
//
// enum UserType { student, driver, admin }
//
// class _RegisterScreenState extends State<RegisterScreen> {
//   final _formKey = GlobalKey<FormState>();
//   bool _passwordVisible = false;
//   bool _confirmPasswordVisible = false;
//   bool _agreeToTerms = false;
//   UserType? _selectedUserType; // To store the selected user type
//
//   String _password = '';
//   final TextEditingController _emailController = TextEditingController(); // Controller for email
//
//   // Regex patterns
//   final RegExp _studentEmailRegex = RegExp(r'^[0-9]{9}@mycput\.ac\.za$');
//   final RegExp _driverEmailRegex = RegExp(r'^.+@hgscput\.driver\.co\.za$');
//   final RegExp _adminEmailRegex = RegExp(r'^.+@hgscput\.admin\.co\.za$');
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     super.dispose();
//   }
//
//   String? _validateEmail(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Please enter your email';
//     }
//     if (_selectedUserType == null) {
//       return 'Please select a user type';
//     }
//     switch (_selectedUserType!) {
//       case UserType.student:
//         if (!_studentEmailRegex.hasMatch(value)) {
//           return 'Student email must be studentnumber@mycput.ac.za';
//         }
//         break;
//       case UserType.driver:
//         if (!_driverEmailRegex.hasMatch(value)) {
//           return 'Driver email must be fullname@hgscput.driver.co.za';
//         }
//         break;
//       case UserType.admin:
//         if (!_adminEmailRegex.hasMatch(value)) {
//           return 'Admin email must be adminname@hgscput.admin.co.za';
//         }
//         break;
//     }
//     if (!value.contains('@')) { // Basic check, though regex handles specifics
//         return 'Please enter a valid email';
//     }
//     return null;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: const Text(
//           'Create Account',
//           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: <Widget>[
//                 const SizedBox(height: 20),
//                 const Text(
//                   'Full Name',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   decoration: InputDecoration(
//                     hintText: 'Enter your full name',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.black),
//                     ),
//                   ),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter your full name';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 20),
//                 const Text(
//                   'User Type',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 DropdownButtonFormField<UserType>(
//                   decoration: InputDecoration(
//                     hintText: 'Select user type',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.black),
//                     ),
//                   ),
//                   value: _selectedUserType,
//                   items: UserType.values.map((UserType type) {
//                     return DropdownMenuItem<UserType>(
//                       value: type,
//                       child: Text(type.name[0].toUpperCase() + type.name.substring(1)), // Capitalize first letter
//                     );
//                   }).toList(),
//                   onChanged: (UserType? newValue) {
//                     setState(() {
//                       _selectedUserType = newValue;
//                     });
//                   },
//                   validator: (value) => value == null ? 'Please select a user type' : null,
//                 ),
//                 const SizedBox(height: 20),
//                 const Text(
//                   'Email Address',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: InputDecoration(
//                     hintText: 'Enter your email',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.black),
//                     ),
//                   ),
//                   keyboardType: TextInputType.emailAddress,
//                   validator: _validateEmail,
//                 ),
//                 const SizedBox(height: 20),
//                 const Text(
//                   'Password',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   obscureText: !_passwordVisible,
//                   decoration: InputDecoration(
//                     hintText: 'Enter your password',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.black),
//                     ),
//                     suffixIcon: IconButton(
//                       icon: Icon(
//                         _passwordVisible ? Icons.visibility : Icons.visibility_off,
//                         color: Colors.grey,
//                       ),
//                       onPressed: () {
//                         setState(() {
//                           _passwordVisible = !_passwordVisible;
//                         });
//                       },
//                     ),
//                   ),
//                   onChanged: (value) {
//                     _password = value;
//                   },
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter your password';
//                     }
//                     if (value.length < 6) {
//                       return 'Password must be at least 6 characters';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 20),
//                 const Text(
//                   'Confirm Password',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 TextFormField(
//                   obscureText: !_confirmPasswordVisible,
//                   decoration: InputDecoration(
//                     hintText: 'Confirm your password',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.grey),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                       borderSide: const BorderSide(color: Colors.black),
//                     ),
//                     suffixIcon: IconButton(
//                       icon: Icon(
//                         _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
//                         color: Colors.grey,
//                       ),
//                       onPressed: () {
//                         setState(() {
//                           _confirmPasswordVisible = !_confirmPasswordVisible;
//                         });
//                       },
//                     ),
//                   ),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please confirm your password';
//                     }
//                     if (value != _password) {
//                       return 'Passwords do not match';
//                     }
//                     return null;
//                   },
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: <Widget>[
//                     Checkbox(
//                       value: _agreeToTerms,
//                       onChanged: (bool? value) {
//                         setState(() {
//                           _agreeToTerms = value!;
//                         });
//                       },
//                     ),
//                     Expanded(
//                       child: RichText(
//                         text: TextSpan(
//                           text: 'I agree to the ',
//                           style: DefaultTextStyle.of(context).style.copyWith(color: Colors.black87),
//                           children: <TextSpan>[
//                             TextSpan(
//                               text: 'Terms',
//                               style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
//                               // TODO: Add onTap for Terms
//                             ),
//                             const TextSpan(text: ' & '),
//                             TextSpan(
//                               text: 'Privacy Policy',
//                               style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
//                               // TODO: Add onTap for Privacy Policy
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 if (!_agreeToTerms)
//                   Padding(
//                     padding: const EdgeInsets.only(left: 12.0, top: 5.0), // Added top padding
//                     child: Text(
//                       'You must agree to the terms and privacy policy.',
//                       style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
//                     ),
//                   ),
//                 const SizedBox(height: 30),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.black,
//                     padding: const EdgeInsets.symmetric(vertical: 16.0),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                     ),
//                   ),
//                   onPressed: () {
//                     if (_formKey.currentState!.validate() && _agreeToTerms) {
//                       // TODO: Implement actual user registration logic (e.g., API call)
//                       print('Create Account button tapped');
//                       print('User Type: ${_selectedUserType?.name}');
//                       print('Email: ${_emailController.text}');
//                       // Navigate to Login Screen
//                       Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(builder: (context) => const LoginScreen()),
//                       );
//                     }
//                   },
//                   child: const Text('Create Account', style: TextStyle(fontSize: 16, color: Colors.white)),
//                 ),
//                 const SizedBox(height: 30),
//                 const Row(
//                   children: <Widget>[
//                     Expanded(child: Divider(color: Colors.grey)),
//                     Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 8.0),
//                       child: Text('OR', style: TextStyle(color: Colors.grey)),
//                     ),
//                     Expanded(child: Divider(color: Colors.grey)),
//                   ],
//                 ),
//                 const SizedBox(height: 30),
//                 OutlinedButton.icon(
//                   icon: const Icon(Icons.g_mobiledata, color: Colors.black),
//                   label: const Text('Sign up with Google', style: TextStyle(color: Colors.black)),
//                   style: OutlinedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 12.0),
//                     side: const BorderSide(color: Colors.grey),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                     ),
//                   ),
//                   onPressed: () {
//                     // TODO: Implement Google Sign Up
//                     print('Google Sign Up tapped');
//                   },
//                 ),
//                 const SizedBox(height: 15),
//                 OutlinedButton.icon(
//                   icon: const Icon(Icons.window, color: Colors.black),
//                   label: const Text('Sign up with Microsoft', style: TextStyle(color: Colors.black)),
//                   style: OutlinedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 12.0),
//                     side: const BorderSide(color: Colors.grey),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8.0),
//                     ),
//                   ),
//                   onPressed: () {
//                     // TODO: Implement Microsoft Sign Up
//                     print('Microsoft Sign Up tapped');
//                   },
//                 ),
//                 const SizedBox(height: 40),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: <Widget>[
//                     const Text("Already have an account?", style: TextStyle(color: Colors.grey)),
//                     TextButton(
//                       onPressed: () {
//                         Navigator.pushReplacement(
//                           context,
//                           MaterialPageRoute(builder: (context) => const LoginScreen()),
//                         );
//                       },
//                       child: const Text('Login', style: TextStyle(color: Colors.black)),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }





import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({Key? key}) : super(key: key);

  @override
  _AdminRegisterScreenState createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminCodeController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Admin registration code (should be secure and stored elsewhere in production)
  //final String _validAdminCode = "CPUT_ADMIN_2024";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Registration'),
        backgroundColor: Colors.red[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 100,
                color: Colors.red[800],
              ),
              const SizedBox(height: 20),
              const Text(
                'Administrator Registration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              _buildPersonalInfoSection(),
              const SizedBox(height: 20),
              _buildSecuritySection(),
              const SizedBox(height: 20),
              _buildButtonSection(),
            ],
          ),
        ),
      ),
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
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter first name';
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
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter last name';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        //
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
              return 'Please enter admin email';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
            if (!value.toLowerCase().endsWith('@cput.ac.za')) {
              return 'Admin emails must use @cput.ac.za domain';
            }
            if (!value.toLowerCase().contains('.admin') &&
                !value.toLowerCase().contains('transport') &&
                !value.toLowerCase().contains('shuttle') &&
                !value.toLowerCase().contains('security')) {
              return 'Admin email must contain department or role identifier';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      children: [
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter password';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          obscureText: _obscureConfirmPassword,
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        // const SizedBox(height: 15),
        // TextFormField(
        //   controller: _adminCodeController,
        //   decoration: const InputDecoration(
        //     labelText: 'Admin Registration Code',
        //     border: OutlineInputBorder(),
        //     prefixIcon: Icon(Icons.security),
        //   ),
        //   obscureText: true,
        //   validator: (value) {
        //     if (value == null || value.isEmpty) {
        //       return 'Please enter admin code';
        //     }
        //     if (value != _validAdminCode) {
        //       return 'Invalid admin registration code';
        //     }
        //     return null;
        //   },
        // ),
      ],
    );
  }

  Widget _buildButtonSection() {
    return Column(
      children: [
        _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
          onPressed: _registerAdmin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[800],
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text(
            'Register as Admin',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
        const SizedBox(height: 15),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/admin/login');
          },
          child: const Text('Already have an admin account? Login here'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
          child: const Text('Student Login'),
        ),
      ],
    );
  }

  Future<void> _registerAdmin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Check if email already exists
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

        // Register admin
        final success = await _authService.registerAdmin(
          name: _nameController.text,
          surname: _surnameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );

        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin registration successful!')),
          );
          Navigator.pushReplacementNamed(context, '/admin/login');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin registration failed')),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
    _adminCodeController.dispose();
    super.dispose();
  }
}