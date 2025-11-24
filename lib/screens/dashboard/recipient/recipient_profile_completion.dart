import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RecipientProfileCompletionScreen extends StatefulWidget {
  @override
  State<RecipientProfileCompletionScreen> createState() => _RecipientProfileCompletionScreenState();
}

class _RecipientProfileCompletionScreenState extends State<RecipientProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for text fields
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController cnicCtrl = TextEditingController();
  final TextEditingController diseaseCtrl = TextEditingController();
  final TextEditingController patientNameCtrl = TextEditingController();
  final TextEditingController hospitalCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();

  String? gender;
  DateTime? dob;
  String? bloodGroup;
  String? relation;
  String? urgencyLevel;

  final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> genders = ['Male', 'Female', 'Other'];
  final List<String> relations = ['Self', 'Family Member', 'Friend', 'Relative', 'Other'];
  final List<String> urgencyLevels = ['Low', 'Medium', 'High', 'Critical'];

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
    if (patientNameCtrl.text.isNotEmpty && relation != 'Self') filled++;
    if (hospitalCtrl.text.isNotEmpty) filled++;
    if (addressCtrl.text.isNotEmpty) filled++;
    if (urgencyLevel != null) filled++;
    return filled / 12;
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
    // CNIC format: 13 digits without dashes
    final cnicRegex = RegExp(r'^[0-9]{13}$');
    if (!cnicRegex.hasMatch(value)) {
      return 'CNIC must be exactly 13 digits (numbers only)';
    }
    return null;
  }

  String? _validatePatientName(String? value) {
    if (relation != 'Self' && (value == null || value.isEmpty)) {
      return 'Please enter patient name';
    }
    if (value != null && value.isNotEmpty && value.length < 3) {
      return 'Patient name must be at least 3 characters';
    }
    return null;
  }

  String? _validateHospital(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter hospital name';
    }
    if (value.length < 3) {
      return 'Hospital name must be at least 3 characters';
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

  String? _validateDisease(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter medical condition or "None"';
    }
    return null;
  }

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (result != null) setState(() => dob = result);
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please fix all errors before saving")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not logged in. Please log in again.");
      }

      // Calculate age from DOB
      final age = dob != null ? DateTime.now().difference(dob!).inDays ~/ 365 : null;

      final data = {
        'fullName': nameCtrl.text.trim(),
        'gender': gender,
        'dob': dob?.toIso8601String(),
        'age': age,
        'bloodGroup': bloodGroup,
        'phoneNumber': phoneCtrl.text.trim(),
        'cnic': cnicCtrl.text.trim(),
        'relationToPatient': relation,
        'patientName': relation == 'Self' ? nameCtrl.text.trim() : patientNameCtrl.text.trim(),
        'disease': diseaseCtrl.text.trim(),
        'hospital': hospitalCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'urgencyLevel': urgencyLevel,
        'profileCompleted': completionScore == 1.0,
        'userType': 'recipient',
        'totalRequests': 0,
        'activeRequests': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print("Saving recipient profile for UID: ${user.uid}");
      print("Profile data: $data");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      print("Recipient profile successfully saved!");

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
      print("Error saving recipient profile: $e");
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
        title: Text('Complete Recipient Profile'),
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

              // Personal Information Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

                      // Full Name
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Your Full Name',
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
                          labelText: 'Required Blood Group',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.bloodtype),
                        ),
                        items: bloodGroups
                            .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                            .toList(),
                        onChanged: (val) => setState(() => bloodGroup = val),
                        validator: (v) => v == null ? "Please select required blood group" : null,
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
                          labelText: 'CNIC (13 digits without dashes)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.badge),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: '1234567890123',
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 13,
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
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Patient Information Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Information',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

                      // Relation to Patient
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
                        validator: (v) => v == null ? "Please select relation to patient" : null,
                      ),
                      SizedBox(height: 14),

                      // Patient Name (conditionally shown)
                      if (relation != null && relation != 'Self')
                        TextFormField(
                          controller: patientNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Patient Name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                            prefixIcon: Icon(Icons.sick),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: _validatePatientName,
                        ),
                      if (relation != null && relation != 'Self') SizedBox(height: 14),

                      // Hospital
                      TextFormField(
                        controller: hospitalCtrl,
                        decoration: InputDecoration(
                          labelText: 'Hospital Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.local_hospital),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: _validateHospital,
                      ),
                      SizedBox(height: 14),

                      // Medical Condition
                      TextFormField(
                        controller: diseaseCtrl,
                        decoration: InputDecoration(
                          labelText: 'Medical Condition / Disease',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.medical_services),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., Surgery, Accident, Anemia, etc.',
                        ),
                        maxLines: 2,
                        validator: _validateDisease,
                      ),
                      SizedBox(height: 14),

                      // Urgency Level
                      DropdownButtonFormField<String>(
                        value: urgencyLevel,
                        decoration: InputDecoration(
                          labelText: 'Urgency Level',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.warning),
                        ),
                        items: urgencyLevels
                            .map((level) => DropdownMenuItem(
                          value: level,
                          child: Row(
                            children: [
                              Icon(
                                _getUrgencyIcon(level),
                                color: _getUrgencyColor(level),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(level),
                            ],
                          ),
                        ))
                            .toList(),
                        onChanged: (val) => setState(() => urgencyLevel = val),
                        validator: (v) => v == null ? "Please select urgency level" : null,
                      ),
                    ],
                  ),
                ),
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

  IconData _getUrgencyIcon(String level) {
    switch (level) {
      case 'Low': return Icons.info;
      case 'Medium': return Icons.warning;
      case 'High': return Icons.error;
      case 'Critical': return Icons.emergency;
      default: return Icons.info;
    }
  }

  Color _getUrgencyColor(String level) {
    switch (level) {
      case 'Low': return Colors.blue;
      case 'Medium': return Colors.orange;
      case 'High': return Colors.orangeAccent;
      case 'Critical': return Colors.red;
      default: return Colors.grey;
    }
  }
}