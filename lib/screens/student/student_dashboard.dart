import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_attendance/screens/student/tabs/class_calendar.dart';
import 'package:qr_attendance/screens/student/tabs/navigation.dart';
import 'package:qr_attendance/screens/student/tabs/student_profile.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentDashboard({super.key, required this.userData});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _upcomingClasses = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUpcomingClasses();
  }

  Future<void> _fetchUpcomingClasses() async {
    try {
      // First, get the student's registered courses
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get student's registered courses
      QuerySnapshot registeredCoursesSnapshot = await FirebaseFirestore.instance
          .collection('registrations')
          .where('studentId', isEqualTo: user.uid)
          .get();

      List<String> registeredCourseCodes = registeredCoursesSnapshot.docs
          .map((doc) => doc['courseCode'] as String)
          .toList();

      if (registeredCourseCodes.isEmpty) {
        setState(() {
          _upcomingClasses = [];
          _isLoading = false;
        });
        return;
      }

      // Get all upcoming classes
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('scheduled_classes')
          .where('dateTime', isGreaterThan: Timestamp.now())
          .orderBy('dateTime')
          .get();

      // Filter classes to only include registered courses
      List<Map<String, dynamic>> classes = snapshot.docs
          .where((doc) => registeredCourseCodes.contains(doc['courseCode']))
          .map((doc) {
        return {
          'courseCode': doc['courseCode'],
          'dateTime': (doc['dateTime'] as Timestamp).toDate(),
        };
      }).toList();

      setState(() {
        _upcomingClasses = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load upcoming classes';
        _isLoading = false;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    switch (index) {
      case 0:
        // Already on dashboard
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/courses');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/history');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/qr_scanning');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        title: Text(
          "Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentProfileScreen(userData: widget.userData),
                ),
              );
            },
          ),
          SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Title
            Center(
              child: Text(
                "ClassSync",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ),
            Center(
              child: Text(
                "Your attendance app",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 30),
            // Upcoming Classes Section
            Text(
              "Upcoming Classes",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red, fontSize: 16)))
                : _upcomingClasses.isEmpty
                ? Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 50, color: Colors.grey[400]),
                          SizedBox(height: 10),
                          Text(
                            "No upcoming classes",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 5),
                          Text(
                            "You haven't registered for any courses yet, or there are no scheduled classes for your registered courses.",
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/courses');
                            },
                            icon: Icon(Icons.school),
                            label: Text("Register for Courses"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ClassCalendar(upcomingClasses: _upcomingClasses),
            SizedBox(height: 20),
            // Recent Attendance Card
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}