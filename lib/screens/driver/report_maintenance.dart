import 'package:flutter/material.dart';
import '../../services/APIService.dart';
import '../../services/endpoints.dart';

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

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final report = {
        'type': _selectedType,
        'description': _descriptionController.text,
        'photoPath': _photoPath,
        // Add driverId, shuttleId, etc. as needed
      };
      try {
        await APIService().post(Endpoints.maintenanceReportCreate, report);
        _descriptionController.clear();
        setState(() {
          _selectedType = _types[0];
          _photoPath = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report successfully submitted.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ' + e.toString())),
        );
      }
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
                decoration: const InputDecoration(
                  labelText: 'Select Issue Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
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
                    onPressed: _addPhoto,
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
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
