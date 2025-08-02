import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  String? selectedCourse;
  List<String> lecturerCourses = [];
  List<Map<String, dynamic>> courseReports = [];
  bool isLoading = true;
  bool loadingReports = false;

  @override
  void initState() {
    super.initState();
    _fetchLecturerCourses();
  }

  Future<void> _fetchLecturerCourses() async {
    try {
      final currentLecturerId = FirebaseAuth.instance.currentUser?.uid;
      if (currentLecturerId == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final lecturerDoc = await FirebaseFirestore.instance
          .collection('lecturers')
          .doc(currentLecturerId)
          .get();

      if (lecturerDoc.exists) {
        final data = lecturerDoc.data();
        if (data != null && data.containsKey('courses')) {
          setState(() {
            lecturerCourses = List<String>.from(data['courses']);
            isLoading = false;
          });
        } else {
          setState(() {
            lecturerCourses = [];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          lecturerCourses = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        lecturerCourses = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading courses: $e")),
      );
    }
  }

  Future<void> _generateCourseReports() async {
    setState(() {
      loadingReports = true;
      courseReports.clear();
    });

    try {
      for (String courseCode in lecturerCourses) {
        // Get total sessions for this course
        var sessionsSnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .where('courseCode', isEqualTo: courseCode)
            .get();
        
        int totalSessions = sessionsSnapshot.docs.length;

        // Get total registered students for this course
        var registrationsSnapshot = await FirebaseFirestore.instance
            .collection('registrations')
            .where('courseCode', isEqualTo: courseCode)
            .get();
        
        int totalRegisteredStudents = registrationsSnapshot.docs.length;

        // Get total attendance records for this course
        var attendanceSnapshot = await FirebaseFirestore.instance
            .collection('session_attendance')
            .where('courseCode', isEqualTo: courseCode)
            .get();
        
        int totalAttendanceRecords = attendanceSnapshot.docs.length;

        // Calculate expected total attendance (students × sessions)
        int expectedTotalAttendance = totalRegisteredStudents * totalSessions;

        // Calculate attendance percentage
        double attendancePercentage = expectedTotalAttendance > 0
            ? (totalAttendanceRecords / expectedTotalAttendance) * 100
            : 0.0;

        // Get course title
        var courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(courseCode)
            .get();
        
        String courseTitle = courseDoc.exists 
            ? (courseDoc.data()?['courseTitle'] ?? courseCode)
            : courseCode;

        courseReports.add({
          'courseCode': courseCode,
          'courseTitle': courseTitle,
          'totalSessions': totalSessions,
          'totalRegisteredStudents': totalRegisteredStudents,
          'totalAttendanceRecords': totalAttendanceRecords,
          'expectedTotalAttendance': expectedTotalAttendance,
          'attendancePercentage': attendancePercentage,
        });
      }

      setState(() {
        loadingReports = false;
      });
    } catch (e) {
      setState(() {
        loadingReports = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating reports: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Course Attendance Reports"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _generateCourseReports,
            tooltip: "Refresh Reports",
          ),
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
                        "You need to be assigned courses by admin to view reports.",
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
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: loadingReports ? null : _generateCourseReports,
                              icon: loadingReports 
                                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(Icons.analytics),
                              label: Text(loadingReports ? "Generating..." : "Generate Reports"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: courseReports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bar_chart, size: 80, color: Colors.grey[400]),
                                  SizedBox(height: 16),
                                  Text(
                                    "No reports generated yet",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Click 'Generate Reports' to view attendance statistics",
                                    style: TextStyle(color: Colors.grey[500]),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: courseReports.length,
                              itemBuilder: (context, index) {
                                final report = courseReports[index];
                                final attendancePercentage = report['attendancePercentage'] as double;
                                
                                return Card(
                                  margin: EdgeInsets.only(bottom: 16),
                                  elevation: 4,
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.school, color: Colors.blueAccent, size: 24),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    report['courseTitle'],
                                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    report['courseCode'],
                                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildStatCard(
                                                "Sessions",
                                                "${report['totalSessions']}",
                                                Icons.event,
                                                Colors.blue,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: _buildStatCard(
                                                "Students",
                                                "${report['totalRegisteredStudents']}",
                                                Icons.people,
                                                Colors.green,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: _buildStatCard(
                                                "Attendance",
                                                "${report['totalAttendanceRecords']}",
                                                Icons.check_circle,
                                                Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          "Attendance Percentage",
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: attendancePercentage / 100,
                                          minHeight: 12,
                                          backgroundColor: Colors.grey[300],
                                          color: _getPercentageColor(attendancePercentage),
                                        ),
                                        SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                              "${report['totalAttendanceRecords']} / ${report['expectedTotalAttendance']}",
                                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}
