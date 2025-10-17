import 'package:flutter/material.dart';

class ManageComplaintsScreen extends StatefulWidget {
  const ManageComplaintsScreen({super.key});

  @override
  State<ManageComplaintsScreen> createState() => _ManageComplaintsScreenState();
}

class _ManageComplaintsScreenState extends State<ManageComplaintsScreen> {
  final List<Map<String, dynamic>> complaints = [
    {
      'id': '1009',
      'user': '230531688@mycput.ac.za',
      'subject': 'Shuttle Delay',
      'status': 'OPEN',
      'createdAt': '2025-10-01',
      'userName': 'Lerato Mokoena',
      'description': 'The shuttle was delayed by 20 minutes at the Bellville stop. This caused me to be late for my exam.',
      'adminNotes': '',
      'responses': <String>[],
    },
    // Add more complaints as needed
  ];

  final List<String> statusOptions = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    String status = complaint['status'];
    String adminNotes = complaint['adminNotes'] ?? '';
    final TextEditingController responseController = TextEditingController();
    final TextEditingController notesController = TextEditingController(text: adminNotes);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Complaint #${complaint['id']}'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('User: ${complaint['userName']}'),
                    Text('Email: ${complaint['user']}'),
                    const SizedBox(height: 12),
                    const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(complaint['description']),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: statusOptions.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => status = val);
                      },
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    const SizedBox(height: 10),
                    const Text('Admin Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Attach admin notes...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setModalState(() => adminNotes = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text('Responses:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...List.generate(
                      complaint['responses'].length,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text('- ${complaint['responses'][i]}', style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: responseController,
                            decoration: const InputDecoration(
                              hintText: 'Add response...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: () {
                            if (responseController.text.trim().isNotEmpty) {
                              setModalState(() {
                                complaint['responses'].add(responseController.text.trim());
                                responseController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      complaint['status'] = status;
                      complaint['adminNotes'] = notesController.text;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Center'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Complaint ID')),
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Subject')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created At')),
              DataColumn(label: Text('Actions')),
            ],
            rows: complaints.map((complaint) {
              return DataRow(cells: [
                DataCell(Text(complaint['id'])),
                DataCell(Text(complaint['user'])),
                DataCell(Text(complaint['subject'])),
                DataCell(Text(complaint['status'])),
                DataCell(Text(complaint['createdAt'])),
                DataCell(Row(
                  children: [
                    TextButton(
                      onPressed: () => _showComplaintDetails(complaint),
                      child: const Text('View'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => complaint['status'] = 'IN_PROGRESS');
                      },
                      child: const Text('Mark In Progress'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => complaint['status'] = 'RESOLVED');
                      },
                      child: const Text('Resolve'),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
