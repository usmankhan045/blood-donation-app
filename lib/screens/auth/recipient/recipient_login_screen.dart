import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RecipientLoginScreen extends StatefulWidget {
  const RecipientLoginScreen({Key? key}) : super(key: key);

  @override
  _RecipientLoginScreenState createState() => _RecipientLoginScreenState();
}

class _RecipientLoginScreenState extends State<RecipientLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  String? _error;

  Future<void> _loginRecipient() async {
    setState(() {
      _loading = true;
      _error = null;
    });

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
        setState(() => _loading = false);
        return;
      }

      // Fetch and check role
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (userDoc.exists && userDoc['role'] == 'recipient') {
        if (mounted) Navigator.pushReplacementNamed(context, '/recipient_dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This account is not registered as a recipient.')),
        );
        await FirebaseAuth.instance.signOut();
        setState(() => _loading = false);
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- GOOGLE SIGN IN LOGIC ----
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

      // Fetch and check role
      final userDoc = FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid);
      final userSnapshot = await userDoc.get();

      if (!userSnapshot.exists) {
        await userDoc.set({
          'email': userCred.user!.email,
          'role': 'recipient',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/recipient_dashboard');
        }
      } else if (userSnapshot['role'] == 'recipient') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/recipient_dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This Google account is registered as a different role and cannot log in as recipient.')),
        );
        await FirebaseAuth.instance.signOut();
        setState(() => _loading = false);
        return;
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = 'Google sign in failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  // ---- END GOOGLE SIGN IN LOGIC ----

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF6F9FB);
    const card = Color(0xFFFFFFFF);
    const inputBorder = Color(0xFFE0E7EF);
    const text = Color(0xFF3A4958);
    const button = Color(0xFFFF8C8C);
    const buttonText = Colors.white;
    const signupLink = Color(0xFFD7263D);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        iconTheme: const IconThemeData(color: text),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recipient Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: text,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Login to request blood easily and fast.',
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
                      color: inputBorder.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: text.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.email_outlined, color: text.withOpacity(0.65)),
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
                      color: inputBorder.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: text.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.lock_outline, color: text.withOpacity(0.65)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPass ? Icons.visibility : Icons.visibility_off,
                        color: text.withOpacity(0.5),
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
              // Login button
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
                  onPressed: _loading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      _loginRecipient();
                    }
                  },
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: buttonText,
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
              // Google login
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) => Icon(Icons.g_mobiledata, color: button),
                  ),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: inputBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: card,
                  ),
                  onPressed: _loading ? null : _signInWithGoogle,
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/recipient_signup');
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Don\'t have an account? ',
                      style: TextStyle(color: text.withOpacity(0.67), fontSize: 15),
                      children: [
                        TextSpan(
                          text: 'Sign up',
                          style: TextStyle(color: signupLink, fontWeight: FontWeight.w700),
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
