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
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_alerts_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_my_requests_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_profile_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';




// import other signup screens here...

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BloodDonationApp());
}



class BloodDonationApp extends StatelessWidget {
  const BloodDonationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blood Donation App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/select_role': (context) => const SelectUserTypeScreen(),
        '/donor_signup': (context) => const DonorSignUpScreen(),
        '/recipient_signup': (context) => const RecipientSignUpScreen(),
        '/hospital_signup': (context) => const HospitalSignUpScreen(),
        '/blood_bank_signup': (context) => const BloodBankSignUpScreen(),
        '/admin_signup': (context) => const AdminSignUpScreen(),
        '/donor_login': (context) => const DonorLoginScreen(),
        '/recipient_login': (context) => const RecipientLoginScreen(),
        '/hospital_login': (context) => const HospitalLoginScreen(),
        '/blood_bank_login': (context) => const BloodBankLoginScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/donor_dashboard': (context) => const DonorDashboardScreen(),
        '/recipient_dashboard': (context) => const RecipientDashboardScreen(),
        '/hospital_dashboard': (context) => const HospitalDashboardScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/blood_bank_dashboard': (context) => const BloodBankDashboardScreen(),
        '/donor_profile_completion': (context) => DonorProfileCompletionScreen(),
        '/recipient_profile_completion': (context) => RecipientProfileCompletionScreen(),
        '/hospital_profile_completion': (context) => HospitalProfileCompletionScreen(),
        '/blood_bank_profile_completion': (context) => BloodBankProfileCompletionScreen(),
        '/admin_profile_completion': (context) => AdminProfileCompletionScreen(),
        '/recipient/request': (context) => const RecipientRequestScreen(),
        '/recipient/my_requests': (context) => const RecipientMyRequestsScreen(),
        '/recipient/alerts': (context) => const RecipientAlertsScreen(),
        '/recipient/profile': (context) => const RecipientProfileScreen(),






        // Add recipient, hospital, blood_bank signup routes here
      },
    );
  }
}
