import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_user_type_screen.dart';
import '../dashboard/donor/donor_dashboard_screen.dart';
import '../dashboard/recipient/recipient_dashboard_screen.dart';
import '../../core/theme.dart';
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
        
        // 🔒 SECURITY: Check admin approval for blood banks and hospitals
        if (userRole == 'blood_bank' || userRole == 'hospital') {
          final isApproved = userData?['isApproved'] ?? false;
          final approvalStatus = userData?['approvalStatus'] ?? 'pending';
          
          if (!isApproved) {
            // User not approved - sign them out and show approval screen
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ApprovalPendingScreen(
                    role: userRole!,
                    status: approvalStatus,
                  ),
                ),
              );
            }
            return;
          }
        }

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
      backgroundColor: BloodAppTheme.primary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.asset(
                      'lib/assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image fails to load
                        return Icon(
                          Icons.bloodtype,
                          color: BloodAppTheme.primary,
                          size: 70,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Blood Donation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Saving Lives Together',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🔒 APPROVAL PENDING SCREEN
// ═══════════════════════════════════════════════════════════════

class ApprovalPendingScreen extends StatelessWidget {
  final String role;
  final String status;

  const ApprovalPendingScreen({
    Key? key,
    required this.role,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final roleName = role == 'blood_bank' ? 'Blood Bank' : 'Hospital';
    final isRejected = status == 'rejected';

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isRejected 
                        ? BloodAppTheme.error.withOpacity(0.1)
                        : BloodAppTheme.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRejected ? Icons.block : Icons.pending_actions,
                    size: 64,
                    color: isRejected ? BloodAppTheme.error : BloodAppTheme.warning,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isRejected ? 'Account Rejected' : 'Account Pending Approval',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: BloodAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isRejected
                      ? 'Your $roleName account has been rejected by the administrator. Please contact support for assistance.'
                      : 'Your $roleName account is pending admin approval. You will be able to access the app once an administrator approves your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: BloodAppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BloodAppTheme.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: BloodAppTheme.info.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: BloodAppTheme.info, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This is a security measure to ensure only verified $roleName accounts can access the platform.',
                          style: TextStyle(
                            fontSize: 13,
                            color: BloodAppTheme.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelectUserTypeScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BloodAppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}