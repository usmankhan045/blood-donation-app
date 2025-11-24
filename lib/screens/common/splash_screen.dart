import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_user_type_screen.dart';
import '../dashboard/donor/donor_dashboard_screen.dart'; // Add other dashboards as needed

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait for Firebase to be ready
      await Future.delayed(const Duration(seconds: 2));

      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        if (user != null) {
          // User is logged in - redirect to appropriate dashboard
          // For now, redirect to donor dashboard (you can add logic to detect user type)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
          );
        } else {
          // User is not logged in - go to role selection
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SelectUserTypeScreen()),
          );
        }
      }
    } catch (e) {
      print('❌ Splash screen error: $e');
      // If there's any error, still navigate to role selection
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SelectUserTypeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF67D5B5), // Use your brand color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.bloodtype,
                color: Color(0xFF67D5B5),
                size: 60,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Blood Donation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Saving Lives Together',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}