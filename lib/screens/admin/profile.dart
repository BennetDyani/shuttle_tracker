import 'package:flutter/material.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({Key? key}) : super(key: key);

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final _formKey = GlobalKey<FormState>();
  String name = 'Admin User';
  String email = 'admin@example.com';
  String phone = '+1234567890';

  // Password fields
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Mock activity log
  final List<String> activityLog = [
    'Logged in',
    'Updated profile',
    'Changed password',
    'Logged out',
    'Added new driver',
    'Removed student',
  ];

  // Settings fields
  bool _notificationsEnabled = false;
  bool _complaintRemindersEnabled = false;
  bool _canManageUsers = false;
  bool _canAssignDrivers = false;
  bool _canViewReports = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updateProfile() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
      setState(() {
        activityLog.insert(0, 'Updated profile');
      });
    }
  }

  void _changePassword() {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields.')),
      );
      return;
    }
    // Mock password change
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed!')),
    );
    setState(() {
      activityLog.insert(0, 'Changed password');
    });
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/admin/dashboard');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Personal Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        onSaved: (val) => name = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Enter name' : null,
                      ),
                      TextFormField(
                        initialValue: email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        onSaved: (val) => email = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Enter email' : null,
                      ),
                      TextFormField(
                        initialValue: phone,
                        decoration: const InputDecoration(labelText: 'Phone Number'),
                        onSaved: (val) => phone = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Enter phone number' : null,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          child: const Text('Update Info'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Current Password'),
                    ),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password'),
                    ),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm New Password'),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _changePassword,
                        child: const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Settings Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // Feature Toggles
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      value: _notificationsEnabled,
                      onChanged: (val) => setState(() => _notificationsEnabled = val),
                    ),
                    SwitchListTile(
                      title: const Text('Enable Complaint Auto-Reminders'),
                      value: _complaintRemindersEnabled,
                      onChanged: (val) => setState(() => _complaintRemindersEnabled = val),
                    ),
                    const Divider(),
                    // Role Permissions
                    const Text('Role Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('Can Manage Users'),
                      value: _canManageUsers,
                      onChanged: (val) => setState(() => _canManageUsers = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Can Assign Drivers'),
                      value: _canAssignDrivers,
                      onChanged: (val) => setState(() => _canAssignDrivers = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text('Can View Reports'),
                      value: _canViewReports,
                      onChanged: (val) => setState(() => _canViewReports = val ?? false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Activity Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 400,
                          child: activityLog.isEmpty
                              ? const Text('No activity yet.')
                              : ListView.separated(
                                  itemCount: activityLog.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    return ListTile(
                                      leading: const Icon(Icons.history),
                                      title: Text(activityLog[index]),
                                    );
                                  },
                                ),
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
    );
  }
}
