import 'package:flutter/material.dart';

class ReportMaintenanceScreen extends StatefulWidget {
  const ReportMaintenanceScreen({super.key});

  @override
  State<ReportMaintenanceScreen> createState() => _ReportMaintenanceScreenState();
}

class _ReportMaintenanceScreenState extends State<ReportMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void dispose() {
    _issueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // TODO: Implement actual API call
      await Future.delayed(const Duration(seconds: 1)); // Simulate API call
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance report submitted successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Report Maintenance'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final padding = maxWidth < 600 ? 16.0 : 24.0;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Maintenance Issue Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _issueController,
                                decoration: const InputDecoration(
                                  labelText: 'Issue Title',
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter a brief title for the issue',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an issue title';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedPriority,
                                decoration: const InputDecoration(
                                  labelText: 'Priority Level',
                                  border: OutlineInputBorder(),
                                ),
                                items: _priorities.map((String priority) {
                                  return DropdownMenuItem<String>(
                                    value: priority,
                                    child: Text(priority),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() => _selectedPriority = newValue);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                  hintText: 'Provide detailed description of the issue',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a description';
                                  }
                                  if (value.length < 10) {
                                    return 'Description must be at least 10 characters long';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submitReport,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text('Submit Report'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
