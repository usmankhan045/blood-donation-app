import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecipientProfileCompletionScreen extends StatefulWidget {
  @override
  State<RecipientProfileCompletionScreen> createState() => _RecipientProfileCompletionScreenState();
}

class _RecipientProfileCompletionScreenState extends State<RecipientProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController cnicCtrl = TextEditingController();
  final TextEditingController diseaseCtrl = TextEditingController();

  String? gender;
  DateTime? dob;
  String? bloodGroup;
  String? relation;

  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> genders = ['Male', 'Female', 'Other'];
  final List<String> relations = ['Self', 'Family', 'Friend', 'Other'];

  double get completionScore {
    int filled = 0;
    if (nameCtrl.text.isNotEmpty) filled++;
    if (gender != null) filled++;
    if (dob != null) filled++;
    if (bloodGroup != null) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (relation != null) filled++;
    if (diseaseCtrl.text.isNotEmpty) filled++;
    if (cnicCtrl.text.length == 13) filled++;
    return filled / 8;
  }

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (result != null) setState(() => dob = result);
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
      'gender': gender,
      'dob': dob?.toIso8601String(),
      'bloodGroup': bloodGroup,
      'phoneNumber': phoneCtrl.text.trim(),
      'relationToPatient': relation,
      'disease': diseaseCtrl.text.trim(),
      'cnic': cnicCtrl.text.trim(),
      'profileCompleted': completionScore == 1.0,
      'updatedAt': FieldValue.serverTimestamp(),
      'role': 'recipient', // Optional: useful for filtering later
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
        title: Text('Complete Your Profile'),
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

              DropdownButtonFormField<String>(
                value: gender,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.wc),
                ),
                items: genders
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => gender = val),
                validator: (v) => v == null ? "Select gender" : null,
              ),
              SizedBox(height: 14),

              GestureDetector(
                onTap: pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                      prefixIcon: Icon(Icons.calendar_month),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    controller: TextEditingController(
                      text: dob == null ? "" : "${dob!.day}/${dob!.month}/${dob!.year}",
                    ),
                    validator: (_) => dob == null ? "Select DOB" : null,
                  ),
                ),
              ),
              SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: bloodGroup,
                decoration: InputDecoration(
                  labelText: 'Blood Group',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.bloodtype),
                ),
                items: bloodGroups
                    .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                    .toList(),
                onChanged: (val) => setState(() => bloodGroup = val),
                validator: (v) => v == null ? "Select blood group" : null,
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

              // CNIC FIELD
              TextFormField(
                controller: cnicCtrl,
                decoration: InputDecoration(
                  labelText: 'CNIC (13 digits Enter without dashes)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.badge),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                maxLength: 13,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter your CNIC";
                  if (v.length != 13) return "CNIC must be exactly 13 digits";
                  if (!RegExp(r'^[0-9]{13}$').hasMatch(v)) return "Only numbers allowed";
                  return null;
                },
              ),
              SizedBox(height: 0),

              DropdownButtonFormField<String>(
                value: relation,
                decoration: InputDecoration(
                  labelText: 'Relation to Patient',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.group),
                ),
                items: relations
                    .map((rel) => DropdownMenuItem(value: rel, child: Text(rel)))
                    .toList(),
                onChanged: (val) => setState(() => relation = val),
                validator: (v) => v == null ? "Select relation" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: diseaseCtrl,
                decoration: InputDecoration(
                  labelText: 'Any Disease',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.medical_services),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter disease or write 'None'" : null,
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
