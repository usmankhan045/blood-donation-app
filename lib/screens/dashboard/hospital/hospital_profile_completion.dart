import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/admin_notification_service.dart';

class HospitalProfileCompletionScreen extends StatefulWidget {
  @override
  State<HospitalProfileCompletionScreen> createState() => _HospitalProfileCompletionScreenState();
}

class _HospitalProfileCompletionScreenState extends State<HospitalProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for text fields
  final TextEditingController hospitalNameCtrl = TextEditingController();
  final TextEditingController registrationCtrl = TextEditingController();
  final TextEditingController contactPersonCtrl = TextEditingController();
  final TextEditingController designationCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController cityCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController emergencyPhoneCtrl = TextEditingController();

  bool hasBloodBank = false;
  bool available24Hours = false;
  String? contactMethod;
  String? hospitalType;

  final List<String> contactMethods = ['Call', 'SMS', 'Email', 'App Notification'];
  final List<String> hospitalTypes = [
    'Government Hospital',
    'Private Hospital',
    'Teaching Hospital',
    'Specialized Hospital',
    'Community Health Center',
    'Clinic'
  ];

  double get completionScore {
    int filled = 0;
    if (hospitalNameCtrl.text.isNotEmpty) filled++;
    if (registrationCtrl.text.isNotEmpty) filled++;
    if (contactPersonCtrl.text.isNotEmpty) filled++;
    if (designationCtrl.text.isNotEmpty) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (emailCtrl.text.isNotEmpty) filled++;
    if (addressCtrl.text.isNotEmpty) filled++;
    if (cityCtrl.text.isNotEmpty) filled++;
    if (hospitalType != null) filled++;
    if (contactMethod != null) filled++;
    if (emergencyPhoneCtrl.text.isNotEmpty) filled++;
    // hasBloodBank and available24Hours are always present (checkboxes)
    return (filled + 2) / 13;
  }

  // Validation functions
  String? _validateHospitalName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter hospital name';
    }
    if (value.length < 3) {
      return 'Hospital name must be at least 3 characters';
    }
    return null;
  }

  String? _validateRegistration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter registration/license number';
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
      return 'Please enter hospital address';
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

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not logged in. Please log in again.");
      }

      // Check if this is a new profile or update
      final existingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isNewProfile = !existingDoc.exists || 
          (existingDoc.data()?['profileCompleted'] ?? false) == false;
      final wasCompleted = existingDoc.data()?['profileCompleted'] ?? false;
      final isNowCompleted = completionScore == 1.0;

      final data = {
        'hospitalName': hospitalNameCtrl.text.trim(),
        'registrationNo': registrationCtrl.text.trim(),
        'contactPerson': contactPersonCtrl.text.trim(),
        'designation': designationCtrl.text.trim(),
        'phoneNumber': phoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'hospitalType': hospitalType,
        'hasBloodBank': hasBloodBank,
        'available24Hours': available24Hours,
        'preferredContactMethod': contactMethod,
        'emergencyPhone': emergencyPhoneCtrl.text.trim(),
        'profileCompleted': isNowCompleted,
        'userType': 'hospital',
        'isVerified': false,
        'totalRequests': 0,
        'activeRequests': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add profileCompletedAt timestamp if just completed
      if (isNowCompleted && !wasCompleted) {
        data['profileCompletedAt'] = FieldValue.serverTimestamp();
      }

      // Preserve createdAt if it exists
      if (existingDoc.exists && existingDoc.data()?['createdAt'] != null) {
        data['createdAt'] = existingDoc.data()!['createdAt'];
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      // Notify admin if profile was completed or updated
      if (isNowCompleted || !isNewProfile) {
        await adminNotificationService.notifyProfileUpdate(
          userId: user.uid,
          userEmail: emailCtrl.text.trim(),
          role: 'hospital',
          name: hospitalNameCtrl.text.trim(),
          isNewProfile: isNewProfile && isNowCompleted,
        );
      }

      if (mounted) {
        if (isNowCompleted) {
          AppSnackbar.showSuccess(
            context,
            'Profile Completed Successfully!',
            subtitle: 'Your profile has been submitted for admin approval.',
          );
        } else {
          AppSnackbar.showSuccess(
            context,
            'Profile Saved Successfully!',
            subtitle: 'Continue filling to complete your profile.',
          );
        }
      }

      if (isNowCompleted) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      print("Error saving hospital profile: $e");
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Error saving profile',
          subtitle: e.toString(),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Hospital Profile'),
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

              // Hospital Basic Information Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hospital Information',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

                      // Hospital Name
                      TextFormField(
                        controller: hospitalNameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Hospital Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.local_hospital),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: _validateHospitalName,
                      ),
                      SizedBox(height: 14),

                      // Hospital Type
                      DropdownButtonFormField<String>(
                        value: hospitalType,
                        decoration: InputDecoration(
                          labelText: 'Hospital Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: hospitalTypes
                            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                            .toList(),
                        onChanged: (val) => setState(() => hospitalType = val),
                        validator: (v) => v == null ? "Please select hospital type" : null,
                      ),
                      SizedBox(height: 14),

                      // Registration Number
                      TextFormField(
                        controller: registrationCtrl,
                        decoration: InputDecoration(
                          labelText: 'Hospital Registration/License No.',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.confirmation_num),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., PMDC-12345',
                        ),
                        validator: _validateRegistration,
                      ),
                      SizedBox(height: 14),

                      // Address
                      TextFormField(
                        controller: addressCtrl,
                        decoration: InputDecoration(
                          labelText: 'Hospital Address',
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
                          hintText: 'e.g., Blood Bank Officer, Nurse, Administrator',
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
                      SizedBox(height: 14),

                      // Preferred Contact Method
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
                        validator: (v) => v == null ? "Please select contact method" : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Hospital Facilities Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hospital Facilities',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

                      // Blood Bank Availability
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: hasBloodBank,
                        onChanged: (v) => setState(() => hasBloodBank = v!),
                        title: Text("Has Blood Bank Facility"),
                        subtitle: Text("Hospital has dedicated blood bank"),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Color(0xFF67D5B5),
                      ),
                      SizedBox(height: 8),

                      // 24/7 Availability
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: available24Hours,
                        onChanged: (v) => setState(() => available24Hours = v!),
                        title: Text("Available 24/7"),
                        subtitle: Text("Hospital operates 24 hours"),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Color(0xFF67D5B5),
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