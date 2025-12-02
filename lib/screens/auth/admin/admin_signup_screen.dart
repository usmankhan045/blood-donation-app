import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AdminSignUpScreen extends StatefulWidget {
  const AdminSignUpScreen({Key? key}) : super(key: key);

  @override
  State<AdminSignUpScreen> createState() => _AdminSignUpScreenState();
}

class _AdminSignUpScreenState extends State<AdminSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  String? _error;

  // Use the same color system as login
  static const background = Color(0xFFFAFCFD);
  static const inputBorder = Color(0xFFE3E9ED);
  static const iconColor = Color(0xFF667085);
  static const inputTextColor = Color(0xFF667085);

  InputDecoration adminInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: iconColor, size: 26),
      hintText: hint,
      hintStyle: TextStyle(
        color: iconColor.withOpacity(0.7),
        fontSize: 18,
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: inputBorder, width: 1.1),
        borderRadius: BorderRadius.circular(22),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: inputBorder, width: 1.7),
        borderRadius: BorderRadius.circular(22),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      suffixIcon: suffix,
    );
  }

  Future<void> _signUpAdmin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 👑 Check if any admins exist - first admin becomes Super Admin
      final existingAdmins = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();
      
      final isFirstAdmin = existingAdmins.docs.isEmpty;

      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': _emailCtrl.text.trim(),
        'role': 'admin',
        'isSuperAdmin': isFirstAdmin, // First admin is Super Admin
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send verification email
      await cred.user!.sendEmailVerification();

      setState(() => _loading = false);

      // Show verification dialog with Super Admin notice if applicable
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isFirstAdmin ? Icons.star : Icons.admin_panel_settings,
                  color: isFirstAdmin ? Colors.purple : Colors.blue,
                ),
                const SizedBox(width: 10),
                Text(isFirstAdmin ? 'Super Admin Created!' : 'Admin Created!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFirstAdmin) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star, color: Colors.purple, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You are the Super Admin! You can manage all other admins.',
                            style: TextStyle(fontSize: 12, color: Colors.purple),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'A verification link has been sent to your email. Please verify your email before logging in.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/admin_login');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Sign up failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await GoogleSignIn().signOut();

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      final userDoc = FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        // 👑 Check if any admins exist - first admin becomes Super Admin
        final existingAdmins = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .limit(1)
            .get();
        
        final isFirstAdmin = existingAdmins.docs.isEmpty;

        await userDoc.set({
          'email': userCred.user!.email,
          'role': 'admin',
          'isSuperAdmin': isFirstAdmin, // First admin is Super Admin
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (userSnapshot['role'] != 'admin') {
        setState(() {
          _error = 'This Google account is already registered as a different role.';
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Google sign up failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign Up as Admin',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B3A4A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage and monitor the whole system.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF8A9AAF), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 28),
                // Email Field
                TextFormField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: inputTextColor, fontWeight: FontWeight.w600, fontSize: 17),
                  decoration: adminInputDecoration(
                    hint: 'Email',
                    icon: Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                // Password Field
                TextFormField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  style: const TextStyle(color: inputTextColor, fontWeight: FontWeight.w600, fontSize: 17),
                  decoration: adminInputDecoration(
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _showPass ? Icons.visibility : Icons.visibility_off,
                        color: iconColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPass = !_showPass;
                        });
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Min 6 chars';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                // Lavender Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3D6FF),
                      foregroundColor: const Color(0xFF4B3C72),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed: _loading
                        ? null
                        : () {
                      if (_formKey.currentState!.validate()) {
                        _signUpAdmin();
                      }
                    },
                    child: _loading
                        ? const CircularProgressIndicator(color: Color(0xFF4B3C72))
                        : const Text(
                      'Create Account',
                      style: TextStyle(
                        color: Color(0xFF4B3C72),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: Divider(color: inputBorder, thickness: 1)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'or',
                        style: TextStyle(color: inputBorder, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(child: Divider(color: inputBorder, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, color: iconColor),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Color(0xFF3A4958),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: inputBorder, width: 1.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed: _loading ? null : _signInWithGoogle,
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/admin_login');
                    },
                    child: RichText(
                      text: const TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(color: Color(0xFF8A9AAF), fontSize: 15),
                        children: [
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              color: Color(0xFF4B3C72),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
