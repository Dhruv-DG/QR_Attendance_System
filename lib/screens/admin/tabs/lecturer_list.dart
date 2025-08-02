import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: 'Lecturers'),
            Tab(text: 'Courses'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              PendingLecturersList(),
              CourseApplicationsList(),
            ],
          ),
        ),
      ],
    );
  }
}

class PendingLecturersList extends StatelessWidget {
  const PendingLecturersList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
    const Padding(
    padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    child: Text(
    'Pending Lecturer Applications',
    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    ),
    ),
    Expanded(
    child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lecturers')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No pending lecturers.'));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final lecturer = docs[index];
            final fullName = lecturer['fullName'] ?? 'No Name';
            final email = lecturer['email'] ?? '';
            final staffId = lecturer['staffId'] ?? '';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(fullName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: $email'),
                    Text('Staff ID: $staffId'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('lecturers')
                            .doc(lecturer.id)
                            .update({'status': 'approved'});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('lecturers')
                            .doc(lecturer.id)
                            .delete();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    )
    )
    ]
    );
  }
}

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
                  final courseId = app['courseId'] ?? '';
                  // Properly handle lecturerId which might be null or different data types
                  dynamic lecturerIdData = app['lecturerId'];
                  String lecturerId = "";
                  if (lecturerIdData != null) {
                    lecturerId = lecturerIdData.toString();
                  }
                  
                  return FutureBuilder<DocumentSnapshot?>(
                    future: lecturerId.isNotEmpty 
                        ? FirebaseFirestore.instance.collection('lecturers').doc(lecturerId).get()
                        : Future.value(null),
                    builder: (context, lecturerSnapshot) {
                      String lecturerName = 'Unknown';
                      if (lecturerSnapshot.hasData && lecturerSnapshot.data != null && lecturerSnapshot.data!.exists) {
                        lecturerName = lecturerSnapshot.data!['fullName'] ?? 'Unknown';
                      } else if (lecturerId.isEmpty) {
                        lecturerName = 'No Lecturer ID';
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          title: Text('Course: $courseId'),
                          subtitle: Text('Lecturer: $lecturerName'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: lecturerId.isNotEmpty ? () async {
                                  try {
                                    // Update the course application status
                                    await FirebaseFirestore.instance
                                        .collection('course_applications')
                                        .doc(app.id)
                                        .update({'status': 'approved'});

                                    // Add the course to the lecturer's approved courses
                                    await FirebaseFirestore.instance
                                        .collection('lecturers')
                                        .doc(lecturerId)
                                        .update({
                                      'courses': FieldValue.arrayUnion([courseId])
                                    });

                                    // Update the course document with lecturer information
                                    await FirebaseFirestore.instance
                                        .collection('courses')
                                        .doc(courseId)
                                        .update({
                                      'lecturerId': lecturerId,
                                      'lecturerName': lecturerName,
                                      'assignedAt': FieldValue.serverTimestamp(),
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Course $courseId assigned to $lecturerName')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error approving application: $e')),
                                    );
                                  }
                                } : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('course_applications')
                                        .doc(app.id)
                                        .update({'status': 'rejected'});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Application rejected for $courseId')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error rejecting application: $e')),
                                    );
                                  }
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

class ApprovedLecturersList extends StatelessWidget {
  const ApprovedLecturersList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Text(
            'Approved Lecturers',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('lecturers')
                .where('status', isEqualTo: 'approved')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No approved lecturers.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final lecturer = docs[index];
                  final fullName = lecturer['fullName'] ?? 'No Name';
                  final email = lecturer['email'] ?? '';
                  final staffId = lecturer['staffId'] ?? '';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      title: Text(fullName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email: $email'),
                          Text('Staff ID: $staffId'),
                        ],
                      ),
                    ),
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