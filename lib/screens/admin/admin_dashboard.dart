import 'package:flutter/material.dart';
import 'tabs/lecturer_list.dart';
import 'tabs/course_management_screen.dart';
import 'tabs/admin_profile.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget bodyWidget;
    switch (_selectedIndex) {
      case 0:
        bodyWidget = const ApplicationsTab();
        break;
      case 1:
        bodyWidget = const ApprovedLecturersList();
        break;
      case 2:
        bodyWidget = CourseManagementScreen();
        break;
      case 3:
        bodyWidget = const AdminProfilePage();
        break;
      default:
        bodyWidget = const ApplicationsTab();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        iconTheme: IconThemeData(color: Colors.black38),
        ),
      body: bodyWidget,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.hourglass_top),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'Approved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Courses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),

        ],
      ),
    );
  }
}