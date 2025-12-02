import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Donor Sign Up
  Future<String?> signUpDonor(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'donor',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Recipient Sign Up
  Future<String?> signUpRecipient(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'recipient',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Hospital Sign Up
  Future<String?> signUpHospital(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'hospital',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Blood Bank Sign Up
  Future<String?> signUpBloodBank(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'blood_bank',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Admin Sign Up
  Future<String?> signUpAdmin(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Donor Login
  Future<String?> loginDonor(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Recipient Login
  Future<String?> loginRecipient(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Hospital Login
  Future<String?> loginHospital(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Blood Bank Login
  Future<String?> loginBloodBank(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Admin Login
  Future<String?> loginAdmin(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Sign out - with FCM token cleanup
  Future<void> signOut() async {
    try {
      // Clear FCM token before signing out
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await FCMService().clearFCMToken(currentUser.uid);
      }
    } catch (e) {
      print('⚠️ Error clearing FCM token on logout: $e');
    }

    await _auth.signOut();
  }
}
