import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../bottom.dart';
import 'student_attendance_detail.dart'; // Added import for StudentAttendanceDetailScreen

class AttendanceMonitoringScreen extends StatefulWidget {
  const AttendanceMonitoringScreen({super.key});

  @override
  _AttendanceMonitoringScreenState createState() => _AttendanceMonitoringScreenState();
}

class _AttendanceMonitoringScreenState extends State<AttendanceMonitoringScreen> {
  int _currentIndex = 2;
  List<String> lecturerCourses = [];
  String? selectedCourse;
  bool isLoading = true;
  bool loadingStudentData = false;
  List<Map<String, dynamic>> studentAttendanceData = [];

  @override
  void initState() {
    super.initState();
    _fetchLecturerCourses();
  }

  Future<void> _fetchLecturerCourses() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final lecturerDoc = await FirebaseFirestore.instance
          .collection('lecturers')
          .doc(currentUserId)
          .get();

      if (lecturerDoc.exists) {
        final data = lecturerDoc.data();
        if (data != null && data.containsKey('courses')) {
          setState(() {
            lecturerCourses = List<String>.from(data['courses']);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    final date = timestamp.toDate();
    return DateFormat('MMM d, yyyy – hh:mm a').format(date);
  }

  Future<void> _fetchStudentAttendanceData(String courseCode) async {
    setState(() {
      loadingStudentData = true;
      studentAttendanceData.clear();
    });

    try {
      // Get all students registered for this course
      var registrationsSnapshot = await FirebaseFirestore.instance
          .collection('registrations')
          .where('courseCode', isEqualTo: courseCode)
          .get();

      // Get all sessions for this course
      var sessionsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('courseCode', isEqualTo: courseCode)
          .get();

      int totalSessions = sessionsSnapshot.docs.length;

      // Get all attendance records for this course
      var attendanceSnapshot = await FirebaseFirestore.instance
          .collection('session_attendance')
          .where('courseCode', isEqualTo: courseCode)
          .get();

      print('Debug: Total sessions for course $courseCode: $totalSessions');
      print('Debug: Total attendance records found: ${attendanceSnapshot.docs.length}');

      // Create a map of attendance records by student registration number
      Map<String, List<Map<String, dynamic>>> attendanceByStudent = {};
      
      for (var doc in attendanceSnapshot.docs) {
        var data = doc.data();
        String regNumber = data['registrationNumber'] ?? '';
        String sessionId = data['sessionId'] ?? '';
        
        print('Debug: Processing attendance record - Reg: $regNumber, Session: $sessionId');
        
        if (regNumber.isNotEmpty) {
          if (!attendanceByStudent.containsKey(regNumber)) {
            attendanceByStudent[regNumber] = [];
          }
          attendanceByStudent[regNumber]!.add(data);
        }
      }

      print('Debug: Attendance grouped by student:');
      attendanceByStudent.forEach((regNumber, records) {
        print('  $regNumber: ${records.length} attendance records');
      });

      // Process each registered student
      for (var regDoc in registrationsSnapshot.docs) {
        var regData = regDoc.data();
        String studentId = regData['studentId'] ?? '';
        String registrationNumber = '';
        String studentName = 'Unknown';

        // Get student details from students collection using studentId
        if (studentId.isNotEmpty) {
          var studentDoc = await FirebaseFirestore.instance
              .collection('students')
              .doc(studentId)
              .get();

          if (studentDoc.exists) {
            var studentData = studentDoc.data();
            studentName = studentData?['fullName'] ?? 'Unknown';
            registrationNumber = studentData?['registrationNumber'] ?? '';
          }
        }

        // Calculate attendance for this student using registration number
        List<Map<String, dynamic>> studentAttendanceRecords = attendanceByStudent[registrationNumber] ?? [];
        int attendedSessions = studentAttendanceRecords.length;
        
        // Get unique session IDs to ensure we're not counting duplicates
        Set<String> uniqueSessions = studentAttendanceRecords
            .map((record) => record['sessionId'] as String)
            .where((sessionId) => sessionId.isNotEmpty)
            .toSet();
        
        int uniqueAttendedSessions = uniqueSessions.length;
        
        double attendancePercentage = totalSessions > 0 
            ? (uniqueAttendedSessions / totalSessions) * 100 
            : 0.0;

        print('Debug: Student $studentName ($registrationNumber) - Total records: $attendedSessions, Unique sessions: $uniqueAttendedSessions, Percentage: ${attendancePercentage.toStringAsFixed(1)}%');

        studentAttendanceData.add({
          'studentId': studentId,
          'studentName': studentName,
          'registrationNumber': registrationNumber,
          'totalSessions': totalSessions,
          'attendedSessions': uniqueAttendedSessions, // Use unique sessions count
          'attendancePercentage': attendancePercentage,
          'totalRecords': attendedSessions, // Keep track of total records for debugging
        });
      }

      // Sort by attendance percentage (descending)
      studentAttendanceData.sort((a, b) => 
          (b['attendancePercentage'] as double).compareTo(a['attendancePercentage'] as double));

      setState(() {
        loadingStudentData = false;
      });
    } catch (e) {
      setState(() {
        loadingStudentData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading student data: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        title: const Text(
          "Student Attendance History",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (selectedCourse != null) ...[
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _fetchStudentAttendanceData(selectedCourse!),
              tooltip: "Refresh Data",
            ),
            IconButton(
              icon: Icon(Icons.bug_report, color: Colors.white),
              onPressed: () => _debugAttendanceRecords(selectedCourse!),
              tooltip: "Debug Records",
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : lecturerCourses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, size: 80, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        "No courses assigned",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "You need to be assigned courses by admin to view attendance.",
                        style: TextStyle(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<String>(
                        value: selectedCourse,
                        decoration: InputDecoration(
                          labelText: "Select Course",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school),
                        ),
                        hint: const Text("Choose a course to view student attendance"),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedCourse = newValue;
                            studentAttendanceData.clear();
                          });
                          if (newValue != null) {
                            _fetchStudentAttendanceData(newValue);
                          }
                        },
                        items: lecturerCourses.map<DropdownMenuItem<String>>((String course) {
                          return DropdownMenuItem<String>(
                            value: course,
                            child: Text(course),
                          );
                        }).toList(),
                      ),
                    ),
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
                                    "Choose a course from the dropdown to view student attendance",
                                    style: TextStyle(color: Colors.grey[500]),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : loadingStudentData
                              ? Center(child: CircularProgressIndicator())
                              : studentAttendanceData.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                                          SizedBox(height: 16),
                                          Text(
                                            "No students enrolled",
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "No students are currently registered for this course.",
                                            style: TextStyle(color: Colors.grey[500]),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.all(16),
                                      itemCount: studentAttendanceData.length,
                                      itemBuilder: (context, index) {
                                        final studentData = studentAttendanceData[index];
                                        final attendancePercentage = studentData['attendancePercentage'] as double;
                                        
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => StudentAttendanceDetailScreen(
                                                  studentName: studentData['studentName'],
                                                  registrationNumber: studentData['registrationNumber'],
                                                  courseCode: selectedCourse!,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Card(
                                            margin: EdgeInsets.only(bottom: 12),
                                            elevation: 3,
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        backgroundColor: _getPercentageColor(attendancePercentage).withValues(alpha: 0.2),
                                                        child: Icon(
                                                          Icons.person,
                                                          color: _getPercentageColor(attendancePercentage),
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              studentData['studentName'],
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                            Text(
                                                              "Reg: ${studentData['registrationNumber']}",
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: Colors.grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          Text(
                                                            "${attendancePercentage.toStringAsFixed(1)}%",
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                              color: _getPercentageColor(attendancePercentage),
                                                            ),
                                                          ),
                                                          Text(
                                                            "${studentData['attendedSessions']}/${studentData['totalSessions']}",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 12),
                                                  LinearProgressIndicator(
                                                    value: attendancePercentage / 100,
                                                    minHeight: 8,
                                                    backgroundColor: Colors.grey[300],
                                                    color: _getPercentageColor(attendancePercentage),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        "Sessions attended",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                      Text(
                                                        "${studentData['attendedSessions']} out of ${studentData['totalSessions']} sessions",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  // Debug information (can be removed in production)
                                                  if (studentData.containsKey('totalRecords') && studentData['totalRecords'] != studentData['attendedSessions'])
                                                    Container(
                                                      margin: EdgeInsets.only(top: 8),
                                                      padding: EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.info, size: 16, color: Colors.orange),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              "Debug: ${studentData['totalRecords']} total records, ${studentData['attendedSessions']} unique sessions",
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors.orange[700],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
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
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  // Debug function to check attendance records
  Future<void> _debugAttendanceRecords(String courseCode) async {
    try {
      var attendanceSnapshot = await FirebaseFirestore.instance
          .collection('session_attendance')
          .where('courseCode', isEqualTo: courseCode)
          .get();

      print('=== DEBUG ATTENDANCE RECORDS ===');
      print('Course: $courseCode');
      print('Total records: ${attendanceSnapshot.docs.length}');
      
      Map<String, List<String>> sessionsByStudent = {};
      
      for (var doc in attendanceSnapshot.docs) {
        var data = doc.data();
        String regNumber = data['registrationNumber'] ?? '';
        String sessionId = data['sessionId'] ?? '';
        
        if (!sessionsByStudent.containsKey(regNumber)) {
          sessionsByStudent[regNumber] = [];
        }
        sessionsByStudent[regNumber]!.add(sessionId);
      }
      
      sessionsByStudent.forEach((regNumber, sessions) {
        print('Student $regNumber: ${sessions.length} sessions');
        print('  Sessions: ${sessions.join(', ')}');
      });
      
      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }
}
