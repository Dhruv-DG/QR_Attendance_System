import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseApplicationsList extends StatelessWidget {
  const CourseApplicationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Text(
            'Pending Course Applications',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('course_applications')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No pending applications.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final app = docs[index];
                  final lecturerId = app['lecturerId'];
                  final courseId = app['courseCode'] ?? '';
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('lecturers').doc(lecturerId).get(),
                    builder: (context, lecturerSnapshot) {
                      String lecturerName = 'Unknown';
                      if (lecturerSnapshot.hasData && lecturerSnapshot.data!.exists) {
                        lecturerName = lecturerSnapshot.data!['fullName'] ?? 'Unknown';
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          title: Text('Course ID: $courseId'),
                          subtitle: Text('Lecturer: $lecturerName'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('course_applications')
                                      .doc(app.id)
                                      .update({'status': 'approved'});
                                                                
                                  await FirebaseFirestore.instance
                                      .collection('courses')
                                      .doc(courseId)
                                      .update({'lecturerName': lecturerName});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('course_applications')
                                      .doc(app.id)
                                      .update({'status': 'rejected'});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}