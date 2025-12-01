import 'package:blood_donation_app/screens/common/pick_location_osm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/blood_request_model.dart';
import '../../../providers/request_provider.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../../services/notification_service.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';

class RecipientRequestScreen extends StatefulWidget {
  const RecipientRequestScreen({super.key});

  @override
  State<RecipientRequestScreen> createState() => _RecipientRequestScreenState();
}

class _RecipientRequestScreenState extends State<RecipientRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _repo = BloodRequestRepository.instance;

  final _hospitalCtr = TextEditingController();
  final _notesCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _recipientNameCtr = TextEditingController();

  String _bloodType = 'A+';
  String _urgency = 'normal';
  int _units = 1;
  DateTime? _neededBy;
  int _searchRadius = 10;

  double? _pickedLat;
  double? _pickedLng;
  String _pickedAddress = '';

  bool _submitting = false;

  final _bloodTypes = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final _urgencies = const ['low', 'normal', 'high', 'emergency'];

  @override
  void dispose() {
    _hospitalCtr.dispose();
    _notesCtr.dispose();
    _phoneCtr.dispose();
    _recipientNameCtr.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _neededBy ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: BloodAppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _neededBy = picked);
  }

  Future<void> _openMap() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PickLocationScreen()),
    );

    if (result != null) {
      setState(() {
        _pickedLat = (result['lat'] as num).toDouble();
        _pickedLng = (result['lng'] as num).toDouble();
        _pickedAddress = (result['address'] as String?)?.trim() ?? '';
      });
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_pickedLat == null || _pickedLng == null) {
      AppSnackbar.showWarning(
        context,
        'Location Required',
        subtitle: 'Please pick a location on the map',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final requesterName = (userDoc.data()?['fullName'] ?? userDoc.data()?['name'] ?? '') as String? ?? '';

      final request = BloodRequest(
        id: '',
        requesterId: user.uid,
        requesterName: requesterName,
        bloodType: _bloodType,
        units: _units,
        urgency: _urgency,
        city: 'Abbottabad',
        address: _pickedAddress,
        hospital: _hospitalCtr.text.trim(),
        notes: _notesCtr.text.trim(),
        phone: _phoneCtr.text.trim(),
        location: GeoPoint(_pickedLat!, _pickedLng!),
        status: 'pending',
        neededBy: _neededBy,
        searchRadius: _searchRadius,
        latitude: _pickedLat!,
        longitude: _pickedLng!,
        potentialDonors: [],
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final requestId = await _repo.createRequest(
        requesterId: request.requesterId,
        requesterName: request.requesterName,
        city: request.city,
        bloodType: request.bloodType,
        urgency: request.urgency,
        units: request.units,
        location: request.location!,
        address: request.address,
        hospital: request.hospital,
        notes: request.notes,
        phone: request.phone,
        neededBy: request.neededBy,
        searchRadius: request.searchRadius,
        expirationMinutes: 60,
      );

      final createdRequest = request.copyWith(id: requestId);

      if (!mounted) return;

      final notificationResults = await NotificationService.instance.notifyAll(createdRequest);

      final donorsNotified = notificationResults['donorsNotified'] as int;
      final bloodBanksNotified = notificationResults['bloodBanksNotified'] as int;
      final totalNotified = notificationResults['totalNotified'] as int;

      final provider = Provider.of<RequestProvider>(context, listen: false);
      await provider.fetchMyRequests();

      if (mounted) {
        // Show beautiful success dialog
        await _showSuccessDialog(donorsNotified, bloodBanksNotified, totalNotified);
      }
    } catch (e) {
      debugPrint('❌ Error creating blood request: $e');
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'Failed to create request',
        subtitle: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog(int donors, int banks, int total) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: BloodAppTheme.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: BloodAppTheme.success,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Created! 🎉',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: BloodAppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_bloodType Blood Request',
                style: TextStyle(
                  fontSize: 16,
                  color: BloodAppTheme.getBloodTypeColor(_bloodType),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              
              // Stats Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BloodAppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.people, '$donors', 'Donors'),
                    Container(
                      height: 40,
                      width: 1,
                      color: BloodAppTheme.textHint,
                    ),
                    _buildStatItem(Icons.local_hospital, '$banks', 'Banks'),
                    Container(
                      height: 40,
                      width: 1,
                      color: BloodAppTheme.textHint,
                    ),
                    _buildStatItem(Icons.timer, '60m', 'Timer'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Info Text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BloodAppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: BloodAppTheme.info, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        total > 0
                            ? 'Notifications sent! Wait for responses.'
                            : 'No matches found. Try increasing search radius.',
                        style: TextStyle(
                          color: BloodAppTheme.info,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Done Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BloodAppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: BloodAppTheme.primary, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: BloodAppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BloodAppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'emergency':
        return BloodAppTheme.emergency;
      case 'high':
        return BloodAppTheme.urgent;
      case 'normal':
        return BloodAppTheme.normal;
      case 'low':
        return BloodAppTheme.low;
      default:
        return BloodAppTheme.textSecondary;
    }
  }

  IconData _getUrgencyIcon(String urgency) {
    switch (urgency) {
      case 'emergency':
        return Icons.emergency;
      case 'high':
        return Icons.warning_amber;
      case 'normal':
        return Icons.info;
      case 'low':
        return Icons.low_priority;
      default:
        return Icons.bloodtype;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'New Blood Request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Indicator
              _buildProgressIndicator(),
              const SizedBox(height: 20),

              // Blood Type Selection
              _buildSectionCard(
                icon: Icons.water_drop,
                title: 'Blood Requirements',
                child: Column(
                  children: [
                    // Blood Type Grid
                    _buildBloodTypeSelector(),
                    const SizedBox(height: 16),
                    
                    // Urgency & Units Row
                    Row(
                      children: [
                        Expanded(child: _buildUrgencySelector()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildUnitsSelector()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Location Section
              _buildSectionCard(
                icon: Icons.location_on,
                title: 'Location',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationPicker(),
                    const SizedBox(height: 16),
                    _buildRadiusSlider(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Additional Details
              _buildSectionCard(
                icon: Icons.description,
                title: 'Additional Details',
                child: Column(
                  children: [
                    _buildTextField(
                      label: 'Hospital / Clinic Name',
                      controller: _hospitalCtr,
                      icon: Icons.local_hospital,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'Contact Phone',
                      controller: _phoneCtr,
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: 'Special Instructions (Optional)',
                      controller: _notesCtr,
                      icon: Icons.note,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _buildDatePicker(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Info Cards
              _buildInfoCard(
                icon: Icons.timer,
                title: '1-Hour Timer',
                description: 'Request active for 60 minutes. Donors can accept during this time.',
                color: BloodAppTheme.warning,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                icon: Icons.people,
                title: 'Smart Matching',
                description: 'Compatible donors within ${_searchRadius}km will be notified instantly.',
                color: BloodAppTheme.success,
              ),
              const SizedBox(height: 24),

              // Submit Button
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getUrgencyColor(_urgency).withOpacity(0.8),
            _getUrgencyColor(_urgency).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getUrgencyColor(_urgency).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.bloodtype,
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
                  '$_bloodType • $_units unit(s)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pickedAddress.isEmpty ? 'Select location' : _pickedAddress,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _urgency.toUpperCase(),
              style: TextStyle(
                color: _getUrgencyColor(_urgency),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
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
                  color: BloodAppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: BloodAppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BloodAppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBloodTypeSelector() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: _bloodTypes.length,
      itemBuilder: (context, index) {
        final type = _bloodTypes[index];
        final isSelected = _bloodType == type;
        final color = BloodAppTheme.getBloodTypeColor(type);
        
        return GestureDetector(
          onTap: () => setState(() => _bloodType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : color.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUrgencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Urgency',
          style: TextStyle(
            fontSize: 13,
            color: BloodAppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BloodAppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _urgency,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: BloodAppTheme.textSecondary),
              items: _urgencies.map((u) {
                return DropdownMenuItem(
                  value: u,
                  child: Row(
                    children: [
                      Icon(_getUrgencyIcon(u), color: _getUrgencyColor(u), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        u.toUpperCase(),
                        style: TextStyle(
                          color: _getUrgencyColor(u),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _urgency = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Units Required',
          style: TextStyle(
            fontSize: 13,
            color: BloodAppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: BloodAppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _units > 1 ? () => setState(() => _units--) : null,
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: _units > 1 ? BloodAppTheme.primary : BloodAppTheme.textHint,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_units',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: BloodAppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _units < 6 ? () => setState(() => _units++) : null,
                icon: Icon(
                  Icons.add_circle_outline,
                  color: _units < 6 ? BloodAppTheme.primary : BloodAppTheme.textHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    final hasLocation = _pickedLat != null && _pickedLng != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasLocation ? BloodAppTheme.success.withOpacity(0.1) : BloodAppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLocation ? BloodAppTheme.success.withOpacity(0.3) : BloodAppTheme.warning.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasLocation ? Icons.check_circle : Icons.location_off,
                color: hasLocation ? BloodAppTheme.success : BloodAppTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasLocation ? _pickedAddress : 'No location selected',
                  style: TextStyle(
                    color: hasLocation ? BloodAppTheme.success : BloodAppTheme.warning,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
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
              onPressed: _openMap,
              icon: Icon(hasLocation ? Icons.edit_location : Icons.add_location),
              label: Text(hasLocation ? 'Change Location' : 'Select Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasLocation ? BloodAppTheme.textSecondary : BloodAppTheme.primary,
                foregroundColor: Colors.white,
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

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.radar, color: BloodAppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Search Radius',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: BloodAppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: BloodAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_searchRadius km',
                style: TextStyle(
                  color: BloodAppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: BloodAppTheme.primary,
            inactiveTrackColor: BloodAppTheme.primary.withOpacity(0.2),
            thumbColor: BloodAppTheme.primary,
            overlayColor: BloodAppTheme.primary.withOpacity(0.2),
          ),
          child: Slider(
            value: _searchRadius.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            onChanged: (value) => setState(() => _searchRadius = value.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5km', style: TextStyle(fontSize: 11, color: BloodAppTheme.textHint)),
              Text('50km', style: TextStyle(fontSize: 11, color: BloodAppTheme.textHint)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: BloodAppTheme.primary),
        filled: true,
        fillColor: BloodAppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BloodAppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: BloodAppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: BloodAppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _neededBy == null
                    ? 'Needed By (Optional)'
                    : '${_neededBy!.day}/${_neededBy!.month}/${_neededBy!.year}',
                style: TextStyle(
                  color: _neededBy == null ? BloodAppTheme.textHint : BloodAppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            if (_neededBy != null)
              GestureDetector(
                onTap: () => setState(() => _neededBy = null),
                child: Icon(Icons.close, color: BloodAppTheme.textSecondary, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getUrgencyColor(_urgency),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: _submitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Creating Request...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Submit Request',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
