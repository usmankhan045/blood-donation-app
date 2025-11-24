import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HospitalProfileCompletionScreen extends StatefulWidget {
  @override
  State<HospitalProfileCompletionScreen> createState() => _HospitalProfileCompletionScreenState();
}

class _HospitalProfileCompletionScreenState extends State<HospitalProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController hospitalNameCtrl = TextEditingController();
  final TextEditingController registrationCtrl = TextEditingController();
  final TextEditingController contactPersonCtrl = TextEditingController();
  final TextEditingController designationCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController cityCtrl = TextEditingController();

  bool hasBloodBank = false;
  String? contactMethod;

  final List<String> contactMethods = ['Call', 'SMS', 'Email'];

  double get completionScore {
    int filled = 0;
    if (hospitalNameCtrl.text.isNotEmpty) filled++;
    if (registrationCtrl.text.isNotEmpty) filled++;
    if (contactPersonCtrl.text.isNotEmpty) filled++;
    if (designationCtrl.text.isNotEmpty) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (addressCtrl.text.isNotEmpty) filled++;
    if (cityCtrl.text.isNotEmpty) filled++;
    if (contactMethod != null) filled++;
    // hasBloodBank is always present (checkbox)
    return (filled + 1) / 9;
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Not logged in. Please log in again.")));
      return;
    }

    final data = {
      'hospitalName': hospitalNameCtrl.text.trim(),
      'registrationNo': registrationCtrl.text.trim(),
      'contactPerson': contactPersonCtrl.text.trim(),
      'designation': designationCtrl.text.trim(),
      'phoneNumber': phoneCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'city': cityCtrl.text.trim(),
      'hasBloodBank': hasBloodBank,
      'preferredContactMethod': contactMethod,
      'profileCompleted': completionScore == 1.0,
      'updatedAt': FieldValue.serverTimestamp(),
      'role': 'hospital',
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
        title: Text('Complete Hospital Profile'),
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
                controller: hospitalNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Hospital Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.local_hospital),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter hospital name" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: registrationCtrl,
                decoration: InputDecoration(
                  labelText: 'Hospital Registration/License No.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.confirmation_num),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter registration/license number" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: contactPersonCtrl,
                decoration: InputDecoration(
                  labelText: 'Contact Person Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter contact person name" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: designationCtrl,
                decoration: InputDecoration(
                  labelText: 'Designation (e.g., Blood Bank Officer, Nurse)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.badge),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter designation" : null,
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
                validator: (v) => v == null || v.isEmpty ? "Enter phone number" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Hospital Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.location_on),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter address" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: cityCtrl,
                decoration: InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.location_city),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter city" : null,
              ),
              SizedBox(height: 14),

              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: hasBloodBank,
                onChanged: (v) => setState(() => hasBloodBank = v!),
                title: Text("Available Blood Bank"),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Color(0xFF67D5B5),
              ),
              SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: contactMethod,
                decoration: InputDecoration(
                  labelText: 'Preferred Contact Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.contact_phone),
                ),
                items: contactMethods
                    .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (val) => setState(() => contactMethod = val),
                validator: (v) => v == null ? "Select contact method" : null,
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
