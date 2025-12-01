import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme.dart';
import '../../../widgets/custom_snackbar.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  Map<String, dynamic> inventory = {};
  List<String> availableBloodTypes = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  Future<void> loadInventory() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          inventory = Map<String, dynamic>.from(doc.data()?['inventory'] ?? {});
          availableBloodTypes = List<String>.from(doc.data()?['availableBloodTypes'] ?? []);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading inventory: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateUnits(String bloodType, int newUnits) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'inventory.$bloodType.units': newUnits,
        'inventory.$bloodType.lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        inventory[bloodType]['units'] = newUnits;
      });

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          '$bloodType Updated',
          subtitle: 'Inventory updated to $newUnits units',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Update Failed',
          subtitle: e.toString(),
        );
      }
    }
  }

  void showEditDialog(String bloodType, int currentUnits) {
    final TextEditingController controller = TextEditingController(text: currentUnits.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: BloodAppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Update $bloodType Units',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Units',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.inventory_2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BloodAppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                int? newUnits = int.tryParse(controller.text);
                if (newUnits != null && newUnits >= 0) {
                  updateUnits(bloodType, newUnits);
                  Navigator.pop(context);
                } else {
                  if (mounted) {
                    AppSnackbar.showError(
                      context,
                      'Invalid Input',
                      subtitle: 'Please enter a valid number',
                    );
                  }
                }
              },
              child: const Text(
                'Update',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  void showQuickAdjustDialog(String bloodType, int currentUnits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune, color: BloodAppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Quick Adjust $bloodType',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current Units: $currentUnits',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickButton(
                  label: '+1',
                  onPressed: () {
                    updateUnits(bloodType, currentUnits + 1);
                    Navigator.pop(context);
                  },
                ),
                _buildQuickButton(
                  label: '+5',
                  onPressed: () {
                    updateUnits(bloodType, currentUnits + 5);
                    Navigator.pop(context);
                  },
                ),
                _buildQuickButton(
                  label: '+10',
                  onPressed: () {
                    updateUnits(bloodType, currentUnits + 10);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickButton(
                  label: '-1',
                  onPressed: currentUnits > 0
                      ? () {
                    updateUnits(bloodType, currentUnits - 1);
                    Navigator.pop(context);
                  }
                      : null,
                  color: Colors.red,
                ),
                _buildQuickButton(
                  label: '-5',
                  onPressed: currentUnits >= 5
                      ? () {
                    updateUnits(bloodType, currentUnits - 5);
                    Navigator.pop(context);
                  }
                      : null,
                  color: Colors.red,
                ),
                _buildQuickButton(
                  label: '-10',
                  onPressed: currentUnits >= 10
                      ? () {
                    updateUnits(bloodType, currentUnits - 10);
                    Navigator.pop(context);
                  }
                      : null,
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButton({
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? BloodAppTheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 2,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  void showAddBloodTypeDialog() {
    final TextEditingController unitsCtrl = TextEditingController(text: '0');

    final List<String> allBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final List<String> remainingTypes = allBloodTypes
        .where((type) => !availableBloodTypes.contains(type))
        .toList();

    if (remainingTypes.isEmpty) {
      if (mounted) {
        AppSnackbar.showInfo(
          context,
          'All Types Added',
          subtitle: 'All blood types are already in your inventory',
        );
      }
      return;
    }

    String? selectedType = remainingTypes.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloodAppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BloodAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_circle, color: BloodAppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Blood Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Blood Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.water_drop),
                ),
                items: remainingTypes
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedType = val),
              ),
              SizedBox(height: 16),
              TextField(
                controller: unitsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Initial Units',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BloodAppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                int? units = int.tryParse(unitsCtrl.text);
                if (selectedType != null && units != null && units >= 0) {
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'availableBloodTypes': FieldValue.arrayUnion([selectedType]),
                      'inventory.$selectedType': {
                        'units': units,
                        'lastUpdated': FieldValue.serverTimestamp(),
                        'status': 'Available'
                      },
                    });

                    Navigator.pop(context);
                    loadInventory();

                    if (mounted) {
                      AppSnackbar.showSuccess(
                        context,
                        '$selectedType Added',
                        subtitle: 'Blood type added to inventory',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackbar.showError(
                        context,
                        'Add Failed',
                        subtitle: e.toString(),
                      );
                    }
                  }
                }
              },
              child: const Text(
                'Add',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, dynamic>> get filteredInventory {
    if (searchQuery.isEmpty) {
      return inventory.entries.toList();
    }
    return inventory.entries
        .where((entry) => entry.key.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  Color getStatusColor(int units) {
    if (units == 0) return BloodAppTheme.error;
    if (units < 5) return BloodAppTheme.warning;
    return BloodAppTheme.success;
  }

  String getStatusText(int units) {
    if (units == 0) return 'Out of Stock';
    if (units < 5) return 'Low Stock';
    return 'In Stock';
  }

  int get totalUnits {
    int total = 0;
    inventory.forEach((key, value) {
      if (value is Map && value['units'] != null) {
        total += (value['units'] as num).toInt();
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: BloodAppTheme.background,
        appBar: AppBar(
          title: const Text(
            'Inventory Management',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: BloodAppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(BloodAppTheme.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: BloodAppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Inventory Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: showAddBloodTypeDialog,
            tooltip: 'Add Blood Type',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadInventory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [BloodAppTheme.primary, BloodAppTheme.primaryDark],
                ),
                borderRadius: BorderRadius.circular(20),
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
                      Icons.inventory_2,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Inventory',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$totalUnits Units',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${inventory.length} Blood Type${inventory.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: BloodAppTheme.cardShadow,
                ),
                child: TextField(
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search blood type...',
                    prefixIcon: const Icon(Icons.search, color: BloodAppTheme.textHint),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Inventory List
            Expanded(
              child: inventory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: BloodAppTheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: BloodAppTheme.primary.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Inventory Data',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: BloodAppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add blood types to start managing your inventory',
                            style: TextStyle(
                              fontSize: 14,
                              color: BloodAppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Add Blood Type',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BloodAppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: showAddBloodTypeDialog,
                          ),
                        ],
                      ),
                    )
                  : filteredInventory.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: BloodAppTheme.textHint,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matching blood types',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: BloodAppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: loadInventory,
                          color: BloodAppTheme.primary,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredInventory.length,
                            itemBuilder: (context, index) {
                              final entry = filteredInventory[index];
                              final bloodType = entry.key;
                              final data = entry.value as Map;
                              final units = data['units'] ?? 0;
                              final statusColor = getStatusColor(units);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: BloodAppTheme.cardShadow,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => showEditDialog(bloodType, units),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Blood Type Badge
                                          Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  BloodAppTheme.primary,
                                                  BloodAppTheme.primaryDark,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: BloodAppTheme.primary.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                bloodType,
                                                style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      '$units',
                                                      style: const TextStyle(
                                                        fontSize: 28,
                                                        fontWeight: FontWeight.bold,
                                                        color: BloodAppTheme.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Text(
                                                      'Units',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: BloodAppTheme.textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: statusColor,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: statusColor,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        getStatusText(units),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: statusColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Action Buttons
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.tune),
                                                color: BloodAppTheme.primary,
                                                onPressed: () => showQuickAdjustDialog(bloodType, units),
                                                tooltip: 'Quick Adjust',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                color: BloodAppTheme.info,
                                                onPressed: () => showEditDialog(bloodType, units),
                                                tooltip: 'Edit',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddBloodTypeDialog,
        backgroundColor: BloodAppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Blood Type',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
