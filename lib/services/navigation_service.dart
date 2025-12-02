import 'package:flutter/material.dart';

/// Global navigation service for navigating from anywhere in the app
/// including from FCM notification handlers
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  static NavigationService get instance => _instance;

  /// Global navigator key to be used in MaterialApp
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Get the current navigator state
  NavigatorState? get navigator => navigatorKey.currentState;

  /// Navigate to a named route
  Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    return navigator?.pushNamed(routeName, arguments: arguments);
  }

  /// Navigate and remove all previous routes
  Future<dynamic>? navigateToAndClearStack(String routeName, {Object? arguments}) {
    return navigator?.pushNamedAndRemoveUntil(routeName, (route) => false, arguments: arguments);
  }

  /// Push a new route (widget)
  Future<dynamic>? push(Widget widget) {
    return navigator?.push(MaterialPageRoute(builder: (_) => widget));
  }

  /// Go back
  void goBack() {
    navigator?.pop();
  }

  /// Navigate to a blood request (used when notification is tapped)
  void navigateToRequest(String requestId, String userType) {
    switch (userType) {
      case 'donor':
        navigateTo('/donor_requests');
        break;
      case 'recipient':
        navigateTo('/recipient/my_requests');
        break;
      case 'blood_bank':
        navigateTo('/blood_bank_dashboard');
        break;
      case 'hospital':
        navigateTo('/hospital/my_requests');
        break;
      default:
        // Just navigate to requests
        navigateTo('/donor_requests');
    }
  }

  /// Navigate to chat for a specific request
  void navigateToChat(String requestId, String otherUserName) {
    // Import ChatScreen when needed
    navigateTo('/chats');
  }
}

final navigationService = NavigationService.instance;

