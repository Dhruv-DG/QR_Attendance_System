import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bottom.dart';

class CourseApplyScreen extends StatefulWidget {
  const CourseApplyScreen({super.key});

  @override
  State<CourseApplyScreen> createState() => _CourseApplyScreenState();
}

class _CourseApplyScreenState extends State<CourseApplyScreen> {
  String? _selectedCourseId;
  bool _isLoading = false;

  Future<List<Map<String, dynamic>>> _fetchCourses() async {
    final snapshot = await FirebaseFirestore.instance.collection('courses').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<void> _applyForCourse() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course to apply.')),
      );
      return;
    }
    setState(() { _isLoading = true; });
    try {
      // You may want to add lecturer info here
      // For now, just add a request to a collection
      final lecturerId = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('course_applications').add({
        'courseId': _selectedCourseId,
        'lecturerId': lecturerId, // Replace with actual lecturer ID
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied for course successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to apply: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Course')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchCourses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final courses = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a course to apply:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedCourseId,
                  items: courses.map((course) {
                    return DropdownMenuItem<String>(
                      value: course['courseCode'],
                      child: Text('${course['courseCode']} - ${course['courseTitle']}'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCourseId = val),
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applyForCourse,
                          child: const Text('Apply'),
                        ),
                      ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        onTap: (index) {},
      ),
    );
  }
}
