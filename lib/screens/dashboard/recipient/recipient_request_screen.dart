import 'package:blood_donation_app/screens/common/pick_location_osm.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../repositories/blood_request_repository.dart';

class RecipientRequestScreen extends StatefulWidget {
  const RecipientRequestScreen({super.key});

  @override
  State<RecipientRequestScreen> createState() => _RecipientRequestScreenState();
}

class _RecipientRequestScreenState extends State<RecipientRequestScreen> {
  final _form = GlobalKey<FormState>();
  // Use the singleton instance instead of creating a new instance
  final _repo = BloodRequestRepository.instance;

  // removed free-text city; locked to Abbottabad
  final _hospitalCtr = TextEditingController();
  final _notesCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _recipientNameCtr = TextEditingController();

  String _bloodType = 'A+';
  String _urgency = 'normal';
  int _units = 1;
  DateTime? _neededBy;
  int _searchRadius = 10; // Default 10km search radius

  // NEW (OSM): we store plain doubles instead of Google LatLng
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a location on the map (Abbottabad).')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final requesterName =
          (userDoc.data()?['fullName'] ?? userDoc.data()?['name'] ?? '') as String? ??
              '';

      final id = await _repo.createRequest(
        requesterId: user.uid,
        requesterName: requesterName,
        city: 'Abbottabad', // locked for now
        bloodType: _bloodType,
        urgency: _urgency,
        units: _units,
        hospital: _hospitalCtr.text.trim(),
        notes: _notesCtr.text.trim(),
        phone: _phoneCtr.text.trim(),
        neededBy: _neededBy,
        location: GeoPoint(_pickedLat!, _pickedLng!),
        address: _pickedAddress,
        searchRadius: _searchRadius, // Add search radius
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request created (#$id) - Notifying donors within $_searchRadius km'),
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Get urgency icon based on level
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

  // Get urgency color based on level
  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case 'emergency':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final addr = (_pickedLat == null || _pickedLng == null)
        ? 'No location selected'
        : '$_pickedAddress\n(${_pickedLat!.toStringAsFixed(5)}, ${_pickedLng!.toStringAsFixed(5)})';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Request Blood'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _form,
          child: Column(
            children: [
              // Patient/Recipient Section
              _section(
                'Patient / Recipient Details',
                Column(
                  children: [
                    _tf('Recipient Name (optional)', _recipientNameCtr),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _bloodType,
                            isExpanded: true,
                            items: _bloodTypes
                                .map((b) => DropdownMenuItem(
                              value: b,
                              child: Row(
                                children: [
                                  Icon(Icons.bloodtype,
                                      color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Text(b),
                                ],
                              ),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() => _bloodType = v!),
                            decoration: const InputDecoration(
                              labelText: 'Blood Type',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _urgency,
                            isExpanded: true,
                            items: _urgencies
                                .map((u) => DropdownMenuItem(
                              value: u,
                              child: Row(
                                children: [
                                  Icon(_getUrgencyIcon(u),
                                      color: _getUrgencyColor(u),
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Text(u.toUpperCase()),
                                ],
                              ),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() => _urgency = v!),
                            decoration: const InputDecoration(
                              labelText: 'Urgency Level',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '1',
                            key: ValueKey(_units),
                            decoration: const InputDecoration(
                              labelText: 'Units Required',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.bloodtype_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final n = int.tryParse(v) ?? 1;
                              _units = n.clamp(1, 6);
                            },
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1 || n > 6) return 'Enter 1-6 units';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Needed By (optional)',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _neededBy == null
                                    ? 'Select date'
                                    : '${_neededBy!.day}/${_neededBy!.month}/${_neededBy!.year}',
                                style: TextStyle(
                                  color: _neededBy == null
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Location & Search Radius Section
              _section(
                'Location & Donor Search',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('City', 'Abbottabad'),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.blueGrey[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Location:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addr,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openMap,
                            icon: const Icon(Icons.map, size: 20),
                            label: const Text('Pick Location on Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF67D5B5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search Radius Slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.radar, size: 18, color: Color(0xFF67D5B5)),
                            const SizedBox(width: 8),
                            Text(
                              'Search Radius: $_searchRadius km',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _searchRadius.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 9,
                          label: '$_searchRadius km',
                          activeColor: const Color(0xFF67D5B5),
                          inactiveColor: Colors.grey[300],
                          onChanged: (value) => setState(() => _searchRadius = value.round()),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text('5km', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('50km', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getRadiusDescription(_searchRadius),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _tf('Hospital / Location Name (optional)', _hospitalCtr),
                    const SizedBox(height: 12),
                    _tf('Contact Phone (optional)', _phoneCtr,
                        keyboardType: TextInputType.phone),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Additional Notes Section
              _section(
                'Additional Information',
                _tf('Special notes or instructions for donors (optional)',
                    _notesCtr,
                    maxLines: 3),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send, size: 20),
                  label: Text(
                    _submitting
                        ? 'Creating Request & Notifying Donors...'
                        : 'Submit Blood Request',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getUrgencyColor(_urgency),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Info text about the process
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'After submission, eligible donors within $_searchRadius km will be notified immediately.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey[900],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _tf(String label, TextEditingController ctr,
      {String? Function(String?)? validator, int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctr,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: maxLines == 1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  String _getRadiusDescription(int radius) {
    if (radius <= 10) {
      return 'Local search - ideal for urgent requests in nearby areas';
    } else if (radius <= 25) {
      return 'Medium range - covers most of Abbottabad city';
    } else {
      return 'Wide search - includes surrounding areas of Abbottabad';
    }
  }
}