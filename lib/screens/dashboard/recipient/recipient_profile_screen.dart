import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../services/auth_service.dart';

class RecipientProfileScreen extends StatefulWidget {
  const RecipientProfileScreen({super.key});

  @override
  State<RecipientProfileScreen> createState() => _RecipientProfileScreenState();
}

class _RecipientProfileScreenState extends State<RecipientProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

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

  final List<String> _bloodTypes = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _genders = const ['Male', 'Female', 'Other', 'Prefer not to say'];

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

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
              ),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Profile not found.'));
          }

          final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};
          _hydrate(data);

          final verified = (data['verified'] ?? false) as bool;
          final completed = (data['profileCompleted'] ?? false) as bool;
          final createdAt = data['createdAt'] as Timestamp?;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(data, verified, completed),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Stats Cards
                        _buildStatsRow(data, createdAt),
                        const SizedBox(height: 20),

                        // Profile Sections
                        if (_editing) ...[
                          _buildEditableSection(data),
                        ] else ...[
                          _buildViewSection(data, verified, completed),
                        ],

                        const SizedBox(height: 24),

                        // Action Buttons
                        if (_editing) ...[
                          _buildSaveButton(),
                          const SizedBox(height: 12),
                          _buildCancelButton(),
                        ] else ...[
                          _buildEditButton(),
                          const SizedBox(height: 16),
                          _buildLogoutButton(),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(Map<String, dynamic> data, bool verified, bool completed) {
    final name = _nameCtr.text.isNotEmpty ? _nameCtr.text : 'Recipient';
    final email = _auth.currentUser?.email ?? '';
    final photoUrl = (data['photoUrl'] ?? '') as String;

    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: BloodAppTheme.primary,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: BloodAppTheme.recipientGradient,
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Avatar
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'R',
                                style: const TextStyle(
                                  color: BloodAppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (verified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: BloodAppTheme.success,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                // Status Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChip(
                      label: 'Recipient',
                      icon: Icons.favorite,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      label: _bloodType ?? '?',
                      icon: Icons.water_drop,
                      color: Colors.white,
                      isBloodType: true,
                    ),
                    const SizedBox(width: 8),
                    _buildChip(
                      label: completed ? 'Complete' : 'Incomplete',
                      icon: completed ? Icons.check_circle : Icons.pending,
                      color: completed ? BloodAppTheme.success : BloodAppTheme.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required Color color,
    bool isBloodType = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isBloodType ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data, Timestamp? createdAt) {
    final memberSince = createdAt != null
        ? '${createdAt.toDate().month}/${createdAt.toDate().year}'
        : 'N/A';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Blood Type',
            _bloodType ?? '?',
            Icons.water_drop,
            BloodAppTheme.getBloodTypeColor(_bloodType ?? 'O+'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'City',
            _cityCtr.text.isNotEmpty ? _cityCtr.text : 'N/A',
            Icons.location_city,
            BloodAppTheme.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Member',
            memberSince,
            Icons.calendar_today,
            BloodAppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: BloodAppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: BloodAppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSection(Map<String, dynamic> data, bool verified, bool completed) {
    return Column(
      children: [
        _buildInfoCard(
          title: 'Personal Information',
          icon: Icons.person,
          items: [
            _InfoItem('Full Name', _nameCtr.text),
            _InfoItem('Gender', _gender ?? 'Not set'),
            _InfoItem('Date of Birth', _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Not set'),
            _InfoItem('Blood Type', _bloodType ?? 'Not set', highlight: true),
            if (_aboutCtr.text.isNotEmpty) _InfoItem('About', _aboutCtr.text),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Contact Information',
          icon: Icons.contact_phone,
          items: [
            _InfoItem('Phone', _phoneCtr.text.isNotEmpty ? _phoneCtr.text : 'Not set'),
            _InfoItem('City', _cityCtr.text.isNotEmpty ? _cityCtr.text : 'Not set'),
            _InfoItem('Address', _addressCtr.text.isNotEmpty ? _addressCtr.text : 'Not set'),
            if (_cnicCtr.text.isNotEmpty) _InfoItem('CNIC', _cnicCtr.text),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Emergency Contact',
          icon: Icons.emergency,
          items: [
            _InfoItem('Name', _emgNameCtr.text.isNotEmpty ? _emgNameCtr.text : 'Not set'),
            _InfoItem('Phone', _emgPhoneCtr.text.isNotEmpty ? _emgPhoneCtr.text : 'Not set'),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Account Status',
          icon: Icons.verified_user,
          items: [
            _InfoItem('Profile', completed ? 'Complete ✓' : 'Incomplete'),
            _InfoItem('Verification', verified ? 'Verified ✓' : 'Pending'),
            _InfoItem('Role', 'Recipient'),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
  }) {
    return Container(
      width: double.infinity,
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
          ...items.map((item) => _buildInfoRow(item)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(_InfoItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                color: BloodAppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: item.highlight ? FontWeight.bold : FontWeight.w500,
                color: item.highlight
                    ? BloodAppTheme.getBloodTypeColor(item.value)
                    : BloodAppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableSection(Map<String, dynamic> data) {
    return Column(
      children: [
        _buildEditCard(
          title: 'Personal Information',
          icon: Icons.person,
          children: [
            _buildTextField('Full Name', _nameCtr, validator: (v) => v?.isEmpty == true ? 'Required' : null),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDropdown('Gender', _genders, _gender, (v) => setState(() => _gender = v))),
                const SizedBox(width: 12),
                Expanded(child: _buildDateField()),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown('Blood Type', _bloodTypes, _bloodType, (v) => setState(() => _bloodType = v)),
            const SizedBox(height: 12),
            _buildTextField('About (optional)', _aboutCtr, maxLines: 2),
          ],
        ),
        const SizedBox(height: 16),
        _buildEditCard(
          title: 'Contact Information',
          icon: Icons.contact_phone,
          children: [
            _buildTextField('Phone Number', _phoneCtr, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildTextField('City', _cityCtr),
            const SizedBox(height: 12),
            _buildTextField('Address', _addressCtr, maxLines: 2),
            const SizedBox(height: 12),
            _buildTextField('CNIC (optional)', _cnicCtr),
          ],
        ),
        const SizedBox(height: 16),
        _buildEditCard(
          title: 'Emergency Contact',
          icon: Icons.emergency,
          children: [
            _buildTextField('Contact Name', _emgNameCtr),
            const SizedBox(height: 12),
            _buildTextField('Contact Phone', _emgPhoneCtr, keyboardType: TextInputType.phone),
          ],
        ),
      ],
    );
  }

  Widget _buildEditCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
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
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: BloodAppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BloodAppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: BloodAppTheme.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDob,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          filled: true,
          fillColor: BloodAppTheme.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          _dob == null ? 'Select' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
          style: TextStyle(
            color: _dob == null ? BloodAppTheme.textSecondary : BloodAppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _editing = true),
        icon: const Icon(Icons.edit),
        label: const Text('Edit Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: BloodAppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save),
        label: Text(_saving ? 'Saving...' : 'Save Changes'),
        style: ElevatedButton.styleFrom(
          backgroundColor: BloodAppTheme.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _saving ? null : () => setState(() => _editing = false),
        style: OutlinedButton.styleFrom(
          foregroundColor: BloodAppTheme.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: BloodAppTheme.textSecondary.withOpacity(0.3)),
        ),
        child: const Text('Cancel'),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: BloodAppTheme.error),
        label: const Text('Sign Out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: BloodAppTheme.error,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: BloodAppTheme.error),
        ),
      ),
    );
  }

  void _hydrate(Map<String, dynamic> data) {
    if (_editing) return;

    _nameCtr.text = (data['fullName'] ?? data['name'] ?? '').toString();
    _phoneCtr.text = (data['phone'] ?? data['phoneNumber'] ?? '').toString();
    _cityCtr.text = (data['city'] ?? '').toString();
    _addressCtr.text = (data['address'] ?? '').toString();
    _aboutCtr.text = (data['about'] ?? '').toString();
    _cnicCtr.text = (data['cnic'] ?? '').toString();
    _emgNameCtr.text = (data['emergencyContactName'] ?? '').toString();
    _emgPhoneCtr.text = (data['emergencyContactPhone'] ?? '').toString();
    _bloodType = (data['bloodType'] ?? data['bloodGroup'])?.toString();
    _gender = data['gender']?.toString();

    final d = data['dob'];
    if (d is Timestamp) {
      _dob = d.toDate();
    } else if (d is String && d.isNotEmpty) {
      _dob = DateTime.tryParse(d);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _auth.currentUser!.uid;

    setState(() => _saving = true);
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
        'profileCompleted': _nameCtr.text.trim().isNotEmpty &&
            _phoneCtr.text.trim().isNotEmpty &&
            _cityCtr.text.trim().isNotEmpty &&
            (_bloodType != null && _bloodType!.isNotEmpty),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      updates.removeWhere((k, v) => v == null);

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        updates,
        SetOptions(merge: true),
      );

      if (mounted) {
        AppSnackbar.showSuccess(context, 'Profile updated successfully!');
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Update failed', subtitle: e.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: BloodAppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }
}

class _InfoItem {
  final String label;
  final String value;
  final bool highlight;

  _InfoItem(this.label, this.value, {this.highlight = false});
}
