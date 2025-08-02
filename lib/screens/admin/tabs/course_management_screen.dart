import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseManagementScreen extends StatelessWidget {
  CourseManagementScreen({Key? key}) : super(key: key);

  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();

  void _showAddCourseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _courseNameController,
                decoration: const InputDecoration(labelText: 'Course Name'),
              ),
              TextField(
                controller: _courseCodeController,
                decoration: const InputDecoration(labelText: 'Course Code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _courseNameController.clear();
                _courseCodeController.clear();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _courseNameController.text.trim();
                final code = _courseCodeController.text.trim();
                if (name.isNotEmpty && code.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('courses').doc(
                      code).set({
                    'courseTitle': name,
                    'courseCode': code,
                  });
                  Navigator.of(context).pop();
                  _courseNameController.clear();
                  _courseCodeController.clear();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCourseDialog(BuildContext context, String docId,
      String currentName, String currentCode) {
    _courseNameController.text = currentName;
    _courseCodeController.text = currentCode;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _courseNameController,
                decoration: const InputDecoration(labelText: 'Course Name'),
              ),
              TextField(
                controller: _courseCodeController,
                decoration: const InputDecoration(labelText: 'Course Code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _courseNameController.clear();
                _courseCodeController.clear();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _courseNameController.text.trim();
                final code = _courseCodeController.text.trim();
                if (name.isNotEmpty && code.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('courses').doc(
                      docId).update({
                    'courseTitle': name,
                    'courseCode': code,
                  });
                  Navigator.of(context).pop();
                  _courseNameController.clear();
                  _courseCodeController.clear();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCourse(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('courses').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Course deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Course Management',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Course'),
              onPressed: () => _showAddCourseDialog(context),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('courses')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No courses found.'));
                  }
                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final courseTitle = data['courseTitle'] ?? '';
                      final courseCode = data['courseCode'] ?? '';
                      final lecturerName = data['lecturerName'] ?? 'No Lecturer Assigned';
                      final hasLecturer = data['lecturerId'] != null && data['lecturerId'].toString().isNotEmpty;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(courseTitle),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Code: $courseCode'),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 16,
                                    color: hasLecturer ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    lecturerName,
                                    style: TextStyle(
                                      color: hasLecturer ? Colors.green : Colors.orange,
                                      fontWeight: hasLecturer ? FontWeight.normal : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _showEditCourseDialog(
                                      context,
                                      doc.id,
                                      data['courseTitle'] ?? '',
                                      data['courseCode'] ?? '',
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCourse(context, doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}