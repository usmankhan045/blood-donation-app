import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminProfileCompletionScreen extends StatefulWidget {
  @override
  State<AdminProfileCompletionScreen> createState() => _AdminProfileCompletionScreenState();
}

class _AdminProfileCompletionScreenState extends State<AdminProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController designationCtrl = TextEditingController();

  String? email;

  double get completionScore {
    int filled = 0;
    if (nameCtrl.text.isNotEmpty) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (designationCtrl.text.isNotEmpty) filled++;
    if (email != null && email!.isNotEmpty) filled++;
    return filled / 4;
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    email = user?.email ?? '';
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Not logged in. Please log in again.")));
      return;
    }

    final data = {
      'fullName': nameCtrl.text.trim(),
      'phoneNumber': phoneCtrl.text.trim(),
      'email': email ?? '',
      'designation': designationCtrl.text.trim(),
      'profileCompleted': completionScore == 1.0,
      'updatedAt': FieldValue.serverTimestamp(),
      'role': 'admin',
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Admin Profile'),
        backgroundColor: Color(0xFF67D5B5),
      ),
      backgroundColor: Color(0xFFF6F9FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 75,
                      height: 75,
                      child: CircularProgressIndicator(
                        value: completionScore,
                        strokeWidth: 7,
                        color: completionScore == 1.0 ? Colors.green : Color(0xFF67D5B5),
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Profile ${((completionScore) * 100).round()}% complete',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22),

              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter your name" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.phone),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? "Enter your phone number" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: designationCtrl,
                decoration: InputDecoration(
                  labelText: 'Designation/Role',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.admin_panel_settings),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter your designation/role" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                enabled: false,
                initialValue: email ?? '',
                decoration: InputDecoration(
                  labelText: 'Email (from login)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.email),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              SizedBox(height: 24),

              ElevatedButton.icon(
                icon: Icon(Icons.save_alt),
                label: Text(
                  completionScore == 1.0 ? "Save & Finish" : "Save Progress",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF67D5B5),
                  padding: EdgeInsets.symmetric(vertical: 15),
                  textStyle: TextStyle(fontSize: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      await saveProfile();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Profile Saved!")));
                      Navigator.pop(context, completionScore);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error saving profile: $e")));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
