import 'package:flutter/material.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/shuttle_service.dart';
import '../../models/shuttle_model.dart';
import '../../models/driver_model/Driver.dart';

class ReportMaintenanceScreen extends StatefulWidget {
  const ReportMaintenanceScreen({super.key});

  @override
  State<ReportMaintenanceScreen> createState() => _ReportMaintenanceScreenState();
}

class _ReportMaintenanceScreenState extends State<ReportMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Mechanical';
  final TextEditingController _descriptionController = TextEditingController();
  // Placeholder for photo (in real app, use File or XFile)
  String? _photoPath;

  final List<String> _types = [
    'Mechanical',
    'Route',
    'Passenger',
    'Other',
  ];

  // Loading/submitting state and context
  bool _isLoadingInitial = true;
  bool _isSubmitting = false;
  int? _driverId;
  int? _shuttleId;
  final ShuttleService _shuttleService = ShuttleService();
  List<Shuttle> _shuttles = [];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    setState(() {
      _isLoadingInitial = true;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uidStr = auth.userId;
      if (uidStr == null || uidStr.isEmpty) return;
      final uid = int.tryParse(uidStr);
      if (uid == null) return;

      // Fetch user to get email and then fetch driver row
      final user = await APIService().fetchUserById(uid);
      final email = (user['email'] ?? '') as String;
      if (email.isEmpty) return;

      try {
        final fetchedDriver = await APIService().fetchDriverByEmail(email);
        final driver = Driver.fromJson(fetchedDriver);
        _driverId = driver.driverId;

        // Try to find an active assignment for this driver and extract shuttle id if available
        try {
          final assignments = await _shuttleService.getDriverAssignments();
          for (final Map<String, dynamic> a in assignments) {
            final aid = (a['driverId'] ?? a['driver_id'] ?? a['driver'])?.toString() ?? '';
            if (aid.isEmpty) continue;
            if (int.tryParse(aid) == _driverId || aid == _driverId.toString()) {
              final rawSid = a['shuttleId'] ?? a['shuttle_id'] ?? a['shuttle'];
              if (rawSid is int) _shuttleId = rawSid;
              else if (rawSid is String) _shuttleId = int.tryParse(rawSid);
              break;
            }
          }
          // Also fetch all shuttles to let the user pick one if no active assignment
          try {
            final fetchedShuttles = await _shuttleService.getShuttles();
            _shuttles = fetchedShuttles;
            // If we didn't find a shuttle assignment but the list contains the shuttle id as string, attempt to match
            if (_shuttleId == null && _shuttles.isNotEmpty) {
              // no-op; user can choose from dropdown
            }
          } catch (_) {
            // ignore shuttle fetch errors
          }
        } catch (_) {
          // ignore shuttle/assignment errors - not critical
        }
      } catch (_) {
        // driver row might not exist; that's OK — report can still be submitted
      }
    } catch (_) {
      // ignore initial load errors; we still allow report submission
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    // If backend requires shuttleId and we don't have one, prompt the user to confirm/choose
    if (_shuttleId == null) {
      // Ask user if they want to submit without shuttle id
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Shuttle Assigned'),
          content: const Text('No shuttle assignment was found for your account. The backend may require a shuttleId. Do you want to submit the report without shuttle info?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Submit Anyway')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    setState(() => _isSubmitting = true);
    try {
      // include report date (date-only) and multiple key variants for backend compatibility
      final reportDate = DateTime.now().toIso8601String().split('T').first;
      final report = <String, dynamic>{
        'type': _selectedType,
        'description': _descriptionController.text,
        'reportDate': reportDate,
        'report_date': reportDate,
        if (_photoPath != null) 'photoPath': _photoPath,
        if (_driverId != null) 'driverId': _driverId,
        if (_driverId != null) 'driver_id': _driverId,
        if (_shuttleId != null) 'shuttleId': _shuttleId,
        if (_shuttleId != null) 'shuttle_id': _shuttleId,
      };

      // Log payload for debugging (keeps parity with AppLogger.debug in APIService)
      // (We won't import the logger; leaving as a code comment for traceability)

      await APIService().post(Endpoints.maintenanceReportCreate, report);
      _descriptionController.clear();
      setState(() {
        _selectedType = _types[0];
        _photoPath = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report successfully submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting report: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addPhoto() async {
    // In a real app, use image_picker or similar
    setState(() {
      _photoPath = 'mock_photo.jpg';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        centerTitle: true,
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: _types
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: _isSubmitting ? null : (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Select Issue Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Shuttle selection (if available)
                    if (_shuttles.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: _shuttleId,
                        items: _shuttles.map((s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text('${s.licensePlate.isNotEmpty ? s.licensePlate : 'Shuttle ${s.id}'} - ${s.make} ${s.model}'),
                            )).toList(),
                        onChanged: _isSubmitting ? null : (val) {
                          setState(() => _shuttleId = val);
                        },
                        decoration: const InputDecoration(
                          labelText: 'Assigned Shuttle',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (_shuttles.isNotEmpty && (v == null)) return 'Please select a shuttle';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 6,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a description' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _addPhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Add Photo'),
                        ),
                        const SizedBox(width: 12),
                        if (_photoPath != null)
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 4),
                              Text('Photo added', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        const Spacer(),
                        if (_driverId != null)
                          Text('Driver ID: $_driverId', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
