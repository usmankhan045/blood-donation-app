import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({Key? key}) : super(key: key);

  @override
  _AdminReportsScreenState createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int totalUsers = 0;
  int totalRequests = 0;
  int completedDonations = 0;
  int activeDonors = 0;
  int pendingVerifications = 0;
  Map<String, int> bloodTypeStats = {};
  Map<String, int> monthlyBloodTypeStats = {};
  Map<String, int> requestStatusStats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait([
      _loadUserStats(),
      _loadRequestStats(),
      _loadBloodTypeStats(),
      _loadMonthlyBloodTypeStats(),
      _loadPendingVerifications(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadUserStats() async {
    final usersSnapshot = await _firestore.collection('users').get();
    final donorsSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'donor')
        .where('isAvailable', isEqualTo: true)
        .get();

    setState(() {
      totalUsers = usersSnapshot.docs.length;
      activeDonors = donorsSnapshot.docs.length;
    });
  }

  Future<void> _loadPendingVerifications() async {
    final hospitalsSnapshot = await _firestore
        .collection('hospitals')
        .where('isVerified', isEqualTo: false)
        .get();

    final bloodBanksSnapshot = await _firestore
        .collection('blood_banks')
        .where('isVerified', isEqualTo: false)
        .get();

    setState(() {
      pendingVerifications = hospitalsSnapshot.docs.length + bloodBanksSnapshot.docs.length;
    });
  }

  Future<void> _loadRequestStats() async {
    final requestsSnapshot = await _firestore.collection('blood_requests').get();
    final completedSnapshot = await _firestore
        .collection('blood_requests')
        .where('status', isEqualTo: 'completed')
        .get();

    // Calculate status distribution
    Map<String, int> statusCount = {};
    for (var doc in requestsSnapshot.docs) {
      final status = doc['status'] ?? 'active';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    setState(() {
      totalRequests = requestsSnapshot.docs.length;
      completedDonations = completedSnapshot.docs.length;
      requestStatusStats = statusCount;
    });
  }

  Future<void> _loadBloodTypeStats() async {
    final requestsSnapshot = await _firestore.collection('blood_requests').get();

    Map<String, int> bloodCount = {};
    for (var doc in requestsSnapshot.docs) {
      final bloodType = doc['bloodType'] ?? 'Unknown';
      bloodCount[bloodType] = (bloodCount[bloodType] ?? 0) + 1;
    }

    setState(() {
      bloodTypeStats = bloodCount;
    });
  }

  Future<void> _loadMonthlyBloodTypeStats() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    final monthlyRequests = await _firestore
        .collection('blood_requests')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth))
        .get();

    Map<String, int> monthlyBloodCount = {};
    for (var doc in monthlyRequests.docs) {
      final bloodType = doc['bloodType'] ?? 'Unknown';
      monthlyBloodCount[bloodType] = (monthlyBloodCount[bloodType] ?? 0) + 1;
    }

    setState(() {
      monthlyBloodTypeStats = monthlyBloodCount;
    });
  }

  List<ChartData> _getChartData(Map<String, int> data) {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return bloodTypes.map((bloodType) {
      final value = data[bloodType] ?? 0;
      return ChartData(bloodType, value.toDouble());
    }).toList();
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodDemandChart(String title, Map<String, int> data) {
    final chartData = _getChartData(data);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed Row with proper constraints
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: double.infinity,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download, size: 20),
                    onPressed: () => _showDownloadOptions(title, data),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <CartesianSeries<ChartData, String>>[
                  ColumnSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.bloodType,
                    yValueMapper: (ChartData data, _) => data.demand,
                    color: const Color(0xFF667eea),
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTypeList(String title, Map<String, int> data) {
    final total = data.values.fold(0, (sum, value) => sum + value);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...data.entries.map((entry) {
              final percentage = total > 0
                  ? (entry.value / total * 100).toStringAsFixed(1)
                  : '0.0';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getBloodTypeColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value} ($percentage%)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getBloodTypeColor(String bloodType) {
    switch (bloodType) {
      case 'A+': return Colors.red;
      case 'A-': return Colors.red[300]!;
      case 'B+': return Colors.blue;
      case 'B-': return Colors.blue[300]!;
      case 'AB+': return Colors.green;
      case 'AB-': return Colors.green[300]!;
      case 'O+': return Colors.orange;
      case 'O-': return Colors.orange[300]!;
      default: return Colors.grey;
    }
  }

  Widget _buildStatusDistribution() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Status Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...requestStatusStats.entries.map((entry) {
              Color statusColor;
              switch (entry.key) {
                case 'completed':
                  statusColor = Colors.green;
                  break;
                case 'active':
                  statusColor = Colors.blue;
                  break;
                case 'accepted':
                  statusColor = Colors.orange;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing: Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showDownloadOptions(String title, Map<String, int> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose report type:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Monthly Report'),
              subtitle: const Text('Current month data'),
              onTap: () => _downloadMonthlyReport(title, data),
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Custom Date Range'),
              subtitle: const Text('Select specific dates'),
              onTap: () => _showCustomDateRangeDialog(title),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _downloadMonthlyReport(String title, Map<String, int> data) {
    Navigator.pop(context);

    // Generate report data
    final reportData = _generateReportData(title, data, 'Monthly');

    _showReportPreview(reportData);
  }

  void _showCustomDateRangeDialog(String title) {
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Date Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startDateController,
              decoration: const InputDecoration(
                labelText: 'Start Date',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            TextField(
              controller: endDateController,
              decoration: const InputDecoration(
                labelText: 'End Date',
                hintText: 'YYYY-MM-DD',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (startDateController.text.isNotEmpty && endDateController.text.isNotEmpty) {
                Navigator.pop(context);
                _downloadCustomRangeReport(title, startDateController.text, endDateController.text);
              }
            },
            child: const Text('Generate Report'),
          ),
        ],
      ),
    );
  }

  void _downloadCustomRangeReport(String title, String startDate, String endDate) {
    final reportData = _generateReportData(title, bloodTypeStats, 'Custom Range: $startDate to $endDate');
    _showReportPreview(reportData);
  }

  Map<String, dynamic> _generateReportData(String title, Map<String, int> data, String period) {
    return {
      'title': title,
      'period': period,
      'generatedAt': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      'totalRequests': totalRequests,
      'completedDonations': completedDonations,
      'activeDonors': activeDonors,
      'totalUsers': totalUsers,
      'bloodTypeData': data,
      'statusDistribution': requestStatusStats,
    };
  }

  void _showReportPreview(Map<String, dynamic> reportData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report Preview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text('Title: ${reportData['title']}'),
              Text('Period: ${reportData['period']}'),
              Text('Generated: ${reportData['generatedAt']}'),
              Text('Total Requests: ${reportData['totalRequests']}'),
              Text('Completed Donations: ${reportData['completedDonations']}'),
              const SizedBox(height: 16),
              const Text(
                'Blood Type Distribution:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(reportData['bloodTypeData'] as Map<String, int>).entries.map((entry) {
                return Text('${entry.key}: ${entry.value} requests');
              }).toList(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showExportSuccess();
                      },
                      child: const Text('Export as PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report exported successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Analytics & Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllStats,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAllStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Grid - Responsive
              GridView.count(
                crossAxisCount: isSmallScreen ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isSmallScreen ? 1.2 : 1.5,
                children: [
                  _buildStatCard('Total Users', totalUsers, Icons.people_alt, Colors.blue),
                  _buildStatCard('Blood Requests', totalRequests, Icons.bloodtype, Colors.red),
                  _buildStatCard('Completed', completedDonations, Icons.check_circle, Colors.green),
                  _buildStatCard('Active Donors', activeDonors, Icons.favorite, Colors.pink),
                  if (!isSmallScreen) // Show additional cards on larger screens
                    _buildStatCard('Pending Verifications', pendingVerifications, Icons.verified_user, Colors.orange),
                ],
              ),

              const SizedBox(height: 24),

              // Overall Blood Demand Chart
              _buildBloodDemandChart('Overall Blood Type Demand', bloodTypeStats),

              const SizedBox(height: 16),

              // Monthly Blood Demand Chart
              _buildBloodDemandChart('This Month Blood Type Demand', monthlyBloodTypeStats),

              const SizedBox(height: 16),

              // Blood Type Lists - Responsive layout
              if (isSmallScreen)
              // Vertical layout for small screens
                Column(
                  children: [
                    _buildBloodTypeList('Overall Demand', bloodTypeStats),
                    const SizedBox(height: 16),
                    _buildBloodTypeList('Monthly Demand', monthlyBloodTypeStats),
                  ],
                )
              else
              // Horizontal layout for larger screens
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildBloodTypeList('Overall Demand', bloodTypeStats),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildBloodTypeList('Monthly Demand', monthlyBloodTypeStats),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Status Distribution
              _buildStatusDistribution(),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.build, color: Colors.blue),
            SizedBox(width: 8),
            Text('Coming Soon'),
          ],
        ),
        content: const Text('This feature is under development and will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final String bloodType;
  final double demand;

  ChartData(this.bloodType, this.demand);
}