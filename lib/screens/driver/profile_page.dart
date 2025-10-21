import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import '../../models/driver_model/Driver.dart';
import '../../providers/auth_provider.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  Map<String, dynamic>? driverRow;
  Map<String, dynamic>? userRow;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDriverProfile();
  }

  Future<void> _fetchDriverProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) throw Exception('Not logged in');
      final uid = int.tryParse(uidStr);
      if (uid == null) throw Exception('Invalid user id');

      // Fetch the user row (includes email)
      final fetchedUser = await APIService().fetchUserById(uid);

      // Use user's email to fetch driver row (driver table links to user by user_id)
      final email = fetchedUser['email'] as String?;
      Map<String, dynamic>? fetchedDriver;
      if (email != null && email.isNotEmpty) {
        try {
          fetchedDriver = await APIService().fetchDriverByEmail(email);
        } catch (_) {
          // driver row might not exist; ignore and continue
          fetchedDriver = null;
        }
      }

      setState(() {
        userRow = fetchedUser;
        driverRow = fetchedDriver;
      });
    } catch (e) {
      setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Update: accept a JSON-like payload constructed by the edit dialog
  Future<void> _updateDriverProfile(Map<String, dynamic> payload) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      // Determine driver id from fetched driverRow
      final id = driverRow?['driver_id'] ?? driverRow?['driverId'];
      if (id == null) {
        // No driver exists yet -> create a new driver row
        // Build a create payload expected by backend. Try to include user identification where possible.
        // Normalize keys: backend may accept 'userId' or nested 'user' object. Keep original payload shape but remove null driverId.
        final createPayload = Map<String, dynamic>.from(payload);
        createPayload.remove('driverId');
        await APIService().post(Endpoints.driverCreate, createPayload);
      } else {
        final driverId = int.tryParse(id.toString()) ?? id;
        await APIService().put('drivers/update/$driverId', payload);
      }
      await _fetchDriverProfile();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userRow == null ? '-' : '${userRow!['first_name'] ?? ''} ${userRow!['last_name'] ?? ''}'.trim();
    final driverLicense = driverRow?['license_number'] ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
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
                                      Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Email: ${userRow?['email'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      Text('Driver License: $driverLicense', style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Pre-fill values for dialog
                          final name = userRow?['first_name'] ?? '';
                          final license = driverRow?['license_number'] ?? '';
                          final updatedData = await _showEditDialog(context, name, license, userRow);
                          if (updatedData != null) {
                            await _updateDriverProfile(updatedData);
                          }
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Info'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<Map<String, dynamic>?> _showEditDialog(BuildContext context, String currentName, String currentLicense, Map<String, dynamic>? user) async {
    final nameController = TextEditingController(text: currentName);
    final licenseController = TextEditingController(text: currentLicense);

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: licenseController, decoration: const InputDecoration(labelText: 'Driver License')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              // Build a minimal payload the backend expects. Include userId so server can identify the user.
              final payload = {
                'driverId': driverRow?['driver_id'] ?? driverRow?['driverId'],
                'driverLicense': licenseController.text,
                'user': {
                  'userId': user?['user_id'] ?? user?['userId'],
                  'name': nameController.text,
                },
              };
              Navigator.of(context).pop(payload);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
