import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentAttendanceDetailScreen extends StatefulWidget {
  final String studentName;
  final String registrationNumber;
  final String courseCode;

  const StudentAttendanceDetailScreen({
    super.key,
    required this.studentName,
    required this.registrationNumber,
    required this.courseCode,
  });

  @override
  _StudentAttendanceDetailScreenState createState() => _StudentAttendanceDetailScreenState();
}

class _StudentAttendanceDetailScreenState extends State<StudentAttendanceDetailScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> allSessions = [];
  Map<String, Map<String, dynamic>> sessionDetails = {};

  @override
  void initState() {
    super.initState();
    _fetchStudentAttendanceData();
  }

  Future<void> _fetchStudentAttendanceData() async {
    setState(() {
      isLoading = true;
      attendanceRecords.clear();
    });

    try {
      // Get all attendance records for this student (no composite index needed)
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('session_attendance')
          .where('registrationNumber', isEqualTo: widget.registrationNumber)
          .get();

      // Get all sessions for this course
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('courseCode', isEqualTo: widget.courseCode)
          .get();

      // Create a map of session details
      for (var doc in sessionsSnapshot.docs) {
        sessionDetails[doc.id] = doc.data();
        allSessions.add({
          'sessionId': doc.id,
          ...doc.data(),
        });
      }

      // Process attendance records and filter by course
      List<Map<String, dynamic>> records = [];
      for (var doc in attendanceSnapshot.docs) {
        var data = doc.data();
        String recordCourseCode = data['courseCode'] ?? '';
        
        // Filter by course code in the app instead of using composite index
        if (recordCourseCode == widget.courseCode) {
          String sessionId = data['sessionId'] ?? '';
          Map<String, dynamic> sessionInfo = sessionDetails[sessionId] ?? {};

          records.add({
            'sessionId': sessionId,
            'sessionTitle': data['sessionTitle'] ?? 'No Title',
            'courseCode': data['courseCode'] ?? widget.courseCode,
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
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        title: Text(
          "${widget.studentName}'s Attendance",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Student Info Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                            child: Icon(Icons.person, color: Colors.blueAccent),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.studentName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Reg: ${widget.registrationNumber}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Course: ${widget.courseCode}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueAccent,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Total Sessions: ${allSessions.length} | Attended: ${attendanceRecords.length}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Attendance Records
                Expanded(
                  child: attendanceRecords.isEmpty
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
                                "${widget.studentName} hasn't attended any sessions for this course yet.",
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
    );
  }
} 