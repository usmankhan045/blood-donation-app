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
  final _repo = BloodRequestRepository();

  // removed free-text city; locked to Abbottabad
  final _hospitalCtr = TextEditingController();
  final _notesCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _recipientNameCtr = TextEditingController();

  String _bloodType = 'A+';
  String _urgency = 'normal';
  int _units = 1;
  DateTime? _neededBy;

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
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request created (#$id)')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
              _section(
                'Patient / Recipient',
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
                                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
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
                              child: Text(u.toUpperCase()),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() => _urgency = v!),
                            decoration: const InputDecoration(
                              labelText: 'Urgency',
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
                              labelText: 'Units',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final n = int.tryParse(v) ?? 1;
                              _units = n.clamp(1, 6);
                            },
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1 || n > 6) return '1-6';
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
                              ),
                              child: Text(_neededBy == null
                                  ? 'Select date'
                                  : '${_neededBy!.year}-${_neededBy!.month.toString().padLeft(2, '0')}-${_neededBy!.day.toString().padLeft(2, '0')}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _section(
                'Location (Abbottabad) & Contact',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('City', 'Abbottabad'),
                    const SizedBox(height: 8),
                    Text(addr, style: const TextStyle(color: Colors.black87)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openMap,
                            icon: const Icon(Icons.map),
                            label: const Text('Pick on Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF67D5B5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _tf('Hospital / Location label (optional)', _hospitalCtr),
                    const SizedBox(height: 12),
                    _tf('Contact Phone (optional)', _phoneCtr,
                        keyboardType: TextInputType.phone),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _section(
                'Notes',
                _tf('Additional details (optional)', _notesCtr, maxLines: 3),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF67D5B5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
      padding: const EdgeInsets.all(14),
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
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.blueGrey[900])),
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
      ),
    );
  }

  Widget _infoRow(String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Expanded(child: Text(v, textAlign: TextAlign.right)),
      ],
    );
  }
}
