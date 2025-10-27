import 'package:flutter/material.dart';
import '../../../widgets/dashboard_action.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Accessibility';
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUrgent = false;
  bool _isDirty = false; // tracks unsaved changes

  final List<String> _types = [
    'Accessibility',
    'Delay',
    'Safety',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  void _onDescriptionChanged() {
    if (!_isDirty && _descriptionController.text.isNotEmpty) {
      setState(() => _isDirty = true);
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Here you would send the issue to your backend or database
      _descriptionController.clear();
      setState(() {
        _selectedType = _types[0];
        _isUrgent = false;
        _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue reported successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Report an Issue'),
        centerTitle: true,
        actions: [
          DashboardAction(hasUnsavedChanges: () async => _isDirty),
        ],
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
                  if (val != null) setState(() { _selectedType = val; _isDirty = true; });
                },
                decoration: const InputDecoration(
                  labelText: 'Type of issue',
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
                onChanged: (_) { if (!_isDirty) setState(() => _isDirty = true); },
                validator: (value) => value == null || value.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _isUrgent,
                onChanged: (val) => setState(() { _isUrgent = val ?? false; _isDirty = true; }),
                title: const Text('Urgent – Requires immediate attention'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
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
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
