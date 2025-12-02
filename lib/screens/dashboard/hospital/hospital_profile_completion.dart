import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/admin_notification_service.dart';

class HospitalProfileCompletionScreen extends StatefulWidget {
  @override
  State<HospitalProfileCompletionScreen> createState() =>
      _HospitalProfileCompletionScreenState();
}

class _HospitalProfileCompletionScreenState
    extends State<HospitalProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGettingLocation = false;

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

  // Location variables
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _locationAddress = 'No location selected';

  bool hasBloodBank = false;
  bool available24Hours = false;
  String? contactMethod;
  String? hospitalType;

  final List<String> contactMethods = [
    'Call',
    'SMS',
    'Email',
    'App Notification'
  ];
  final List<String> hospitalTypes = [
    'Government Hospital',
    'Private Hospital',
    'Teaching Hospital',
    'Specialized Hospital',
    'Community Health Center',
    'Clinic'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            hospitalNameCtrl.text = data['hospitalName'] ?? '';
            registrationCtrl.text = data['registrationNo'] ?? '';
            contactPersonCtrl.text = data['contactPerson'] ?? '';
            designationCtrl.text = data['designation'] ?? '';
            phoneCtrl.text = data['phoneNumber'] ?? '';
            emailCtrl.text = data['email'] ?? '';
            addressCtrl.text = data['address'] ?? '';
            cityCtrl.text = data['city'] ?? '';
            emergencyPhoneCtrl.text = data['emergencyPhone'] ?? '';
            hospitalType = data['hospitalType'];
            contactMethod = data['preferredContactMethod'];
            hasBloodBank = data['hasBloodBank'] ?? false;
            available24Hours = data['available24Hours'] ?? false;

            // Load location data
            _selectedLatitude = data['latitude'];
            _selectedLongitude = data['longitude'];
            _locationAddress =
                data['locationAddress'] ?? 'No location selected';
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Updated completion score including location
  double get completionScore {
    int filled = 0;
    int total = 14; // Total mandatory fields

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
    // Location is mandatory
    if (_selectedLatitude != null && _selectedLongitude != null) filled++;
    // Checkboxes are always counted
    filled += 2;

    return filled / total;
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppSnackbar.showWarning(
            context,
            'Location Services Disabled',
            subtitle: 'Please enable location services',
          );
        }
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          if (mounted) {
            AppSnackbar.showWarning(
              context,
              'Permission Denied',
              subtitle: 'Location permission is required',
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            'Permission Denied Forever',
            subtitle: 'Please enable location in app settings',
          );
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        setState(() {
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
          _locationAddress =
              address.isNotEmpty ? address : 'Location selected';

          // Auto-fill city if empty
          if (cityCtrl.text.isEmpty && placemark.locality != null) {
            cityCtrl.text = placemark.locality!;
          }
          
          // Auto-fill address if empty
          if (addressCtrl.text.isEmpty && address.isNotEmpty) {
            addressCtrl.text = address;
          }
        });

        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Location Captured',
            subtitle: _locationAddress,
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Location Error',
          subtitle: e.toString(),
        );
      }
    } finally {
      setState(() => _isGettingLocation = false);
    }
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
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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
      AppSnackbar.showError(
        context,
        'Validation Error',
        subtitle: 'Please fix all errors before saving',
      );
      return;
    }

    // Check if location is set
    if (_selectedLatitude == null || _selectedLongitude == null) {
      AppSnackbar.showWarning(
        context,
        'Location Required',
        subtitle: 'Please capture your hospital location',
      );
      return;
    }

    setState(() => _isSaving = true);

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

        // Location data - MANDATORY
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'locationAddress': _locationAddress,
        'location': _selectedLatitude != null && _selectedLongitude != null
            ? GeoPoint(_selectedLatitude!, _selectedLongitude!)
            : null,

        'profileCompleted': isNowCompleted,
        'userType': 'hospital',
        'role': 'hospital', // Ensure role is set for queries
        'isActive': isNowCompleted, // Allow hospital to make requests when profile is complete
        'isVerified': false, // Admin needs to verify separately
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
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hospital Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: BloodAppTheme.background,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(
                  BloodAppTheme.primary,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress Indicator - Matching Blood Bank style
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: completionScore == 1.0
                                  ? const LinearGradient(
                                      colors: [
                                        BloodAppTheme.success,
                                        Color(0xFF4CAF50),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        BloodAppTheme.primary,
                                        BloodAppTheme.primaryDark,
                                      ],
                                    ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    value: completionScore,
                                    strokeWidth: 8,
                                    color: Colors.white.withOpacity(0.3),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                                Text(
                                  '${(completionScore * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Profile ${(completionScore * 100).round()}% Complete',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: completionScore == 1.0
                                  ? BloodAppTheme.success
                                  : BloodAppTheme.textPrimary,
                            ),
                          ),
                          if (completionScore < 1.0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Complete all fields to finish profile',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Hospital Basic Information Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: BloodAppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.local_hospital,
                                    color: BloodAppTheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Hospital Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: BloodAppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: hospitalNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Hospital Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.local_hospital),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: _validateHospitalName,
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              value: hospitalType,
                              decoration: InputDecoration(
                                labelText: 'Hospital Type',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.category),
                              ),
                              items: hospitalTypes
                                  .map((type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => hospitalType = val),
                              validator: (v) =>
                                  v == null ? "Please select hospital type" : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: registrationCtrl,
                              decoration: InputDecoration(
                                labelText: 'Registration/License No.',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.confirmation_num),
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'e.g., PMDC-12345',
                              ),
                              validator: _validateRegistration,
                            ),
                            const SizedBox(height: 14),

                            // Location Picker Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hospital Location *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    side: BorderSide(
                                      color: _selectedLatitude == null
                                          ? Colors.red
                                          : Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: _selectedLatitude != null
                                                  ? Colors.green
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _locationAddress,
                                                style: TextStyle(
                                                  color: _selectedLatitude != null
                                                      ? Colors.black87
                                                      : Colors.grey,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            icon: _isGettingLocation
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.my_location,
                                                    size: 18,
                                                  ),
                                            label: Text(
                                              _selectedLatitude != null
                                                  ? 'Update Location'
                                                  : 'Get Current Location',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _selectedLatitude != null
                                                  ? Colors.orange
                                                  : BloodAppTheme.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                            ),
                                            onPressed: _isGettingLocation
                                                ? null
                                                : _getCurrentLocation,
                                          ),
                                        ),
                                        if (_selectedLatitude != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Coordinates: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                if (_selectedLatitude == null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, left: 8),
                                    child: Text(
                                      'Please select your location using the location button',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: addressCtrl,
                              decoration: InputDecoration(
                                labelText: 'Hospital Address',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.location_on),
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Full address will be auto-filled when you select location',
                              ),
                              maxLines: 2,
                              validator: _validateAddress,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: cityCtrl,
                              decoration: InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.location_city),
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'City will be auto-filled when you select location',
                              ),
                              validator: _validateCity,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Contact Information Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: BloodAppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.contact_phone,
                                    color: BloodAppTheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Contact Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: BloodAppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: contactPersonCtrl,
                              decoration: InputDecoration(
                                labelText: 'Contact Person Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.person),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: _validateContactPerson,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: designationCtrl,
                              decoration: InputDecoration(
                                labelText: 'Designation',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.badge),
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'e.g., Blood Bank Officer, Administrator',
                              ),
                              validator: _validateDesignation,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: phoneCtrl,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.phone),
                                filled: true,
                                fillColor: Colors.white,
                                hintText: '03XXXXXXXXX',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: _validatePhone,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: emergencyPhoneCtrl,
                              decoration: InputDecoration(
                                labelText: 'Emergency Phone Number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.contact_emergency),
                                filled: true,
                                fillColor: Colors.white,
                                hintText: '03XXXXXXXXX',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: _validateEmergencyPhone,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: emailCtrl,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                prefixIcon: const Icon(Icons.email),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              value: contactMethod,
                              decoration: InputDecoration(
                                labelText: 'Preferred Contact Method',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: const Icon(Icons.contact_mail),
                              ),
                              items: contactMethods
                                  .map((method) => DropdownMenuItem(
                                        value: method,
                                        child: Text(method),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => contactMethod = val),
                              validator: (v) =>
                                  v == null ? "Please select contact method" : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hospital Facilities Section
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: BloodAppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.settings,
                                    color: BloodAppTheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Hospital Facilities',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: BloodAppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: hasBloodBank,
                              onChanged: (v) => setState(() => hasBloodBank = v!),
                              title: const Text("Has Blood Bank Facility"),
                              subtitle: const Text("Hospital has dedicated blood bank"),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: BloodAppTheme.primary,
                            ),
                            const SizedBox(height: 8),

                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: available24Hours,
                              onChanged: (v) =>
                                  setState(() => available24Hours = v!),
                              title: const Text("Available 24/7"),
                              subtitle: const Text("Hospital operates 24 hours"),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: BloodAppTheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(Icons.save_alt, color: Colors.white),
                      label: Text(
                        completionScore == 1.0
                            ? "Complete Profile"
                            : "Save Progress",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: completionScore == 1.0
                            ? BloodAppTheme.success
                            : BloodAppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _isSaving ? null : saveProfile,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    hospitalNameCtrl.dispose();
    registrationCtrl.dispose();
    contactPersonCtrl.dispose();
    designationCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    cityCtrl.dispose();
    emailCtrl.dispose();
    emergencyPhoneCtrl.dispose();
    super.dispose();
  }
}
