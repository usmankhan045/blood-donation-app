import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../../services/notification_service.dart';

/// 🏥 HOSPITAL BLOOD REQUEST SCREEN
/// Similar to recipient request but sends notifications ONLY to blood banks
class HospitalRequestScreen extends StatefulWidget {
  const HospitalRequestScreen({super.key});

  @override
  State<HospitalRequestScreen> createState() => _HospitalRequestScreenState();
}

class _HospitalRequestScreenState extends State<HospitalRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = BloodRequestRepository.instance;

  // Form fields
  String? _selectedBloodType;
  String _urgency = 'normal';
  int _units = 1;
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _patientNameCtrl = TextEditingController();

  // Location data
  double? _latitude;
  double? _longitude;
  String _address = '';
  String _city = '';
  bool _isGettingLocation = false;
  bool _hasLocation = false;

  // Hospital data
  String _hospitalName = '';
  String _hospitalPhone = '';

  bool _isLoading = true;
  bool _isSubmitting = false;

  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  @override
  void initState() {
    super.initState();
    _loadHospitalData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _patientNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _hospitalName = data['hospitalName'] ?? 'Hospital';
          _hospitalPhone = data['phoneNumber'] ?? '';
          _address = data['address'] ?? '';
          _city = data['city'] ?? '';

          // Use hospital's saved location as default
          if (data['location'] is GeoPoint) {
            final loc = data['location'] as GeoPoint;
            _latitude = loc.latitude;
            _longitude = loc.longitude;
            _hasLocation = true;
          } else if (data['latitude'] != null && data['longitude'] != null) {
            _latitude = data['latitude'];
            _longitude = data['longitude'];
            _hasLocation = true;
          }
        });
      }
    } catch (e) {
      print('Error loading hospital data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

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
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _address = address;
          _city = placemark.locality ?? _city;
          _hasLocation = true;
        });

        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            'Location Updated',
            subtitle: address,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Location Error', subtitle: e.toString());
      }
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBloodType == null) {
      AppSnackbar.showWarning(
        context,
        'Blood Type Required',
        subtitle: 'Please select a blood type',
      );
      return;
    }

    if (!_hasLocation || _latitude == null || _longitude == null) {
      AppSnackbar.showWarning(
        context,
        'Location Required',
        subtitle: 'Please confirm your location',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Create request - pass requesterType: 'hospital' to skip donor matching
      final requestId = await _repo.createRequest(
        requesterId: user.uid,
        requesterName: _hospitalName,
        city: _city,
        bloodType: _selectedBloodType!,
        urgency: _urgency,
        units: _units,
        location: GeoPoint(_latitude!, _longitude!),
        address: _address,
        hospital: _hospitalName,
        notes: _notesCtrl.text.isNotEmpty
            ? 'Patient: ${_patientNameCtrl.text}\n${_notesCtrl.text}'
            : 'Patient: ${_patientNameCtrl.text}',
        phone: _hospitalPhone,
        searchRadius: _urgency == 'emergency' ? 50 : 25,
        requesterType: 'hospital', // 🏥 This skips donor matching - blood banks only
      );

      // Mark request as hospital request in document
      await FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(requestId)
          .update({
        'requesterType': 'hospital',
        'hospitalId': user.uid,
        'hospitalName': _hospitalName,
      });

      // 🔥 CRITICAL: Send notifications ONLY to blood banks (not donors)
      final notificationResult =
          await NotificationService.instance.notifyBloodBanksOnly(
        await _repo.getRequestById(requestId) ??
            (throw Exception('Request not found')),
      );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Request Submitted Successfully! 🏥',
          subtitle:
              '${notificationResult['bloodBanksNotified']} blood banks notified',
        );

        // Navigate back after short delay
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Failed to Submit Request',
          subtitle: e.toString(),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('New Blood Request'),
          backgroundColor: BloodAppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      appBar: AppBar(
        title: const Text(
          'New Blood Request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hospital Info Card
              _buildHospitalInfoCard(),
              const SizedBox(height: 20),

              // Info Banner
              _buildInfoBanner(),
              const SizedBox(height: 20),

              // Blood Type Selection
              _buildBloodTypeSelector(),
              const SizedBox(height: 20),

              // Urgency Selection
              _buildUrgencySelector(),
              const SizedBox(height: 20),

              // Units Counter
              _buildUnitsCounter(),
              const SizedBox(height: 20),

              // Patient Name
              _buildPatientNameField(),
              const SizedBox(height: 20),

              // Location Card
              _buildLocationCard(),
              const SizedBox(height: 20),

              // Notes Field
              _buildNotesField(),
              const SizedBox(height: 24),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_hospital,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hospitalName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _city.isNotEmpty ? _city : 'Location not set',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BloodAppTheme.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BloodAppTheme.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: BloodAppTheme.info,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hospital requests are sent only to blood banks for faster response.',
              style: TextStyle(
                color: BloodAppTheme.info,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BloodAppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.water_drop, color: BloodAppTheme.accent),
              ),
              const SizedBox(width: 12),
              const Text(
                'Blood Type Required',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: _bloodTypes.map((type) {
              final isSelected = _selectedBloodType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedBloodType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              BloodAppTheme.accent,
                              BloodAppTheme.accentDark
                            ],
                          )
                        : null,
                    color: isSelected ? null : BloodAppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? BloodAppTheme.accent
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: BloodAppTheme.accent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      type,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color:
                            isSelected ? Colors.white : BloodAppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BloodAppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.priority_high,
                    color: BloodAppTheme.warning),
              ),
              const SizedBox(width: 12),
              const Text(
                'Urgency Level',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildUrgencyChip('normal', 'Normal', BloodAppTheme.success),
              const SizedBox(width: 10),
              _buildUrgencyChip('high', 'Urgent', BloodAppTheme.warning),
              const SizedBox(width: 10),
              _buildUrgencyChip('emergency', 'Emergency', BloodAppTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyChip(String value, String label, Color color) {
    final isSelected = _urgency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgency = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitsCounter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BloodAppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2, color: BloodAppTheme.primary),
          ),
          const SizedBox(width: 12),
          const Text(
            'Units Required',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: BloodAppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _units > 1
                      ? () => setState(() => _units--)
                      : null,
                  icon: const Icon(Icons.remove),
                  color: BloodAppTheme.primary,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_units',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BloodAppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _units < 10
                      ? () => setState(() => _units++)
                      : null,
                  icon: const Icon(Icons.add),
                  color: BloodAppTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientNameField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BloodAppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: BloodAppTheme.info),
              ),
              const SizedBox(width: 12),
              const Text(
                'Patient Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _patientNameCtrl,
            decoration: InputDecoration(
              labelText: 'Patient Name',
              hintText: 'Enter patient name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: BloodAppTheme.surface,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter patient name';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _hasLocation
                      ? BloodAppTheme.success.withOpacity(0.1)
                      : BloodAppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _hasLocation ? Icons.check_circle : Icons.location_on,
                  color:
                      _hasLocation ? BloodAppTheme.success : BloodAppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hospital Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasLocation ? _address : 'Location not set',
                      style: TextStyle(
                        fontSize: 12,
                        color: BloodAppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isGettingLocation
                    ? 'Getting Location...'
                    : _hasLocation
                        ? 'Update Location'
                        : 'Get Location',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: BloodAppTheme.primary,
                side: const BorderSide(color: BloodAppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BloodAppTheme.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.note, color: BloodAppTheme.textHint),
              ),
              const SizedBox(width: 12),
              const Text(
                'Additional Notes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: BloodAppTheme.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any additional information...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: BloodAppTheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitRequest,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send, color: Colors.white),
        label: Text(
          _isSubmitting ? 'Submitting Request...' : 'Submit Request to Blood Banks',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: BloodAppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}

