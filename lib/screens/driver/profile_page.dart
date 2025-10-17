import 'package:flutter/material.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import '../../models/driver_model/Driver.dart';
import '../../models/User.dart' as app_user;

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  Driver? driver;
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
      // Replace with actual driver ID or email as needed
      final fetchedDriver = await APIService().get(Endpoints.driverReadById(1));
      setState(() {
        driver = Driver.fromJson(fetchedDriver);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _updateDriverProfile(Driver updatedDriver) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      await APIService().put(Endpoints.driverUpdate, updatedDriver.toJson());
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
                                      Text(driver?.user.name ?? '-', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Driver License: ${driver?.driverLicense ?? '-'}', style: const TextStyle(color: Colors.grey)),
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
                          if (driver != null) {
                            final updatedDriver = await _showEditDialog(context, driver!);
                            if (updatedDriver != null) {
                              await _updateDriverProfile(updatedDriver);
                            }
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

  Future<Driver?> _showEditDialog(BuildContext context, Driver driver) async {
    final nameController = TextEditingController(text: driver.user.name);
    final licenseController = TextEditingController(text: driver.driverLicense);

    return showDialog<Driver>(
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
              final existingUser = driver.user;
              final updatedUser = app_user.User(
                userId: existingUser.userId,
                name: nameController.text,
                surname: existingUser.surname,
                email: existingUser.email,
                password: existingUser.password,
                phoneNumber: existingUser.phoneNumber,
                disability: existingUser.disability,
                role: existingUser.role,
                complaints: existingUser.complaints,
                feedbacks: existingUser.feedbacks,
                notifications: existingUser.notifications,
              );

              final updated = Driver(
                driverId: driver.driverId,
                user: updatedUser,
                driverLicense: licenseController.text,
              );
              Navigator.of(context).pop(updated);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
