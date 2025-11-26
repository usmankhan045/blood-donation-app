import 'package:blood_donation_app/screens/auth/admin/admin_login_screen.dart';
import 'package:blood_donation_app/screens/auth/admin/admin_signup_screen.dart';
import 'package:blood_donation_app/screens/auth/blood_bank/blood_bank_login_screen.dart';
import 'package:blood_donation_app/screens/auth/blood_bank/blood_bank_signup_screen.dart';
import 'package:blood_donation_app/screens/auth/donor/donor_login_screen.dart';
import 'package:blood_donation_app/screens/auth/donor/donor_signup_screen.dart';
import 'package:blood_donation_app/screens/auth/hospital/hospital_login_screen.dart';
import 'package:blood_donation_app/screens/auth/hospital/hospital_signup_screen.dart';
import 'package:blood_donation_app/screens/auth/recipient/recipient_login_screen.dart';
import 'package:blood_donation_app/screens/auth/recipient/recipient_signup_screen.dart';
import 'package:blood_donation_app/screens/common/select_user_type_screen.dart';
import 'package:blood_donation_app/screens/common/splash_screen.dart';
import 'package:blood_donation_app/screens/dashboard/admin/admin_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/admin/admin_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/blood_bank/blood_bank_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/blood_bank/blood_bank_profile_completion_screen.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_profile_screen.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_requests_screen.dart';
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_alerts_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_my_requests_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_profile_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_request_screen.dart';
import 'package:blood_donation_app/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/request_provider.dart';

// Import the new screens
import 'screens/my_requests_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  // Initialize notifications (but don't block app startup)
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  notificationService.initializeFCM().catchError((e) {
    print('❌ FCM initialization error: $e');
  });

  runApp(BloodDonationApp());
}

class BloodDonationApp extends StatelessWidget {
  const BloodDonationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        // Add other providers here as needed
      ],
      child: MaterialApp(
        title: 'Blood Donation App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Color(0xFF67D5B5),
          scaffoldBackgroundColor: Color(0xFFF6F9FB),
          fontFamily: 'Roboto',
          visualDensity: VisualDensity.adaptivePlatformDensity,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: Color(0xFF67D5B5),
            secondary: Color(0xFF4AB9C5),
          ),
        ),
        navigatorKey: NotificationService.navigatorKey,
        home: const SplashScreen(),
        routes: {
          // Common Routes
          '/select_role': (context) => const SelectUserTypeScreen(),

          // Auth Routes - Signup
          '/donor_signup': (context) => const DonorSignUpScreen(),
          '/recipient_signup': (context) => const RecipientSignUpScreen(),
          '/hospital_signup': (context) => const HospitalSignUpScreen(),
          '/blood_bank_signup': (context) => const BloodBankSignUpScreen(),
          '/admin_signup': (context) => const AdminSignUpScreen(),

          // Auth Routes - Login
          '/donor_login': (context) => const DonorLoginScreen(),
          '/recipient_login': (context) => const RecipientLoginScreen(),
          '/hospital_login': (context) => const HospitalLoginScreen(),
          '/blood_bank_login': (context) => const BloodBankLoginScreen(),
          '/admin_login': (context) => const AdminLoginScreen(),

          // Dashboard Routes
          '/donor_dashboard': (context) => const DonorDashboardScreen(),
          '/recipient_dashboard': (context) => const RecipientDashboardScreen(),
          '/hospital_dashboard': (context) => const HospitalDashboardScreen(),
          '/blood_bank_dashboard': (context) => const BloodBankDashboardScreen(),
          '/admin_dashboard': (context) => const AdminDashboardScreen(),

          // Profile Completion Routes
          '/donor_profile_completion': (context) => DonorProfileCompletionScreen(),
          '/recipient_profile_completion': (context) => RecipientProfileCompletionScreen(),
          '/hospital_profile_completion': (context) => HospitalProfileCompletionScreen(),
          '/blood_bank_profile_completion': (context) => BloodBankProfileCompletionScreen(),
          '/admin_profile_completion': (context) => AdminProfileCompletionScreen(),

          // Recipient Specific Routes
          '/recipient/request': (context) => const RecipientRequestScreen(),
          '/recipient/my_requests': (context) => const RecipientMyRequestsScreen(),
          '/recipient/alerts': (context) => const RecipientAlertsScreen(),
          '/recipient/profile': (context) => const RecipientProfileScreen(),

          // Donor Specific Routes
          '/donor/profile': (context) => const DonorProfileScreen(),

          // NEW SCREENS - Add these routes
          '/my_requests': (context) => const MyRequestsScreen(),
          '/donor_requests': (context) => const DonorRequestsScreen(),
        },
      ),
    );
  }
}