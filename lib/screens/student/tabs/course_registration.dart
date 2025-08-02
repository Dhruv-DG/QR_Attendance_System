import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_attendance/screens/student/tabs/navigation.dart';

class CourseRegistrationScreen extends StatefulWidget {
  const CourseRegistrationScreen({super.key});

  @override
  _CourseRegistrationScreenState createState() => _CourseRegistrationScreenState();
}

class _CourseRegistrationScreenState extends State<CourseRegistrationScreen> {
  int _currentIndex = 1;
  String? _studentId;
  List<String> _registeredCourses = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentIdAndRegistrations();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/student_dashboard');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/history');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/qr_scanning');
        break;
    }
  }

  Future<void> _fetchStudentIdAndRegistrations() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _studentId = user.uid;
      });

      var registeredDocs = await FirebaseFirestore.instance
          .collection('registrations')
          .where('studentId', isEqualTo: user.uid)
          .get();

      setState(() {
        _registeredCourses =
            registeredDocs.docs.map((doc) => doc['courseCode'] as String).toList();
      });
    }
  }

  void _registerForCourse(String courseCode, String courseTitle) async {
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Student not logged in.")),
      );
      return;
    }

    if (_registeredCourses.contains(courseCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You are already registered for $courseTitle.")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc("$_studentId\_$courseCode")
          .set({
        'studentId': _studentId,
        'courseCode': courseCode,
        'courseTitle': courseTitle,
        'registrationDate': Timestamp.now(),
      });

      setState(() {
        _registeredCourses.add(courseCode);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Successfully registered for $courseTitle!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error registering: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Course Registration",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: const [
          Icon(Icons.bar_chart, color: Colors.black),
          SizedBox(width: 10),
          CircleAvatar(backgroundColor: Colors.grey),
          SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('courses').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No courses available."));
            }

            // Filter only courses with a valid lecturerName field
            var filteredCourses = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data.containsKey('lecturerName') && data['lecturerName'] != null;
            }).toList();

            if (filteredCourses.isEmpty) {
              return const Center(child: Text("No courses with assigned lecturers."));
            }

            return ListView.builder(
              itemCount: filteredCourses.length,
              itemBuilder: (context, index) {
                var course = filteredCourses[index];
                final data = course.data() as Map<String, dynamic>;

                String title = data['courseTitle'] ?? "No Title";
                String code = data['courseCode'] ?? "No Code";
                String lecturerName = data['lecturerName'] ?? "";
                bool isRegistered = _registeredCourses.contains(code);

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  elevation: 5,
                  shadowColor: Colors.grey[300],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              code,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.person, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              lecturerName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Learn more about $title taught by $lecturerName.",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: isRegistered
                                ? null
                                : () => _registerForCourse(code, title),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              isRegistered ? Colors.grey : Colors.blueAccent,
                              foregroundColor:
                              isRegistered ? Colors.black : Colors.white,
                              side: BorderSide(
                                color: isRegistered ? Colors.grey : Colors.blueAccent,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14.0,
                                horizontal: 24.0,
                              ),
                            ),
                            child: Text(
                              isRegistered ? "Registered" : "Register",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
