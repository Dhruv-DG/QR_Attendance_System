import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_attendance/screens/common/splash_screen.dart';
import 'package:qr_attendance/screens/lecturer/tabs/lecturer_dashboard.dart';
import 'package:qr_attendance/screens/student/student_dashboard.dart';
import 'package:qr_attendance/screens/student/tabs/course_registration.dart';
import 'package:qr_attendance/screens/student/attendance/student_attendance_history.dart';
import 'package:qr_attendance/screens/student/attendance/qr_scanning.dart';
import 'package:qr_attendance/screens/lecturer/tabs/monitoring.dart';
import 'package:qr_attendance/screens/lecturer/attendance/qr_generation.dart';
import 'package:qr_attendance/screens/admin/tabs/course_management_screen.dart';
import 'package:qr_attendance/screens/common/role_based.dart';
import 'package:qr_attendance/screens/student/tabs/student_profile.dart';
import 'package:qr_attendance/screens/admin/auth/admin_login_screen.dart';
import 'package:qr_attendance/screens/lecturer/tabs/course_apply_screen.dart';
import 'package:qr_attendance/screens/student/student_dashboard.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      // Add these by creating web app in the firebase
      // options: FirebaseOptions(
      //     apiKey:
      //     authDomain:
      //     projectId:
      //     storageBucket:
      //     messagingSenderId:
      //     appId:
      //     measurementId:
      // ),
    );
  } else {
    // Add google-services.json in the specified directory by creating android app in firebase
    await Firebase.initializeApp();
  }
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClassSync',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/splash',
      
      // Define static routes
      routes: {
        '/splash': (context) => SplashScreen(),
        '/role': (context) => RoleSelectionScreen(),
        //lecturer's route
        '/lecturer_dashboard': (context) => LecturerDashboard(),
        '/monitoring': (context) => AttendanceMonitoringScreen(),
        '/qr_generation': (context) => QRCodeGenerationScreen(),
        '/course': (context) => CourseManagementScreen(),
        '/course_apply': (context) => CourseApplyScreen(),
        //student's route
        '/courses': (context) => CourseRegistrationScreen(),
        '/history': (context) => StudentAttendanceHistoryScreen(),
        '/qr_scanning': (context) => QRScannerScreen(),
        // admin route
        '/admin_login': (context) =>
            // ignore: prefer_const_constructors
            AdminLoginScreen(),
      },
      
      // Handle dynamic routes (e.g., passing user data)
      onGenerateRoute: (settings) {
        if (settings.name == '/student_dashboard') {
          final userData = settings.arguments as Map<String, dynamic>?; 
          return MaterialPageRoute(
            builder: (context) => StudentDashboard(userData: userData ?? {}),
          );
        }

        if (settings.name == '/profile') {
          final userData = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => StudentProfileScreen(userData: userData ?? {}),
          );
        }

        return null; // Default case
      },
    );
  }
}
