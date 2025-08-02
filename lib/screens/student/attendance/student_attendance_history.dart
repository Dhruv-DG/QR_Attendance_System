import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_attendance/screens/student/tabs/navigation.dart';

class StudentAttendanceHistoryScreen extends StatefulWidget {
  const StudentAttendanceHistoryScreen({super.key});

  @override
  _StudentAttendanceHistoryScreenState createState() => _StudentAttendanceHistoryScreenState();
}

class _StudentAttendanceHistoryScreenState extends State<StudentAttendanceHistoryScreen> {
  int _currentIndex = 2;
  String? fullName;
  String? registrationNumber;
  String? selectedCourse;
  List<String> registeredCourses = [];
  bool isLoadingCourses = true;
  bool isLoadingAttendance = false;
  List<Map<String, dynamic>> attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // Fetch student details
        final studentDoc = await FirebaseFirestore.instance.collection('students').doc(uid).get();
        if (studentDoc.exists) {
          setState(() {
            fullName = studentDoc['fullName'];
            registrationNumber = studentDoc['registrationNumber'];
          });
        }

        // Fetch registered courses
        final registrationsSnapshot = await FirebaseFirestore.instance
            .collection('registrations')
            .where('studentId', isEqualTo: uid)
            .get();

        List<String> courses = [];
        for (var doc in registrationsSnapshot.docs) {
          courses.add(doc['courseCode'] as String);
        }

        setState(() {
          registeredCourses = courses;
          isLoadingCourses = false;
        });

        // If there are courses, select the first one and load its attendance
        if (courses.isNotEmpty) {
          setState(() {
            selectedCourse = courses.first;
          });
          await _fetchAttendanceForCourse(courses.first);
        }
      } catch (e) {
        setState(() {
          isLoadingCourses = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading student data: $e")),
        );
      }
    }
  }

  Future<void> _fetchAttendanceForCourse(String courseCode) async {
    if (registrationNumber == null) return;

    setState(() {
      isLoadingAttendance = true;
      attendanceRecords.clear();
    });

    try {
      // Get all attendance records for this student (no composite index needed)
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('session_attendance')
          .where('registrationNumber', isEqualTo: registrationNumber)
          .get();

      // Get session details for better information
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('courseCode', isEqualTo: courseCode)
          .get();

      // Create a map of session details
      Map<String, Map<String, dynamic>> sessionDetails = {};
      for (var doc in sessionsSnapshot.docs) {
        sessionDetails[doc.id] = doc.data();
      }

      // Process attendance records and filter by course
      List<Map<String, dynamic>> records = [];
      for (var doc in attendanceSnapshot.docs) {
        var data = doc.data();
        String recordCourseCode = data['courseCode'] ?? '';
        
        // Filter by course code in the app instead of using composite index
        if (recordCourseCode == courseCode) {
          String sessionId = data['sessionId'] ?? '';
          Map<String, dynamic> sessionInfo = sessionDetails[sessionId] ?? {};

          records.add({
            'sessionId': sessionId,
            'sessionTitle': data['sessionTitle'] ?? 'No Title',
            'courseCode': data['courseCode'] ?? courseCode,
            'scannedAt': data['scannedAt'],
            'status': data['status'] ?? 'Present',
            'sessionTime': sessionInfo['time'],
            'sessionDescription': sessionInfo['description'] ?? 'No description',
            'sessionExpiryTime': sessionInfo['expirationTimestamp'],
            'createdAt': sessionInfo['createdAt'],
          });
        }
      }

      // Sort by scannedAt in descending order (most recent first)
      records.sort((a, b) {
        Timestamp? aTime = a['scannedAt'] as Timestamp?;
        Timestamp? bTime = b['scannedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() {
        attendanceRecords = records;
        isLoadingAttendance = false;
      });
    } catch (e) {
      setState(() {
        isLoadingAttendance = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading attendance data: $e")),
      );
    }
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    final date = timestamp.toDate();
    return DateFormat('MMM d, yyyy – hh:mm a').format(date);
  }

  String formatSessionTime(dynamic time) {
    if (time == null) return 'Unknown Time';
    if (time is Timestamp) {
      return DateFormat('MMM d, yyyy – hh:mm a').format(time.toDate());
    }
    return 'Unknown Time';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
        Navigator.pushReplacementNamed(context, '/courses');
        break;
      case 2:
        // Already on history
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
        elevation: 0,
        title: const Text(
          "My Attendance History",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: registrationNumber == null || isLoadingCourses
          ? const Center(child: CircularProgressIndicator())
          : registeredCourses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, size: 80, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        "No courses registered",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "You haven't registered for any courses yet.",
                        style: TextStyle(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/courses'),
                        icon: Icon(Icons.school),
                        label: Text("Register for Courses"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Course Selection Dropdown
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<String>(
                        value: selectedCourse,
                        decoration: InputDecoration(
                          labelText: "Select Course",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        hint: const Text("Choose a course to view attendance"),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedCourse = newValue;
                            attendanceRecords.clear();
                          });
                          if (newValue != null) {
                            _fetchAttendanceForCourse(newValue);
                          }
                        },
                        items: registeredCourses.map<DropdownMenuItem<String>>((String course) {
                          return DropdownMenuItem<String>(
                            value: course,
                            child: Text(course),
                          );
                        }).toList(),
                      ),
                    ),
                    
                    // Attendance Records
                    Expanded(
                      child: selectedCourse == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people, size: 80, color: Colors.grey[400]),
                                  SizedBox(height: 16),
                                  Text(
                                    "Select a course",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Choose a course from the dropdown to view your attendance",
                                    style: TextStyle(color: Colors.grey[500]),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : isLoadingAttendance
                              ? Center(child: CircularProgressIndicator())
                              : attendanceRecords.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                                          SizedBox(height: 16),
                                          Text(
                                            "No attendance records",
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "You haven't attended any sessions for this course yet.",
                                            style: TextStyle(color: Colors.grey[500]),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.all(16),
                                      itemCount: attendanceRecords.length,
                                      itemBuilder: (context, index) {
                                        final record = attendanceRecords[index];
                                        final status = record['status'] as String;
                                        final scannedAt = record['scannedAt'] as Timestamp?;
                                        final sessionTime = record['sessionTime'];
                                        final sessionExpiry = record['sessionExpiryTime'];
                                        
                                        return Card(
                                          margin: EdgeInsets.only(bottom: 12),
                                          elevation: 3,
                                          child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(status).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: _getStatusColor(status)),
                                                      ),
                                                      child: Text(
                                                        status.toUpperCase(),
                                                        style: TextStyle(
                                                          color: _getStatusColor(status),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Spacer(),
                                                    Icon(
                                                      Icons.check_circle,
                                                      color: _getStatusColor(status),
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 12),
                                                Text(
                                                  record['sessionTitle'],
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  "Course: ${record['courseCode']}",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                if (record['sessionDescription'] != null && record['sessionDescription'].isNotEmpty)
                                                  Text(
                                                    "Description: ${record['sessionDescription']}",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                SizedBox(height: 12),
                                                Divider(),
                                                SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            "Session Time",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey[500],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            formatSessionTime(sessionTime),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            "Scanned At",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey[500],
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            formatDate(scannedAt),
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (sessionExpiry != null) ...[
                                                  SizedBox(height: 8),
                                                  Text(
                                                    "Valid Until: ${formatSessionTime(sessionExpiry)}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _onTabTapped(index);
        },
      ),
    );
  }
} 