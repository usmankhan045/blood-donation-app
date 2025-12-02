import 'package:blood_donation_app/providers/blood_bank_provider.dart';
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
import 'package:blood_donation_app/screens/dashboard/admin/admin_manage_admins_screen.dart';
import 'package:blood_donation_app/screens/dashboard/admin/admin_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/admin/admin_profile_screen.dart';
import 'package:blood_donation_app/screens/dashboard/admin/admin_reports_screen.dart';
import 'package:blood_donation_app/screens/dashboard/admin/admin_verify_users_screen.dart';
import 'package:blood_donation_app/screens/dashboard/admin/admin_manage_users_screen.dart';
import 'package:blood_donation_app/screens/dashboard/blood_bank/blood_bank_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/blood_bank/blood_bank_profile_completion_screen.dart';
import 'package:blood_donation_app/screens/dashboard/blood_bank/stock_screen.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_profile_screen.dart';
import 'package:blood_donation_app/screens/dashboard/donor/donor_requests_screen.dart';
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_request_screen.dart';
import 'package:blood_donation_app/screens/dashboard/hospital/hospital_my_requests_screen.dart';
import 'package:blood_donation_app/screens/chat/chat_list_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_alerts_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_dashboard_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_my_requests_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_profile_completion.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_profile_screen.dart';
import 'package:blood_donation_app/screens/dashboard/recipient/recipient_request_screen.dart';
import 'package:blood_donation_app/services/service_locator.dart';
import 'package:blood_donation_app/services/location_service.dart';
import 'package:blood_donation_app/services/navigation_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/request_provider.dart';
import 'screens/my_requests_screen.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  try {
    ServiceLocator().initialize();
    print('✅ ServiceLocator initialized successfully');
  } catch (e) {
    print('❌ ServiceLocator initialization error: $e');
  }

  try {
    await LocationService.requestLocationPermission();
    print('✅ Location permissions requested successfully');
  } catch (e) {
    print('❌ Location permission error: $e');
  }

  // 🔥 INITIALIZE FCM SERVICE
  try {
    await FCMService().initializeFCM();
    print('✅ FCM initialized successfully');
  } catch (e) {
    print('❌ FCM initialization error: $e');
  }

  // 🏥 NOTE: Fulfillment service will be initialized after user login
  // processPendingFulfillments() requires authentication, so it's called in splash_screen

  runApp(BloodDonationApp());
}

class BloodDonationApp extends StatelessWidget {
  const BloodDonationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => BloodBankProvider()),
      ],
      child: MaterialApp(
        title: 'Blood Donation App',
        debugShowCheckedModeBanner: false,
        navigatorKey: NavigationService.instance.navigatorKey,
        theme: ThemeData(
          primaryColor: const Color(0xFF67D5B5),
          scaffoldBackgroundColor: const Color(0xFFF6F9FB),
          fontFamily: 'Roboto',
          visualDensity: VisualDensity.adaptivePlatformDensity,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: const Color(0xFF67D5B5),
            secondary: const Color(0xFF4AB9C5),
          ),
        ),
        home: const SplashScreen(),
        routes: {
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
          '/blood_bank_dashboard': (context) => const BloodBankDashboardScreen(),
          '/admin_dashboard': (context) => const AdminDashboardScreen(),
          '/donor_profile_completion': (context) => DonorProfileCompletionScreen(),
          '/recipient_profile_completion': (context) => RecipientProfileCompletionScreen(),
          '/hospital_profile_completion': (context) => HospitalProfileCompletionScreen(),
          '/blood_bank_profile_completion': (context) => BloodBankProfileCompletionScreen(),
          '/admin_profile_completion': (context) => AdminProfileCompletionScreen(),
          '/recipient/request': (context) => const RecipientRequestScreen(),
          '/recipient/my_requests': (context) => const RecipientMyRequestsScreen(),
          '/recipient/alerts': (context) => const RecipientAlertsScreen(),
          '/recipient/profile': (context) => const RecipientProfileScreen(),
          '/donor/profile': (context) => const DonorProfileScreen(),
          '/my_requests': (context) => const MyRequestsScreen(),
          '/donor_requests': (context) => const DonorRequestsScreen(),
          '/admin_reports': (context) => const AdminReportsScreen(),
          '/admin_verify_users': (context) => const AdminVerifyUsersScreen(),
          '/admin_manage_users': (context) => const AdminManageUsersScreen(),
          '/admin_profile': (context) => const AdminProfileScreen(),
          '/admin_manage_admins': (context) => AdminManageAdminsScreen(),
          '/completed_requests': (context) => const MyRequestsScreen(),
          '/blood_bank_requests': (context) => const BloodBankDashboardScreen(),
          '/blood_bank_inventory': (context) => const StockScreen(),
          '/hospital/request': (context) => const HospitalRequestScreen(),
          '/hospital/my_requests': (context) => const HospitalMyRequestsScreen(),
          '/chats': (context) => const ChatListScreen(),
        },
      ),
    );
  }
}