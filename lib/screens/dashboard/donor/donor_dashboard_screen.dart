import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/donor_service.dart';
import '../../../repositories/blood_request_repository.dart';
import '../../../models/blood_request_model.dart';
import '../../chat/chat_screen.dart';
import 'donor_profile_screen.dart';


class DonorDashboardScreen extends StatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  State<DonorDashboardScreen> createState() => _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends State<DonorDashboardScreen> {
  final _donorService = DonorService();

  bool _isAvailable = false;
  bool _profileCompleted = false;
  String? _city;
  String? _bloodType;
  bool _navigating = false; // guard against rapid taps

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final d = doc.data() ?? {};
    if (!mounted) return;
    setState(() {
      _isAvailable = (d['isAvailable'] ?? false) as bool;
      _profileCompleted = (d['profileCompleted'] ?? false) as bool;
      _city = d['city'] as String?;
      _bloodType = (d['bloodType'] as String?)?.toUpperCase(); // normalize
    });
  }

  Future<void> _toggle(bool v) async {
    await _donorService.toggleAvailability(v);
    if (!mounted) return;
    setState(() => _isAvailable = v);
  }

  // push direct page instead of named route
  Future<void> _openProfile() async {
    if (_navigating) return;
    _navigating = true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DonorProfileScreen()),
    );
    _navigating = false;
    if (mounted) {
      await _loadProfile(); // refresh profile after return
    }
  }

  void _openProfileCompletion() {
    Navigator.pushNamed(context, '/donor_profile_completion').then((_) => _loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final ready = _profileCompleted; // real completion flag
    final canReceive = ready && _isAvailable && _city != null && _bloodType != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Donor Dashboard'),
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
        actions: [
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(Icons.account_circle),
            onPressed: _openProfile,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(top: -60, left: -40, child: _blob(140, const Color(0x3367D5B5))),
          Positioned(bottom: -50, right: -30, child: _blob(120, const Color(0x334AB9C5))),
          SafeArea(
            child: DefaultTabController(
              length: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(
                      isAvailable: _isAvailable,
                      city: _city ?? '-',
                      bloodType: _bloodType ?? '-',
                      onToggle: _toggle,
                      onProfileTap: _openProfile,
                      onCompleteTap: _openProfileCompletion,
                      showCompleteBtn: !ready,
                    ),
                    const SizedBox(height: 12),
                    const _EligibilityBanner(),
                    const SizedBox(height: 14),
                    Text(
                      'Recent Donations',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _RecentDonationsRow(),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const TabBar(
                        labelColor: Color(0xFF2C8D7C),
                        unselectedLabelColor: Colors.black54,
                        indicatorColor: Color(0xFF2C8D7C),
                        tabs: [
                          Tab(icon: Icon(Icons.inbox_outlined), text: 'Requests'),
                          Tab(icon: Icon(Icons.history), text: 'History'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _RequestsTab(
                            canReceive: canReceive,
                            ready: ready,
                            isAvailable: _isAvailable,
                            city: _city,
                            bloodType: _bloodType,
                            onCompleteTap: _openProfileCompletion,
                            onTurnOn: () => _toggle(true),
                          ),
                          const _DonationHistoryList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// =================== Header Card ===================

class _HeaderCard extends StatelessWidget {
  final bool isAvailable;
  final String city;
  final String bloodType;
  final ValueChanged<bool> onToggle;
  final VoidCallback onProfileTap;
  final VoidCallback onCompleteTap;
  final bool showCompleteBtn;

  const _HeaderCard({
    required this.isAvailable,
    required this.city,
    required this.bloodType,
    required this.onToggle,
    required this.onProfileTap,
    required this.onCompleteTap,
    required this.showCompleteBtn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF67D5B5).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.45)),
                ),
                child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip('City: $city'),
                    _chip('Blood: $bloodType'),
                    _chip(isAvailable ? 'Available' : 'Unavailable',
                        color: isAvailable ? Colors.white : Colors.white70,
                        textColor: isAvailable ? const Color(0xFF2C8D7C) : Colors.black87),
                  ],
                ),
              ),
              Switch(
                value: isAvailable,
                onChanged: onToggle,
                activeColor: Colors.white,
                activeTrackColor: Colors.white54,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white24,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onProfileTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: const Icon(Icons.account_circle),
                  label: const Text('My Profile'),
                ),
              ),
              const SizedBox(width: 10),
              if (showCompleteBtn)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onCompleteTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2C8D7C),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Complete Profile'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {Color color = Colors.white, Color textColor = Colors.black87}) {
    return Chip(
      label: Text(label,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// =================== Eligibility Banner ===================

class _EligibilityBanner extends StatelessWidget {
  const _EligibilityBanner();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final q = FirebaseFirestore.instance
        .collection('donations')
        .where('donorId', isEqualTo: uid)
        .orderBy('date', descending: true)
        .limit(1);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        DateTime? lastDonation;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final data = snap.data!.docs.first.data() as Map<String, dynamic>? ?? {};
          final ts = data['date'];
          if (ts is Timestamp) lastDonation = ts.toDate();
        }

        if (lastDonation == null) {
          return _infoPill(
              icon: Icons.calendar_today_outlined,
              text: 'No past donations recorded. You are good to donate!',
          );
        }

        final nextEligible = lastDonation.add(const Duration(days: 90));
        final now = DateTime.now();
        final eligible = now.isAfter(nextEligible);
        final text = eligible
            ? 'You are eligible to donate again. Last donation: ${_fmtDate(lastDonation)}'
            : 'Next eligible on ${_fmtDate(nextEligible)} (last: ${_fmtDate(lastDonation)})';

        return _infoPill(
          icon: Icons.health_and_safety_outlined,
          text: text,
        );
      },
    );
  }

  Widget _infoPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2C8D7C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== Recent 3 Donations ===================

class _RecentDonationsRow extends StatelessWidget {
  const _RecentDonationsRow();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final q = FirebaseFirestore.instance
        .collection('donations')
        .where('donorId', isEqualTo: uid)
        .orderBy('date', descending: true)
        .limit(3);

    return SizedBox(
      height: 100,
      child: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No donations yet.'));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>? ?? {};
              final date = (data['date'] is Timestamp) ? (data['date'] as Timestamp).toDate() : null;
              final units = (data['units'] ?? 1) as int;
              final city = (data['city'] ?? '-') as String;
              final hospital = (data['hospital'] ?? '') as String;
              final recipient = (data['recipientName'] ?? '') as String;

              final line2 = (hospital.isNotEmpty ? hospital : recipient.isNotEmpty ? recipient : city);

              return Container(
                width: 230,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFE3F7F2), Color(0xFFD2F1F3)],
                        ),
                      ),
                      child: const Icon(Icons.water_drop, color: Color(0xFF2C8D7C)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${units} unit${units > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            line2.isEmpty ? '-' : line2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            date == null ? '-' : _fmtDate(date),
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =================== Tabs Content ===================

class _RequestsTab extends StatelessWidget {
  final bool canReceive;
  final bool ready;
  final bool isAvailable;
  final String? city;
  final String? bloodType;
  final VoidCallback onCompleteTap;
  final VoidCallback onTurnOn;

  const _RequestsTab({
    required this.canReceive,
    required this.ready,
    required this.isAvailable,
    required this.city,
    required this.bloodType,
    required this.onCompleteTap,
    required this.onTurnOn,
  });

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return _EmptyStateCard(
        icon: Icons.info_outline,
        title: 'Complete your profile',
        message: 'Add your City & Blood Type to start receiving requests.',
        ctaLabel: 'Complete Profile',
        onCta: onCompleteTap,
      );
    }
    if (!isAvailable) {
      return _EmptyStateCard(
        icon: Icons.toggle_off_outlined,
        title: 'You are currently unavailable',
        message: 'Switch yourself to AVAILABLE to receive matching requests.',
        ctaLabel: 'Turn ON Availability',
        onCta: onTurnOn,
      );
    }
    if (city == null || bloodType == null) {
      return const Center(child: Text('Profile missing City/Blood Type.'));
    }
    return _RequestsList(city: city!, bloodType: bloodType!);
  }
}

class _DonationHistoryList extends StatelessWidget {
  const _DonationHistoryList();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not logged in'));

    final q = FirebaseFirestore.instance
        .collection('donations')
        .where('donorId', isEqualTo: uid)
        .orderBy('date', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No donation history yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 6),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>? ?? {};
            final date = (data['date'] is Timestamp) ? (data['date'] as Timestamp).toDate() : null;
            final units = (data['units'] ?? 1) as int;
            final status = (data['status'] ?? 'completed') as String;
            final city = (data['city'] ?? '-') as String;
            final hospital = (data['hospital'] ?? '') as String;
            final recipient = (data['recipientName'] ?? '') as String;

            final line2 = hospital.isNotEmpty ? hospital : (recipient.isNotEmpty ? recipient : city);

            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(1.4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE3F7F2),
                    child: Text(
                      '${units}u',
                      style: const TextStyle(
                        color: Color(0xFF2C8D7C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    line2,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blueGrey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${date == null ? '-' : _fmtDate(date)} • ${status.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Optional: push details page if you later add it
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// =================== Existing Requests List ===================

class _RequestsList extends StatelessWidget {
  final String city;
  final String bloodType;

  const _RequestsList({required this.city, required this.bloodType});

  @override
  Widget build(BuildContext context) {
    final repo = BloodRequestRepository();
    // Ensure bloodType is normalized (e.g., 'A+', 'B-')
    final bt = bloodType.toUpperCase();
    return StreamBuilder<List<BloodRequest>>(
      stream: repo.streamActiveForDonor(donorCity: city, donorBloodType: bt),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No active requests right now.'));
        }
        return ListView.separated(
          itemCount: items.length,
          padding: const EdgeInsets.only(top: 6),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final r = items[i];
            return _RequestCard(request: r);
          },
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BloodRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final createdStr = _fmtMaybeTimestamp(request.createdAt);

    final subtitle = StringBuffer()
      ..write('By: ')
      ..write(request.requesterName.isEmpty ? request.requesterId : request.requesterName)
      ..write('\nPosted: ')
      ..write(createdStr);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF67D5B5), Color(0xFF4AB9C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE3F7F2),
            child: Text(
              request.bloodType,
              style: const TextStyle(
                color: Color(0xFF2C8D7C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            '${request.bloodType} • ${request.city} • ${request.urgency.toUpperCase()}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey[900],
            ),
          ),
          subtitle: Text(
            subtitle.toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ElevatedButton(
            onPressed: () async {
              try {
                await DonorService().acceptRequest(request.id);
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        threadId: request.id,
                        title: 'Chat with Recipient',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to accept: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF67D5B5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Accept'),
          ),
        ),
      ),
    );
  }
}

// =================== Shared helpers ===================

String _fmtDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$y-$m-$day $hh:$mm';
}

String _fmtMaybeTimestamp(dynamic tsOrDate) {
  if (tsOrDate == null) return '-';
  if (tsOrDate is DateTime) return _fmtDate(tsOrDate);
  if (tsOrDate is Timestamp) return _fmtDate(tsOrDate.toDate());
  return tsOrDate.toString();
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: const Color(0xFF2C8D7C)),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.blueGrey[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF67D5B5),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}