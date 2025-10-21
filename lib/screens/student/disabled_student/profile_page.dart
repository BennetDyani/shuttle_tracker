import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shuttle_tracker/providers/auth_provider.dart';
import '../../../services/APIService.dart';
import '../../../services/logout_helper.dart';
import '../../../widgets/dashboard_action.dart';

class DisabledStudentProfilePage extends StatefulWidget {
  const DisabledStudentProfilePage({super.key});

  @override
  State<DisabledStudentProfilePage> createState() => _DisabledStudentProfilePageState();
}

class _DisabledStudentProfilePageState extends State<DisabledStudentProfilePage> {
  bool _voiceAssistance = false;
  bool _highContrast = false;
  bool _vibrationFeedback = false;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) throw Exception('Not logged in');
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');
      final user = await APIService().fetchUserById(uid);
      setState(() => _user = user);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Accessibility'),
        centerTitle: true,
        actions: const [DashboardAction()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.blue[100],
                                    child: const Icon(Icons.person, size: 40, color: Colors.blueGrey),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_user == null ? '-' : '${_user!['first_name'] ?? ''} ${_user!['last_name'] ?? ''}'.trim(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Student ID: ${_user?['student_id'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(_user?['email'] ?? '-', style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SwitchListTile(
                        value: _voiceAssistance,
                        onChanged: (val) => setState(() => _voiceAssistance = val),
                        title: const Text('Voice Assistance'),
                        secondary: const Icon(Icons.record_voice_over),
                      ),
                      SwitchListTile(
                        value: _highContrast,
                        onChanged: (val) => setState(() => _highContrast = val),
                        title: const Text('High Contrast Mode'),
                        secondary: const Icon(Icons.contrast),
                      ),
                      SwitchListTile(
                        value: _vibrationFeedback,
                        onChanged: (val) => setState(() => _vibrationFeedback = val),
                        title: const Text('Vibration Feedback'),
                        secondary: const Icon(Icons.vibration),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {

                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Personal Info'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Use centralized logout helper to clear app state and navigate to login
                          performGlobalLogout();
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
