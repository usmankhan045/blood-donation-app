import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DonorProfileCompletionScreen extends StatefulWidget {
  @override
  State<DonorProfileCompletionScreen> createState() => _DonorProfileCompletionScreenState();
}

class _DonorProfileCompletionScreenState extends State<DonorProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for text fields
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController cnicCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController emergencyCtrl = TextEditingController();

  String? gender;
  DateTime? dob;
  String? bloodGroup;
  bool healthy = false;
  String? frequency;
  XFile? profileImage;

  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> genders = ['Male', 'Female', 'Other'];
  final List<String> frequencies = ['Once', 'Regular', 'Never Donated Before'];

  double get completionScore {
    int filled = 0;
    if (nameCtrl.text.isNotEmpty) filled++;
    if (gender != null) filled++;
    if (dob != null) filled++;
    if (bloodGroup != null) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (cnicCtrl.text.isNotEmpty) filled++;
    if (addressCtrl.text.isNotEmpty) filled++;
    if (healthy) filled++;
    if (frequency != null) filled++;
    if (emergencyCtrl.text.isNotEmpty) filled++;
    return filled / 10;
  }

  // Validation functions
  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.length < 3) {
      return 'Name must be at least 3 characters long';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    // Pakistani phone number format: 03XXXXXXXXX
    final phoneRegex = RegExp(r'^03[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid Pakistani phone number (03XXXXXXXXX)';
    }
    return null;
  }

  String? _validateCNIC(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your CNIC';
    }
    // CNIC format: XXXXX-XXXXXXX-X
    final cnicRegex = RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]{1}$');
    if (!cnicRegex.hasMatch(value)) {
      return 'Enter CNIC in format: XXXXX-XXXXXXX-X';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your address';
    }
    if (value.length < 10) {
      return 'Address must be at least 10 characters long';
    }
    return null;
  }

  String? _validateEmergencyContact(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter emergency contact';
    }
    final phoneRegex = RegExp(r'^03[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter a valid Pakistani phone number (03XXXXXXXXX)';
    }
    if (value == phoneCtrl.text) {
      return 'Emergency contact cannot be same as your phone number';
    }
    return null;
  }

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(Duration(days: 365 * 16)), // Minimum 16 years old
    );
    if (result != null) setState(() => dob = result);
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (img != null) setState(() => profileImage = img);
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please fix all errors before saving")));
      return;
    }

    if (!healthy) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please confirm you are healthy to donate")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not logged in. Please log in again.");
      }

      // Calculate age from DOB
      final age = DateTime.now().difference(dob!).inDays ~/ 365;

      final data = {
        'fullName': nameCtrl.text.trim(),
        'gender': gender,
        'dob': dob?.toIso8601String(),
        'age': age,
        'bloodGroup': bloodGroup,
        'phoneNumber': phoneCtrl.text.trim(),
        'cnic': cnicCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'isHealthy': healthy,
        'donationFrequency': frequency,
        'emergencyContact': emergencyCtrl.text.trim(),
        'profilePhoto': profileImage?.path, // You can upload to Firebase Storage later
        'profileCompleted': completionScore == 1.0,
        'userType': 'donor',
        'isAvailable': true, // Default available status
        'lastDonationDate': null,
        'totalDonations': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print("Saving donor profile for UID: ${user.uid}");
      print("Profile data: $data");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      print("Profile successfully saved!");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completionScore == 1.0
              ? "Profile Completed Successfully!"
              : "Profile Saved Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back only if profile is 100% complete
      if (completionScore == 1.0) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      print("Error saving profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving profile: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile'),
        backgroundColor: Color(0xFF67D5B5),
        elevation: 0,
      ),
      backgroundColor: Color(0xFFF6F9FB),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF67D5B5)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Indicator
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: completionScore == 1.0 ? Colors.green : Colors.grey[700],
                      ),
                    ),
                    if (completionScore < 1.0) ...[
                      SizedBox(height: 4),
                      Text(
                        'Complete all fields to finish profile',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 22),

              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundImage: profileImage != null
                          ? FileImage(File(profileImage!.path))
                          : null,
                      backgroundColor: Colors.grey[200],
                      child: profileImage == null
                          ? Icon(Icons.person, size: 48, color: Colors.grey[500])
                          : null,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: IconButton(
                        icon: Icon(Icons.camera_alt, color: Color(0xFF67D5B5)),
                        onPressed: pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 22),

              // Full Name
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: _validateName,
              ),
              SizedBox(height: 14),

              // Gender
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
                validator: (v) => v == null ? "Please select your gender" : null,
              ),
              SizedBox(height: 14),

              // Date of Birth
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
                      hintText: 'Tap to select date',
                    ),
                    controller: TextEditingController(
                      text: dob == null ? "" : DateFormat('dd/MM/yyyy').format(dob!),
                    ),
                    validator: (_) => dob == null ? "Please select your date of birth" : null,
                    onTap: pickDate,
                  ),
                ),
              ),
              if (dob != null) ...[
                SizedBox(height: 8),
                Text(
                  'Age: ${DateTime.now().difference(dob!).inDays ~/ 365} years',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              SizedBox(height: 14),

              // Blood Group
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
                validator: (v) => v == null ? "Please select your blood group" : null,
              ),
              SizedBox(height: 14),

              // Phone Number
              TextFormField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.phone),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '03XXXXXXXXX',
                ),
                keyboardType: TextInputType.phone,
                validator: _validatePhone,
              ),
              SizedBox(height: 14),

              // CNIC
              TextFormField(
                controller: cnicCtrl,
                decoration: InputDecoration(
                  labelText: 'CNIC / ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.badge),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'XXXXX-XXXXXXX-X',
                ),
                keyboardType: TextInputType.number,
                validator: _validateCNIC,
              ),
              SizedBox(height: 14),

              // Address
              TextFormField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.location_on),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 2,
                validator: _validateAddress,
              ),
              SizedBox(height: 14),

              // Health Check
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Health Declaration',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: healthy,
                        onChanged: (v) => setState(() => healthy = v!),
                        title: Text("I confirm that I am healthy and eligible to donate blood"),
                        subtitle: Text("You must be in good health to donate"),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Color(0xFF67D5B5),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 14),

              // Donation Frequency
              DropdownButtonFormField<String>(
                value: frequency,
                decoration: InputDecoration(
                  labelText: 'Donation Frequency',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: frequencies
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (val) => setState(() => frequency = val),
                validator: (v) => v == null ? "Please select donation frequency" : null,
              ),
              SizedBox(height: 14),

              // Emergency Contact
              TextFormField(
                controller: emergencyCtrl,
                decoration: InputDecoration(
                  labelText: 'Emergency Contact',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  prefixIcon: Icon(Icons.contact_emergency),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '03XXXXXXXXX',
                ),
                keyboardType: TextInputType.phone,
                validator: _validateEmergencyContact,
              ),
              SizedBox(height: 24),

              // Save Button
              ElevatedButton.icon(
                icon: _isLoading
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.save_alt),
                label: Text(
                  completionScore == 1.0 ? "Complete Profile" : "Save Progress",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: completionScore == 1.0 ? Colors.green : Color(0xFF67D5B5),
                  padding: EdgeInsets.symmetric(vertical: 15),
                  textStyle: TextStyle(fontSize: 17),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: _isLoading ? null : saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}