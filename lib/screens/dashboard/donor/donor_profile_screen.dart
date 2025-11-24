import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  // controllers
  final _nameCtr = TextEditingController();
  final _phoneCtr = TextEditingController();
  final _cityCtr = TextEditingController();
  final _addressCtr = TextEditingController();
  final _aboutCtr = TextEditingController();
  final _cnicCtr = TextEditingController();
  final _emgNameCtr = TextEditingController();
  final _emgPhoneCtr = TextEditingController();

  String? _bloodType;
  String? _gender;
  DateTime? _dob;

  bool _editing = false;
  bool _saving = false;

  final Map<String, TextEditingController> _otherCtrs = {};

  final List<String> _bloodTypes = const [
    'A+','A-','B+','B-','AB+','AB-','O+','O-'
  ];
  final List<String> _genders = const [
    'Male','Female','Other','Prefer not to say'
  ];

  static const Set<String> _knownKeys = {
    'uid','email','role','fullName','name','phone','phoneNumber','city','address',
    'bloodType','gender','dob','about','cnic',
    'emergencyContactName','emergencyContactPhone',
    'profileCompleted','verified','photoUrl','createdAt','updatedAt',
    'isAvailable','location'
  };

  @override
  void dispose() {
    _nameCtr.dispose();
    _phoneCtr.dispose();
    _cityCtr.dispose();
    _addressCtr.dispose();
    _aboutCtr.dispose();
    _cnicCtr.dispose();
    _emgNameCtr.dispose();
    _emgPhoneCtr.dispose();
    _otherCtrs.forEach((_, c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: Text('Not logged in')),
      );
    }
    final email = _auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
        ],
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};
          _hydrate(data, editing: _editing);

          final role = (data['role'] ?? 'Donor').toString();
          final verified = (data['verified'] ?? false) as bool;
          final completed = (data['profileCompleted'] ?? false) as bool;
          final createdAt = data['createdAt'];
          final updatedAt = data['updatedAt'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _Header(
                    name: _nameCtr.text.isEmpty ? 'Your Name' : _nameCtr.text,
                    email: email,
                    role: role,
                    verified: verified,
                    completed: completed,
                    photoUrl: (data['photoUrl'] ?? '') as String,
                  ),
                  const SizedBox(height: 18),

                  _section('Personal', Column(
                    children: [
                      _tf('Full Name', _nameCtr, enabled: _editing,
                          validator: (v)=> (v==null||v.trim().isEmpty)?'Required':null),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              isExpanded: true,
                              items: _genders.map((g)=>DropdownMenuItem(
                                value: g, child: Text(g, maxLines: 1, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              selectedItemBuilder: (_) => _genders.map((g)=>Align(
                                alignment: Alignment.centerLeft,
                                child: Text(g, maxLines:1, overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: _editing ? (v)=>setState(()=>_gender=v) : null,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _editing ? _pickDob : null,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date of Birth',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                child: Text(
                                  _dob==null ? 'Not set'
                                      : '${_dob!.year}-${_dob!.month.toString().padLeft(2,'0')}-${_dob!.day.toString().padLeft(2,'0')}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _bloodType,
                        isExpanded: true,
                        items: _bloodTypes.map((b)=>DropdownMenuItem(
                          value: b, child: Text(b, maxLines:1, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        selectedItemBuilder: (_)=>_bloodTypes.map((b)=>Align(
                          alignment: Alignment.centerLeft,
                          child: Text(b, maxLines:1, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: _editing ? (v)=>setState(()=>_bloodType=v) : null,
                        decoration: const InputDecoration(
                          labelText: 'Blood Type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (_)=> (_bloodType==null||_bloodType!.isEmpty) ? 'Select blood type' : null,
                      ),
                      const SizedBox(height: 12),
                      _tf('About (optional)', _aboutCtr, enabled: _editing, maxLines: 2),
                    ],
                  )),

                  const SizedBox(height: 18),

                  _section('Contact', Column(
                    children: [
                      _tf('Phone Number', _phoneCtr, enabled: _editing,
                          keyboardType: TextInputType.phone,
                          validator: (v)=> (v==null||v.trim().length<8)?'Enter a valid number':null),
                      const SizedBox(height: 12),
                      _tf('City', _cityCtr, enabled: _editing,
                          validator: (v)=> (v==null||v.trim().isEmpty)?'Required':null),
                      const SizedBox(height: 12),
                      _tf('Address (optional)', _addressCtr, enabled: _editing, maxLines: 2),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _tf('Emergency Contact Name (optional)', _emgNameCtr, enabled: _editing)),
                          const SizedBox(width: 12),
                          Expanded(child: _tf('Emergency Contact Phone (optional)', _emgPhoneCtr, enabled: _editing, keyboardType: TextInputType.phone)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _tf('CNIC (optional)', _cnicCtr, enabled: _editing),
                    ],
                  )),

                  const SizedBox(height: 18),

                  _section('Account', Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Email', email),
                      const SizedBox(height: 8),
                      _kv('Role', role),
                      const SizedBox(height: 8),
                      _kv('Verified', verified ? 'Yes' : 'No'),
                      const SizedBox(height: 8),
                      if (createdAt is Timestamp) _kv('Created', createdAt.toDate().toString().split('.').first),
                      if (updatedAt is Timestamp) _kv('Updated', updatedAt.toDate().toString().split('.').first),
                    ],
                  )),

                  const SizedBox(height: 18),

                  _section('Other Fields',
                    _otherCtrs.isEmpty
                        ? const Align(alignment: Alignment.centerLeft, child: Text('No additional fields.', style: TextStyle(color: Colors.black54)))
                        : Column(
                      children: _otherCtrs.entries.map((e){
                        final key=e.key; final ctr=e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(key, maxLines:1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 6,
                                child: TextFormField(
                                  controller: ctr,
                                  enabled: _editing,
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                ),
                              ),
                              if (_editing)
                                SizedBox(
                                  width: 40,
                                  child: IconButton(
                                    tooltip: 'Remove',
                                    icon: const Icon(Icons.close),
                                    onPressed: (){
                                      setState(()=> _otherCtrs.remove(key)?.dispose());
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    trailing: _editing ? IconButton(
                      tooltip: 'Add custom field',
                      icon: const Icon(Icons.add),
                      onPressed: _addCustomFieldDialog,
                    ) : null,
                  ),

                  const SizedBox(height: 24),

                  if (_editing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Update Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF67D5B5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (_editing)
                    TextButton(
                      onPressed: _saving ? null : ()=> setState(()=> _editing=false),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _hydrate(Map<String, dynamic> data, {required bool editing}) {
    if (editing) return;

    _nameCtr.text   = (data['fullName'] ?? data['name'] ?? '').toString();
    _phoneCtr.text  = (data['phone'] ?? data['phoneNumber'] ?? '').toString();
    _cityCtr.text   = (data['city'] ?? '').toString();
    _addressCtr.text= (data['address'] ?? '').toString();
    _aboutCtr.text  = (data['about'] ?? '').toString();
    _cnicCtr.text   = (data['cnic'] ?? '').toString();
    _emgNameCtr.text= (data['emergencyContactName'] ?? '').toString();
    _emgPhoneCtr.text=(data['emergencyContactPhone'] ?? '').toString();
    _bloodType      = (data['bloodType'] ?? _bloodType)?.toString();
    _gender         = (data['gender'] ?? _gender)?.toString();

    final d = data['dob'];
    if (d is Timestamp) {
      _dob = d.toDate();
    } else if (d is String && d.isNotEmpty) {
      _dob = DateTime.tryParse(d);
    }

    _otherCtrs.forEach((_, c) => c.dispose());
    _otherCtrs.clear();
    for (final e in data.entries) {
      final k = e.key; final v = e.value;
      if (_knownKeys.contains(k)) continue;
      if (v is String) {
        _otherCtrs[k] = TextEditingController(text: v);
      }
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, now.month, now.day);
    final first   = DateTime(now.year - 100, 1, 1);
    final last    = DateTime(now.year - 10, 12, 31);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null) setState(()=> _dob = picked);
  }

  Future<void> _addCustomFieldDialog() async {
    String key=''; String value='';
    final reserved = {..._knownKeys, ..._otherCtrs.keys};

    await showDialog(
      context: context,
      builder: (_)=> AlertDialog(
        title: const Text('Add custom field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: const InputDecoration(labelText: 'Field key'), onChanged: (v)=> key=v.trim()),
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(labelText: 'Field value'), onChanged: (v)=> value=v),
            const SizedBox(height: 6),
            const Text('Note: only string values are supported here.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: (){
              if (key.isEmpty || reserved.contains(key)) return;
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (key.isNotEmpty && !reserved.contains(key)) {
      setState(()=> _otherCtrs[key] = TextEditingController(text: value));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _auth.currentUser!.uid;

    setState(()=> _saving = true);
    try {
      final updates = <String, dynamic>{
        'fullName': _nameCtr.text.trim(),
        'phone': _phoneCtr.text.trim(),
        'city': _cityCtr.text.trim(),
        'address': _addressCtr.text.trim(),
        'about': _aboutCtr.text.trim(),
        'cnic': _cnicCtr.text.trim(),
        'emergencyContactName': _emgNameCtr.text.trim(),
        'emergencyContactPhone': _emgPhoneCtr.text.trim(),
        'bloodType': _bloodType,
        'gender': _gender,
        'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
        // completion rule
        'profileCompleted': _nameCtr.text.trim().isNotEmpty &&
            _phoneCtr.text.trim().isNotEmpty &&
            _cityCtr.text.trim().isNotEmpty &&
            (_bloodType != null && _bloodType!.isNotEmpty),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      updates.removeWhere((k, v) => v == null);
      for (final e in _otherCtrs.entries) {
        updates[e.key] = e.value.text;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        updates,
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      setState(()=> _editing = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(()=> _saving = false);
    }
  }

  // ---- UI helpers ----

  Widget _section(String title, Widget child, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey[900]),
              )),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _tf(String label, TextEditingController ctr, {bool enabled=true, TextInputType? keyboardType, String? Function(String?)? validator, int maxLines=1}) {
    return TextFormField(
      controller: ctr,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: maxLines == 1,
        disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(flex: 4, child: Text(k, maxLines:1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Expanded(flex: 6, child: Text(v.isEmpty?'-':v, maxLines:1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final bool verified;
  final bool completed;
  final String photoUrl;

  const _Header({
    required this.name,
    required this.email,
    required this.role,
    required this.verified,
    required this.completed,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF67D5B5).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            backgroundImage: (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
            child: (photoUrl.isEmpty)
                ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Color(0xFF2C8D7C),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Your Name' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5)),
                const SizedBox(height: 3),
                Text(email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(completed ? 'Complete' : 'Incomplete',
                        Colors.white, textColor: completed ? const Color(0xFF2C8D7C) : Colors.black87),
                    _chip(verified ? 'Verified' : 'Unverified',
                        Colors.white, textColor: verified ? const Color(0xFF2C8D7C) : Colors.orange.shade800),
                    _chip(role.isEmpty ? 'Donor' : role, Colors.white, textColor: Colors.black87),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, {Color textColor = Colors.black87}) {
    return Chip(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
