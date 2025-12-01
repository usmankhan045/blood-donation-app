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

  // Hospital Sign Up - Requires Admin Approval
  Future<String?> signUpHospital(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'hospital',
        'isApproved': false, // Requires admin approval
        'approvalStatus': 'pending', // pending, approved, rejected
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Create approval request for admin
      await _firestore.collection('approval_requests').doc(cred.user!.uid).set({
        'userId': cred.user!.uid,
        'email': email,
        'role': 'hospital',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      
      return null; // success - but account needs approval
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Blood Bank Sign Up - Requires Admin Approval
  Future<String?> signUpBloodBank(String email, String password) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': 'blood_bank',
        'isApproved': false, // Requires admin approval
        'approvalStatus': 'pending', // pending, approved, rejected
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Create approval request for admin
      await _firestore.collection('approval_requests').doc(cred.user!.uid).set({
        'userId': cred.user!.uid,
        'email': email,
        'role': 'blood_bank',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      
      return null; // success - but account needs approval
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

  // Hospital Login - Checks Approval Status
  Future<String?> loginHospital(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Check approval status
      final userDoc = await _firestore.collection('users').doc(cred.user!.uid).get();
      final isApproved = userDoc.data()?['isApproved'] ?? false;
      final approvalStatus = userDoc.data()?['approvalStatus'] ?? 'pending';
      
      if (!isApproved) {
        await _auth.signOut(); // Sign out unapproved user
        if (approvalStatus == 'rejected') {
          return 'Your account has been rejected. Please contact support.';
        }
        return 'Your account is pending admin approval. Please wait for approval before logging in.';
      }
      
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Blood Bank Login - Checks Approval Status
  Future<String?> loginBloodBank(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Check approval status
      final userDoc = await _firestore.collection('users').doc(cred.user!.uid).get();
      final isApproved = userDoc.data()?['isApproved'] ?? false;
      final approvalStatus = userDoc.data()?['approvalStatus'] ?? 'pending';
      
      if (!isApproved) {
        await _auth.signOut(); // Sign out unapproved user
        if (approvalStatus == 'rejected') {
          return 'Your account has been rejected. Please contact support.';
        }
        return 'Your account is pending admin approval. Please wait for approval before logging in.';
      }
      
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }
  
  // Admin: Approve Account
  Future<String?> approveAccount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isApproved': true,
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('approval_requests').doc(userId).update({
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      return null;
    } catch (e) {
      return e.toString();
    }
  }
  
  // Admin: Reject Account
  Future<String?> rejectAccount(String userId, String? reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isApproved': false,
        'approvalStatus': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      
      await _firestore.collection('approval_requests').doc(userId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      return null;
    } catch (e) {
      return e.toString();
    }
  }
  
  // Get pending approval requests
  Stream<QuerySnapshot> getPendingApprovals() {
    return _firestore
        .collection('approval_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();
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
      // 🔥 Clear FCM token before signing out (important for reinstalls)
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
