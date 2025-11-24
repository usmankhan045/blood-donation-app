import 'package:flutter/material.dart';
import 'package:blood_donation_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DonorLoginScreen extends StatefulWidget {
  const DonorLoginScreen({Key? key}) : super(key: key);

  @override
  State<DonorLoginScreen> createState() => _DonorLoginScreenState();
}

class _DonorLoginScreenState extends State<DonorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await GoogleSignIn().signOut();

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
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/donor_dashboard');
        }
      } else if (userSnapshot['role'] == 'donor') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/donor_dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This Google account is registered as a different role and cannot log in as donor.')),
        );
        await FirebaseAuth.instance.signOut();
        setState(() => _isLoading = false);
        return;
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Firebase Auth error')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign in failed. Please try again.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      User? user = cred.user;
      await user?.reload();
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please verify your email before logging in. Verification link sent again!')),
        );
        await FirebaseAuth.instance.signOut();
        setState(() => _isLoading = false);
        return;
      }

      // Fetch and check role
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (userDoc.exists && userDoc['role'] == 'donor') {
        if (mounted) Navigator.pushReplacementNamed(context, '/donor_dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This account is not registered as a donor.')),
        );
        await FirebaseAuth.instance.signOut();
        setState(() => _isLoading = false);
        return;
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed. Please try again.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF6FAFD);
    const inputBorder = Color(0xFFE1EEF7);
    const heading = Colors.black;
    const subText = Color(0xFF3A4958);
    const inputText = Color(0xFF6A7A8B);
    const inputIcon = Color(0xFF6A7A8B);
    const button = Color(0xFF90CDFE);
    const buttonText = Color(0xFF244A67);
    const link = Color(0xFF46A2E0);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Donor Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your donor account.',
                  style: TextStyle(fontSize: 15, color: subText.withOpacity(0.55)),
                ),
                const SizedBox(height: 28),
                // Email Field
                TextFormField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: inputText, fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.email_outlined, color: inputIcon),
                    hintText: 'Email',
                    hintStyle: TextStyle(color: inputText.withOpacity(0.6), fontWeight: FontWeight.w400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorder, width: 2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorder, width: 2.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Enter valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                // Password Field
                TextFormField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  style: const TextStyle(color: inputText, fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.lock_outline, color: inputIcon),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPass ? Icons.visibility : Icons.visibility_off,
                        color: inputIcon,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPass = !_showPass;
                        });
                      },
                    ),
                    hintText: 'Password',
                    hintStyle: TextStyle(color: inputText.withOpacity(0.6), fontWeight: FontWeight.w400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorder, width: 2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: inputBorder, width: 2.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Min 6 chars';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: button,
                      foregroundColor: buttonText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _isLoading ? null : _loginWithEmail,
                    child: _isLoading
                        ? SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(buttonText),
                        strokeWidth: 3,
                      ),
                    )
                        : Text(
                      'Login',
                      style: TextStyle(
                        color: buttonText,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Divider and Google
                Row(
                  children: [
                    Expanded(child: Divider(color: inputBorder, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'or',
                        style: TextStyle(color: inputBorder, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(child: Divider(color: inputBorder, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 14),
                // Google Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, color: inputIcon),
                    ),
                    label: Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: inputText,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: inputBorder, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                  ),
                ),
                const SizedBox(height: 30),
                // Sign Up Link
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/donor_signup');
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: inputText.withOpacity(0.8), fontSize: 15),
                        children: [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(color: link, fontWeight: FontWeight.w700),
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
