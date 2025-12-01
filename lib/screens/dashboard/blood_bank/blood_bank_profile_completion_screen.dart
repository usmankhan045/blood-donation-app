import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/admin_notification_service.dart';

class BloodBankProfileCompletionScreen extends StatefulWidget {
  @override
  State<BloodBankProfileCompletionScreen> createState() =>
      _BloodBankProfileCompletionScreenState();
}

class _BloodBankProfileCompletionScreenState
    extends State<BloodBankProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGettingLocation = false;

  // Text Editing Controllers
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

  // Location variables
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _locationAddress = 'No location selected';
  Position? _currentPosition;

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
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    _checkLocationPermission();
  }

  // Check location permission
  Future<void> _checkLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location permission is required for profile completion',
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking location permission: $e');
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enable location services')),
        );
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permission is required')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permissions are permanently denied. Please enable them in app settings.',
            ),
          ),
        );
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
          _currentPosition = position;
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
          _locationAddress =
              address.isNotEmpty
                  ? address
                  : 'Location selected (address not available)';
        });

        // Auto-fill city if empty
        if (cityCtrl.text.isEmpty && placemark.locality != null) {
          cityCtrl.text = placemark.locality!;
        }

        // Auto-fill address if empty
        if (addressCtrl.text.isEmpty && address.isNotEmpty) {
          addressCtrl.text = address;
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  // Load existing profile data
  Future<void> _loadExistingProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            bankNameCtrl.text = data['bloodBankName'] ?? '';
            regNoCtrl.text = data['registrationNo'] ?? '';
            contactPersonCtrl.text = data['contactPerson'] ?? '';
            designationCtrl.text = data['designation'] ?? '';
            phoneCtrl.text = data['phoneNumber'] ?? '';
            emailCtrl.text = data['email'] ?? '';
            addressCtrl.text = data['address'] ?? '';
            cityCtrl.text = data['city'] ?? '';
            hoursCtrl.text = data['operatingHours'] ?? '';
            emergencyPhoneCtrl.text = data['emergencyPhone'] ?? '';
            bloodBankType = data['bloodBankType'];
            available24Hours = data['available24Hours'] ?? false;
            acceptsDonations = data['acceptsDonations'] ?? true;
            selectedBloodTypes = List<String>.from(
              data['availableBloodTypes'] ?? [],
            );

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

  // 🔥 FIXED: Calculate completion score - checkboxes are now optional
  double get completionScore {
    int filled = 0;

    // Mandatory fields (12 fields)
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
    if (_selectedLatitude != null && _selectedLongitude != null)
      filled++; // Location field

    // Checkboxes are optional, so we don't count them in the total
    int totalMandatoryFields = 13; // 12 text fields + 1 location field

    return filled / totalMandatoryFields;
  }

  // Validation functions (unchanged)
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
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
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

  // Validate location
  String? _validateLocation() {
    if (_selectedLatitude == null || _selectedLongitude == null) {
      return 'Please select your location using the location button';
    }
    return null;
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fix all errors before saving")),
      );
      return;
    }

    if (selectedBloodTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select at least one blood type")),
      );
      return;
    }

    // Validate location
    if (_validateLocation() != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_validateLocation()!)));
      return;
    }

    setState(() => _isSaving = true);

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
          'status': 'Available',
        };
      }

      // Check if this is a new profile or update
      final existingDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final isNewProfile =
          !existingDoc.exists ||
          (existingDoc.data()?['profileCompleted'] ?? false) == false;
      final wasCompleted = existingDoc.data()?['profileCompleted'] ?? false;
      final isNowCompleted = completionScore == 1.0;

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

        // Location data
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'locationAddress': _locationAddress,
        'geopoint':
            _selectedLatitude != null && _selectedLongitude != null
                ? GeoPoint(_selectedLatitude!, _selectedLongitude!)
                : null,

        'profileCompleted': isNowCompleted,
        'userType': 'blood_bank',
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
          role: 'blood_bank',
          name: bankNameCtrl.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving profile: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Blood Bank Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: BloodAppTheme.background,
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    BloodAppTheme.primary,
                  ),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
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
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient:
                                    completionScore == 1.0
                                        ? const LinearGradient(
                                          colors: [
                                            BloodAppTheme.success,
                                            BloodAppTheme.low,
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
                                    '${((completionScore) * 100).round()}%',
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
                              'Profile ${((completionScore) * 100).round()}% Complete',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color:
                                    completionScore == 1.0
                                        ? BloodAppTheme.success
                                        : BloodAppTheme.textPrimary,
                              ),
                            ),
                            if (completionScore < 1.0) ...[
                              SizedBox(height: 4),
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
                      SizedBox(height: 22),

                      // Blood Bank Basic Information Section
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
                                      color: BloodAppTheme.primary.withOpacity(
                                        0.1,
                                      ),
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
                                    'Blood Bank Information',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: BloodAppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              TextFormField(
                                controller: bankNameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Blood Bank Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.local_hospital),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: _validateBankName,
                              ),
                              SizedBox(height: 14),

                              DropdownButtonFormField<String>(
                                value: bloodBankType,
                                decoration: InputDecoration(
                                  labelText: 'Blood Bank Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items:
                                    bloodBankTypes
                                        .map(
                                          (type) => DropdownMenuItem(
                                            value: type,
                                            child: Text(type),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (val) =>
                                        setState(() => bloodBankType = val),
                                validator:
                                    (v) =>
                                        v == null
                                            ? "Please select blood bank type"
                                            : null,
                              ),
                              SizedBox(height: 14),

                              TextFormField(
                                controller: regNoCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Registration/License No.',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.confirmation_num),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'e.g., PBTA-12345',
                                ),
                                validator: _validateRegistration,
                              ),
                              SizedBox(height: 14),

                              // Location Picker Section
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Blood Bank Location *',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Card(
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                      side: BorderSide(
                                        color:
                                            _selectedLatitude == null
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
                                                color:
                                                    _selectedLatitude != null
                                                        ? Colors.green
                                                        : Colors.grey,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _locationAddress,
                                                  style: TextStyle(
                                                    color:
                                                        _selectedLatitude !=
                                                                null
                                                            ? Colors.black87
                                                            : Colors.grey,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),
                                          ElevatedButton.icon(
                                            icon:
                                                _isGettingLocation
                                                    ? SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                    : Icon(
                                                      Icons.my_location,
                                                      size: 18,
                                                    ),
                                            label: Text(
                                              _selectedLatitude != null
                                                  ? 'Update Location'
                                                  : 'Get Current Location',
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _selectedLatitude != null
                                                      ? Colors.orange
                                                      : Color(0xFF67D5B5),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                            ),
                                            onPressed:
                                                _isGettingLocation
                                                    ? null
                                                    : _getCurrentLocation,
                                          ),
                                          if (_selectedLatitude != null) ...[
                                            SizedBox(height: 8),
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
                                  if (_validateLocation() != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        left: 8,
                                      ),
                                      child: Text(
                                        _validateLocation()!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 14),

                              TextFormField(
                                controller: addressCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Blood Bank Address',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.location_on),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText:
                                      'Full address will be auto-filled when you select location',
                                ),
                                maxLines: 2,
                                validator: _validateAddress,
                              ),
                              SizedBox(height: 14),

                              TextFormField(
                                controller: cityCtrl,
                                decoration: InputDecoration(
                                  labelText: 'City',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.location_city),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText:
                                      'City will be auto-filled when you select location',
                                ),
                                validator: _validateCity,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Contact Information
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
                                      color: BloodAppTheme.primary.withOpacity(
                                        0.1,
                                      ),
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
                              SizedBox(height: 16),

                              TextFormField(
                                controller: contactPersonCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Contact Person Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.person),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator: _validateContactPerson,
                              ),
                              SizedBox(height: 14),

                              TextFormField(
                                controller: designationCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Designation',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.badge),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText:
                                      'e.g., Blood Bank Manager, Technician',
                                ),
                                validator: _validateDesignation,
                              ),
                              SizedBox(height: 14),

                              TextFormField(
                                controller: phoneCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.phone),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: '03XXXXXXXXX',
                                ),
                                keyboardType: TextInputType.phone,
                                validator: _validatePhone,
                              ),
                              SizedBox(height: 14),

                              TextFormField(
                                controller: emergencyPhoneCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Emergency Phone Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.contact_emergency),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: '03XXXXXXXXX',
                                ),
                                keyboardType: TextInputType.phone,
                                validator: _validateEmergencyPhone,
                              ),
                              SizedBox(height: 14),

                              TextFormField(
                                controller: emailCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
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

                      // Operations
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
                                      color: BloodAppTheme.primary.withOpacity(
                                        0.1,
                                      ),
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
                                    'Blood Bank Operations',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: BloodAppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              TextFormField(
                                controller: hoursCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Operating Hours',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  prefixIcon: Icon(Icons.access_time),
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText:
                                      'e.g., 9:00 AM - 5:00 PM, Monday to Friday',
                                ),
                                validator: _validateOperatingHours,
                              ),
                              SizedBox(height: 14),

                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: available24Hours,
                                onChanged:
                                    (v) =>
                                        setState(() => available24Hours = v!),
                                title: Text("Available 24/7"),
                                subtitle: Text("Blood bank operates 24 hours"),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: Color(0xFF67D5B5),
                              ),
                              SizedBox(height: 8),

                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: acceptsDonations,
                                onChanged:
                                    (v) =>
                                        setState(() => acceptsDonations = v!),
                                title: Text("Accepts Blood Donations"),
                                subtitle: Text(
                                  "Blood bank accepts donations from donors",
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: Color(0xFF67D5B5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Blood Types
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
                                      color: BloodAppTheme.primary.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.bloodtype,
                                      color: BloodAppTheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Available Blood Types',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: BloodAppTheme.textPrimary,
                                    ),
                                  ),
                                ],
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
                                children:
                                    bloodTypes.map((type) {
                                      return FilterChip(
                                        label: Text(type),
                                        selected: selectedBloodTypes.contains(
                                          type,
                                        ),
                                        onSelected: (bool selected) {
                                          setState(() {
                                            if (selected) {
                                              selectedBloodTypes.add(type);
                                            } else {
                                              selectedBloodTypes.remove(type);
                                            }
                                          });
                                        },
                                        selectedColor: Color(
                                          0xFF67D5B5,
                                        ).withOpacity(0.3),
                                        checkmarkColor: Colors.white,
                                        backgroundColor: Colors.grey[200],
                                        labelStyle: TextStyle(
                                          color:
                                              selectedBloodTypes.contains(type)
                                                  ? Colors.white
                                                  : Colors.black87,
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
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (selectedBloodTypes.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    "Selected: ${selectedBloodTypes.join(', ')}",
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Save Button
                      ElevatedButton.icon(
                        icon:
                            _isSaving
                                ? SizedBox(
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              completionScore == 1.0
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
    bankNameCtrl.dispose();
    regNoCtrl.dispose();
    contactPersonCtrl.dispose();
    designationCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    cityCtrl.dispose();
    hoursCtrl.dispose();
    emailCtrl.dispose();
    emergencyPhoneCtrl.dispose();
    super.dispose();
  }
}
