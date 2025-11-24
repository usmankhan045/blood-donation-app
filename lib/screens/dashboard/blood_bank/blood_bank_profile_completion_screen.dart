import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BloodBankProfileCompletionScreen extends StatefulWidget {
  @override
  State<BloodBankProfileCompletionScreen> createState() => _BloodBankProfileCompletionScreenState();
}

class _BloodBankProfileCompletionScreenState extends State<BloodBankProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController bankNameCtrl = TextEditingController();
  final TextEditingController regNoCtrl = TextEditingController();
  final TextEditingController contactPersonCtrl = TextEditingController();
  final TextEditingController designationCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController cityCtrl = TextEditingController();
  final TextEditingController hoursCtrl = TextEditingController();

  List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  List<String> selectedBloodTypes = [];

  double get completionScore {
    int filled = 0;
    if (bankNameCtrl.text.isNotEmpty) filled++;
    if (regNoCtrl.text.isNotEmpty) filled++;
    if (contactPersonCtrl.text.isNotEmpty) filled++;
    if (designationCtrl.text.isNotEmpty) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (addressCtrl.text.isNotEmpty) filled++;
    if (cityCtrl.text.isNotEmpty) filled++;
    if (hoursCtrl.text.isNotEmpty) filled++;
    if (selectedBloodTypes.isNotEmpty) filled++;
    return filled / 9;
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Not logged in. Please log in again.")));
      return;
    }

    final data = {
      'bloodBankName': bankNameCtrl.text.trim(),
      'registrationNo': regNoCtrl.text.trim(),
      'contactPerson': contactPersonCtrl.text.trim(),
      'designation': designationCtrl.text.trim(),
      'phoneNumber': phoneCtrl.text.trim(),
      'address': addressCtrl.text.trim(),
      'city': cityCtrl.text.trim(),
      'operatingHours': hoursCtrl.text.trim(),
      'availableBloodTypes': selectedBloodTypes,
      'profileCompleted': completionScore == 1.0,
      'updatedAt': FieldValue.serverTimestamp(),
      'role': 'blood_bank',
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
        title: Text('Complete Blood Bank Profile'),
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
                controller: bankNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Blood Bank Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.local_hospital),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter blood bank name" : null,
              ),
              SizedBox(height: 14),

              TextFormField(
                controller: regNoCtrl,
                decoration: InputDecoration(
                  labelText: 'Registration No.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.confirmation_num),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter registration number" : null,
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
                  labelText: 'Designation',
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
                  labelText: 'Address',
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

              TextFormField(
                controller: hoursCtrl,
                decoration: InputDecoration(
                  labelText: 'Operating Hours',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.access_time),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter operating hours" : null,
              ),
              SizedBox(height: 14),

              Text(
                "Available Blood Types",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Wrap(
                spacing: 10,
                children: bloodTypes.map((type) {
                  return FilterChip(
                    label: Text(type),
                    selected: selectedBloodTypes.contains(type),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          selectedBloodTypes.add(type);
                        } else {
                          selectedBloodTypes.remove(type);
                        }
                      });
                    },
                    selectedColor: Color(0xFF67D5B5).withOpacity(0.2),
                  );
                }).toList(),
              ),
              if (selectedBloodTypes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text("Select at least one blood type", style: TextStyle(color: Colors.red[700], fontSize: 12)),
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
                  if (_formKey.currentState!.validate() && selectedBloodTypes.isNotEmpty) {
                    try {
                      await saveProfile();
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Profile Saved!")));
                      Navigator.pop(context, completionScore);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error saving profile: $e")));
                    }
                  } else if (selectedBloodTypes.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Please select at least one blood type.")));
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
