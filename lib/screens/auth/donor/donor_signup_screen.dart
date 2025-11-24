import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DonorSignUpScreen extends StatefulWidget {
  const DonorSignUpScreen({Key? key}) : super(key: key);

  @override
  _DonorSignUpScreenState createState() => _DonorSignUpScreenState();
}

class _DonorSignUpScreenState extends State<DonorSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _isLoading = false;

  // Google Sign Up
  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await GoogleSignIn().signOut(); // Always show picker

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
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
        await userDoc.set({
          'email': userCred.user!.email,
          'role': 'donor',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (userSnapshot['role'] != 'donor') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not a donor account.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      Navigator.pushReplacementNamed(context, '/donor_dashboard');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Firebase Auth error')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign up failed. Please try again.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Email/Password Sign Up
  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
    });
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': _emailCtrl.text.trim(),
        'role': 'donor',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send email verification
      await cred.user!.sendEmailVerification();

      setState(() {
        _isLoading = false;
      });

      // Popup
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Verify Your Email'),
          content: Text('A verification link has been sent to your email. Please verify your email before logging in.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/donor_login');
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Sign up failed')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF6F9FB);
    const card = Color(0xFFFFFFFF);
    const inputBorder = Color(0xFFE0E7EF);
    const text = Color(0xFF3A4958);
    const accent = Color(0xFF87BFFF);
    const button = Color(0xFFB5E4FF);
    const buttonText = Color(0xFF22567A);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        iconTheme: IconThemeData(color: accent),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Become a Donor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: text,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join our lifesaving community!',
                style: TextStyle(fontSize: 16, color: text.withOpacity(0.65)),
              ),
              const SizedBox(height: 32),
              // Email field
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: inputBorder),
                  boxShadow: [
                    BoxShadow(
                      color: inputBorder.withOpacity(0.15),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: text.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.email_outlined, color: accent),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Enter valid email';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 18),
              // Password field
              Container(
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: inputBorder),
                  boxShadow: [
                    BoxShadow(
                      color: inputBorder.withOpacity(0.15),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: text.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.lock_outline, color: accent),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPass ? Icons.visibility : Icons.visibility_off,
                        color: accent.withOpacity(0.7),
                      ),
                      onPressed: () {
                        setState(() {
                          _showPass = !_showPass;
                        });
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Min 6 chars';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 28),
              // Sign up button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: button,
                    foregroundColor: buttonText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  onPressed: _isLoading ? null : _signUpWithEmail,
                  child: _isLoading
                      ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(buttonText),
                      strokeWidth: 3,
                    ),
                  )
                      : Text(
                    'Create Account',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600, color: buttonText, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Or divider
              Row(
                children: [
                  Expanded(child: Divider(color: inputBorder)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or', style: TextStyle(color: text.withOpacity(0.45))),
                  ),
                  Expanded(child: Divider(color: inputBorder)),
                ],
              ),
              const SizedBox(height: 16),
              // Google signup
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, color: accent),
                  ),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(
                        color: text, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.1),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: inputBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: card,
                  ),
                  onPressed: _isLoading ? null : _signUpWithGoogle,
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/donor_login');
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: text.withOpacity(0.67), fontSize: 15),
                      children: [
                        TextSpan(
                          text: 'Log in',
                          style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
