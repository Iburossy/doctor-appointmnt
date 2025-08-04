import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'doctor_profile_tab.dart';
import 'doctor_dashboard_tabs.dart';
import 'doctor_appointments_tab.dart';
import 'doctor_patients_tab.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DoctorHomeTab(),
    const DoctorAppointmentsTab(),
    const DoctorPatientsTab(),
    const DoctorProfileTab(),
  ];

  final List<String> _pageTitles = [
    'Tableau de bord',
    'Mes rendez-vous',
    'Mes patients',
    'Mon profil',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pageTitles[_selectedIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 32, 160, 200),
        actions: _selectedIndex == 1 ? [
          IconButton(
            onPressed: () {
              // Trigger refresh for appointments tab
              // This will be handled by the tab itself
            },
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ] : null,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: const Color.fromARGB(255, 32, 160, 200),
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'RV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
