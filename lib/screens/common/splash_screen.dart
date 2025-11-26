import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_user_type_screen.dart';
import '../dashboard/donor/donor_dashboard_screen.dart';
import '../dashboard/recipient/recipient_dashboard_screen.dart';
// Import other dashboards as needed

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
          // User is logged in - check their role and redirect accordingly
          await _redirectBasedOnUserRole(user.uid);
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
      // If there's any error, navigate to role selection
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SelectUserTypeScreen()),
        );
      }
    }
  }

  Future<void> _redirectBasedOnUserRole(String userId) async {
    try {
      // Get user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final userRole = userData?['role'] as String?;
        final profileCompleted = userData?['profileCompleted'] ?? false;

        print('User role: $userRole, Profile completed: $profileCompleted');

        // Navigate based on role
        switch (userRole) {
          case 'donor':
            if (profileCompleted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DonorDashboardScreen()),
              );
            } else {
              Navigator.pushReplacementNamed(context, '/donor_profile_completion');
            }
            break;
          case 'recipient':
            if (profileCompleted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RecipientDashboardScreen()),
              );
            } else {
              Navigator.pushReplacementNamed(context, '/recipient_profile_completion');
            }
            break;
          case 'hospital':
            if (profileCompleted) {
              Navigator.pushReplacementNamed(context, '/hospital_dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/hospital_profile_completion');
            }
            break;
          case 'blood_bank':
            if (profileCompleted) {
              Navigator.pushReplacementNamed(context, '/blood_bank_dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/blood_bank_profile_completion');
            }
            break;
          case 'admin':
            Navigator.pushReplacementNamed(context, '/admin_dashboard');
            break;
          default:
          // If role is not set or invalid, go to role selection
            _goToRoleSelection();
            break;
        }
      } else {
        // User document doesn't exist - go to role selection
        _goToRoleSelection();
      }
    } catch (e) {
      print('Error checking user role: $e');
      // On error, go to role selection
      _goToRoleSelection();
    }
  }

  void _goToRoleSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SelectUserTypeScreen()),
    );
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