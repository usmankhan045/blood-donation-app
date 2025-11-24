import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminProfileCompletionScreen extends StatefulWidget {
  @override
  State<AdminProfileCompletionScreen> createState() => _AdminProfileCompletionScreenState();
}

class _AdminProfileCompletionScreenState extends State<AdminProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController designationCtrl = TextEditingController();
  final TextEditingController departmentCtrl = TextEditingController();
  final TextEditingController adminIdCtrl = TextEditingController();

  String? email;
  String? adminLevel;

  final List<String> adminLevels = [
    'Super Admin',
    'System Admin',
    'Content Moderator',
    'Support Admin'
  ];

  double get completionScore {
    int filled = 0;
    if (nameCtrl.text.isNotEmpty) filled++;
    if (phoneCtrl.text.isNotEmpty) filled++;
    if (designationCtrl.text.isNotEmpty) filled++;
    if (departmentCtrl.text.isNotEmpty) filled++;
    if (adminIdCtrl.text.isNotEmpty) filled++;
    if (adminLevel != null) filled++;
    if (email != null && email!.isNotEmpty) filled++;
    return filled / 7;
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
    final phoneRegex = RegExp(r'^03[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Enter valid Pakistani phone number (03XXXXXXXXX)';
    }
    return null;
  }

  String? _validateDesignation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your designation';
    }
    if (value.length < 3) {
      return 'Designation must be at least 3 characters';
    }
    return null;
  }

  String? _validateDepartment(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your department';
    }
    if (value.length < 2) {
      return 'Department must be at least 2 characters';
    }
    return null;
  }

  String? _validateAdminId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter admin ID';
    }
    if (value.length < 4) {
      return 'Admin ID must be at least 4 characters';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    email = user?.email ?? '';
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

      final data = {
        'fullName': nameCtrl.text.trim(),
        'phoneNumber': phoneCtrl.text.trim(),
        'email': email ?? '',
        'designation': designationCtrl.text.trim(),
        'department': departmentCtrl.text.trim(),
        'adminId': adminIdCtrl.text.trim(),
        'adminLevel': adminLevel,
        'profileCompleted': completionScore == 1.0,
        'userType': 'admin',
        'isSuperAdmin': adminLevel == 'Super Admin',
        'permissions': _getAdminPermissions(adminLevel),
        'totalUsersVerified': 0,
        'totalRequestsMonitored': 0,
        'lastLogin': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      print("Saving admin profile for UID: ${user.uid}");
      print("Admin data: $data");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      print("Admin profile successfully saved!");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completionScore == 1.0
              ? "Admin Profile Completed Successfully!"
              : "Profile Saved Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back only if profile is 100% complete
      if (completionScore == 1.0) {
        Navigator.pop(context, true);
      }

    } catch (e) {
      print("Error saving admin profile: $e");
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

  List<String> _getAdminPermissions(String? level) {
    switch (level) {
      case 'Super Admin':
        return [
          'verify_users',
          'manage_users',
          'view_reports',
          'system_settings',
          'manage_admins',
          'content_moderation'
        ];
      case 'System Admin':
        return [
          'verify_users',
          'manage_users',
          'view_reports',
          'system_settings'
        ];
      case 'Content Moderator':
        return [
          'verify_users',
          'content_moderation',
          'view_reports'
        ];
      case 'Support Admin':
        return [
          'verify_users',
          'view_reports'
        ];
      default:
        return ['verify_users'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Admin Profile'),
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

              // Admin Basic Information Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Information',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

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

                      // Admin ID
                      TextFormField(
                        controller: adminIdCtrl,
                        decoration: InputDecoration(
                          labelText: 'Admin ID',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.badge),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., ADM-001',
                        ),
                        validator: _validateAdminId,
                      ),
                      SizedBox(height: 14),

                      // Designation
                      TextFormField(
                        controller: designationCtrl,
                        decoration: InputDecoration(
                          labelText: 'Designation',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.admin_panel_settings),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., System Administrator, Moderator',
                        ),
                        validator: _validateDesignation,
                      ),
                      SizedBox(height: 14),

                      // Department
                      TextFormField(
                        controller: departmentCtrl,
                        decoration: InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.business),
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'e.g., IT, Operations, Support',
                        ),
                        validator: _validateDepartment,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Contact & Admin Level Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact & Access Level',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF67D5B5)),
                      ),
                      SizedBox(height: 16),

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

                      // Email (Disabled)
                      TextFormField(
                        enabled: false,
                        initialValue: email ?? '',
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          prefixIcon: Icon(Icons.email),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                      SizedBox(height: 14),

                      // Admin Level
                      DropdownButtonFormField<String>(
                        value: adminLevel,
                        decoration: InputDecoration(
                          labelText: 'Admin Level',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.security),
                        ),
                        items: adminLevels
                            .map((level) => DropdownMenuItem(
                          value: level,
                          child: Row(
                            children: [
                              Icon(
                                _getAdminLevelIcon(level),
                                color: _getAdminLevelColor(level),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(level),
                            ],
                          ),
                        ))
                            .toList(),
                        onChanged: (val) => setState(() => adminLevel = val),
                        validator: (v) => v == null ? "Please select admin level" : null,
                      ),
                      SizedBox(height: 8),

                      // Permissions Preview
                      if (adminLevel != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permissions:',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _getAdminPermissions(adminLevel).map((permission) {
                                return Chip(
                                  label: Text(
                                    permission.replaceAll('_', ' '),
                                    style: TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                  backgroundColor: Color(0xFF67D5B5),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ],
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

  IconData _getAdminLevelIcon(String level) {
    switch (level) {
      case 'Super Admin': return Icons.admin_panel_settings;
      case 'System Admin': return Icons.settings;
      case 'Content Moderator': return Icons.add_moderator_outlined;
      case 'Support Admin': return Icons.support_agent;
      default: return Icons.person;
    }
  }

  Color _getAdminLevelColor(String level) {
    switch (level) {
      case 'Super Admin': return Colors.red;
      case 'System Admin': return Colors.orange;
      case 'Content Moderator': return Colors.blue;
      case 'Support Admin': return Colors.green;
      default: return Colors.grey;
    }
  }
}