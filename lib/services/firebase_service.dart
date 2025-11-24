// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Initialize Firebase if it's not already initialized (usually called in main.dart)
  Future<void> initializeFirebase() async {
    // FirebaseAuth, FirebaseFirestore, and FirebaseMessaging are initialized automatically
    // But we can add custom initialization logic if needed here
  }

  // Save the FCM token to Firestore
  Future<void> saveFcmToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Save the token to the user's document in Firestore
      await _fs.collection('users').doc(user.uid).update({'fcmToken': token});
    }
  }

  // Get the FCM token for the current user
  Future<String?> getFcmToken() async {
    final token = await _fcm.getToken();
    return token;
  }

  // Get a user's FCM token from Firestore
  Future<String?> getUserFcmToken(String uid) async {
    final userDoc = await _fs.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return userDoc.data()?['fcmToken'];
    }
    return null;
  }

  // This function should be called when the app starts to ensure the token is up to date
  Future<void> updateFcmToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      saveFcmToken(token);  // Save the token to Firestore
    }
  }
}
