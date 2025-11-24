import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BloodBankProfileCompletionScreen extends StatefulWidget {
  @override
  State<BloodBankProfileCompletionScreen> createState() => _BloodBankProfileCompletionScreenState();
}

class _BloodBankProfileCompletionScreenState extends State<BloodBankProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController bankNameCtrl = TextEditingController();
  final TextEditingController regNoCtrl = TextEditingController();
  final TextEditingController contactPersonCtrl = TextEditingController();
  final TextEditingController designationCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController cityCtrl = TextEditingController();
  final TextEditingController hoursCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController emergencyPhoneCtrl = TextEditingController();

  List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  List<String> selectedBloodTypes = [];
  String? bloodBankType;
  bool available24Hours = false;
  bool acceptsDonations = true;

  final List<String> bloodBankTypes = [
    'Government Blood Bank',
    'Private Blood Bank',
    'Hospital Blood Bank',
    'Red Crescent Blood Bank',
    'Other'
  ];

  double get completionScore {
    int filled = 0;
    if (bankNameCtrl.text.isNotEmpty) filled++;
    if (regNoCtrl.text.isNotEmpty) filled++;
    if (contactPersonCtrl.text.isNotEmpty) filled++;
    if (designationCtrl.text.isNotEmpty) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (emailCtrl.text.isNotEmpty) filled++;
    if (addressCtrl.text.isNotEmpty) filled++;
    if (cityCtrl.text.isNotEmpty) filled++;
    if (hoursCtrl.text.isNotEmpty) filled++;
    if (bloodBankType != null) filled++;
    if (selectedBloodTypes.isNotEmpty) filled++;
    if (emergencyPhoneCtrl.text.isNotEmpty) filled++;
    // available24Hours and acceptsDonations are always present (checkboxes)
    return (filled + 2) / 14;
  }

  // Validation functions
  String? _validateBankName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter blood bank name';
    }
    if (value.length < 3) {
      return 'Blood bank name must be at least 3 characters';
    }
    return null;
  }

  String? _validateRegistration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter registration number';
    }
    if (value.length < 5) {
      return 'Registration number must be at least 5 characters';
    }
    return null;
  }

  String? _validateContactPerson(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter contact person name';
    }
    if (value.length < 3) {
      return 'Contact person name must be at least 3 characters';
    }
    return null;
  }

  String? _validateDesignation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter designation';
    }
    if (value.length < 3) {
      return 'Designation must be at least 3 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }
    final phoneRegex = RegExp(r'^03[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter valid Pakistani phone number (03XXXXXXXXX)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter email address';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter address';
    }
    if (value.length < 10) {
      return 'Address must be at least 10 characters';
    }
    return null;
  }

  String? _validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter city';
    }
    if (value.length < 2) {
      return 'City name must be at least 2 characters';
    }
    return null;
  }

  String? _validateOperatingHours(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter operating hours';
    }
    return null;
  }

  String? _validateEmergencyPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter emergency phone number';
    }
    final phoneRegex = RegExp(r'^03[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter valid Pakistani phone number (03XXXXXXXXX)';
    }
    if (value == phoneCtrl.text) {
      return 'Emergency phone cannot be same as main phone';
    }
    return null;
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please fix all errors before saving")));
      return;
    }

    if (selectedBloodTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select at least one blood type")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not logged in. Please log in again.");
      }

      // Initialize inventory with selected blood types
      Map<String, dynamic> inventory = {};
      for (String bloodType in selectedBloodTypes) {
        inventory[bloodType] = {
          'units': 0,
          'lastUpdated': FieldValue.serverTimestamp(),
          'status': 'Available'
        };
      }

      final data = {
        'bloodBankName': bankNameCtrl.text.trim(),
        'registrationNo': regNoCtrl.text.trim(),
        'contactPerson': contactPersonCtrl.text.trim(),
        'designation': designationCtrl.text.trim(),
        'phoneNumber': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'operatingHours': hoursCtrl.text.trim(),
        'bloodBankType': bloodBankType,
        'availableBloodTypes': selectedBloodTypes,
        'emergencyPhone': emergencyPhoneCtrl.text.trim(),
        'available24Hours': available24Hours,
        'acceptsDonations': acceptsDonations,
        'inventory': inventory,
        'profileCompleted': completionScore == 1.0,
        'userType': 'blood_bank',
        'isVerified': false, // Admin will verify later
        'totalRequests': 0,
        'activeRequests': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print("Saving blood bank profile for UID: ${user.uid}");
      print("Blood bank data: $data");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      print("Blood bank profile successfully saved!");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completionScore == 1.0
              ? "Blood Bank Profile Completed Successfully!"
              : "Profile Saved Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back only if profile is 100% complete
      if (completionScore == 1.0) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      print("Error saving blood bank profile: $e");
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
        title: Text('Complete Blood Bank Profile'),
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

              // Blood Bank Basic Information Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blood Bank Information',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

                      // Blood Bank Name
                      TextFormField(
                        controller: bankNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Blood Bank Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.local_hospital),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: _validateBankName,
                      ),
                      SizedBox(height: 14),

                      // Blood Bank Type
                      DropdownButtonFormField<String>(
                        value: bloodBankType,
                        decoration: InputDecoration(
                          labelText: 'Blood Bank Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: bloodBankTypes
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (val) => setState(() => bloodBankType = val),
                        validator: (v) => v == null ? "Please select blood bank type" : null,
                      ),
                      SizedBox(height: 14),

                      // Registration Number
                      TextFormField(
                        controller: regNoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Registration/License No.',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.confirmation_num),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., PBTA-12345',
                        ),
                        validator: _validateRegistration,
                      ),
                      SizedBox(height: 14),

                      // Address
                      TextFormField(
                        controller: addressCtrl,
                        decoration: InputDecoration(
                          labelText: 'Blood Bank Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.location_on),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        maxLines: 2,
                        validator: _validateAddress,
                      ),
                      SizedBox(height: 14),

                      // City
                      TextFormField(
                        controller: cityCtrl,
                        decoration: InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.location_city),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: _validateCity,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Contact Information Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

                      // Contact Person
                      TextFormField(
                        controller: contactPersonCtrl,
                        decoration: InputDecoration(
                          labelText: 'Contact Person Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.person),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: _validateContactPerson,
                      ),
                      SizedBox(height: 14),

                      // Designation
                      TextFormField(
                        controller: designationCtrl,
                        decoration: InputDecoration(
                          labelText: 'Designation',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.badge),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., Blood Bank Manager, Technician',
                        ),
                        validator: _validateDesignation,
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

                      // Emergency Phone
                      TextFormField(
                        controller: emergencyPhoneCtrl,
                        decoration: InputDecoration(
                          labelText: 'Emergency Phone Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.contact_emergency),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: '03XXXXXXXXX',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: _validateEmergencyPhone,
                      ),
                      SizedBox(height: 14),

                      // Email
                      TextFormField(
                        controller: emailCtrl,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.email),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Blood Bank Operations Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blood Bank Operations',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

                      // Operating Hours
                      TextFormField(
                        controller: hoursCtrl,
                        decoration: InputDecoration(
                          labelText: 'Operating Hours',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.access_time),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., 9:00 AM - 5:00 PM, Monday to Friday',
                        ),
                        validator: _validateOperatingHours,
                      ),
                      SizedBox(height: 14),

                      // 24/7 Availability
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: available24Hours,
                        onChanged: (v) => setState(() => available24Hours = v!),
                        title: Text("Available 24/7"),
                        subtitle: Text("Blood bank operates 24 hours"),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Color(0xFF67D5B5),
                      ),
                      SizedBox(height: 8),

                      // Accepts Donations
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: acceptsDonations,
                        onChanged: (v) => setState(() => acceptsDonations = v!),
                        title: Text("Accepts Blood Donations"),
                        subtitle: Text("Blood bank accepts donations from donors"),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Color(0xFF67D5B5),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Available Blood Types Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Blood Types',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Select all blood types that your blood bank handles:',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
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
                            selectedColor: Color(0xFF67D5B5).withOpacity(0.3),
                            checkmarkColor: Colors.white,
                            backgroundColor: Colors.grey[200],
                            labelStyle: TextStyle(
                              color: selectedBloodTypes.contains(type) ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      if (selectedBloodTypes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            "Please select at least one blood type",
                            style: TextStyle(color: Colors.red[700], fontSize: 12),
                          ),
                        ),
                      if (selectedBloodTypes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            "Selected: ${selectedBloodTypes.join(', ')}",
                            style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
                          ),
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
}