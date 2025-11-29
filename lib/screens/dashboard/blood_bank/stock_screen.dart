import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$bloodType updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void showEditDialog(String bloodType, int currentUnits) {
    final TextEditingController controller = TextEditingController(text: currentUnits.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF67D5B5)),
            SizedBox(width: 12),
            Text('Update $bloodType Units'),
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
              backgroundColor: Color(0xFF67D5B5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              int? newUnits = int.tryParse(controller.text);
              if (newUnits != null && newUnits >= 0) {
                updateUnits(bloodType, newUnits);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid number')),
                );
              }
            },
            child: Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void showQuickAdjustDialog(String bloodType, int currentUnits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.tune, color: Color(0xFF67D5B5)),
            SizedBox(width: 12),
            Text('Quick Adjust $bloodType'),
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
        backgroundColor: color ?? Color(0xFF67D5B5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  void showAddBloodTypeDialog() {
    final TextEditingController bloodTypeCtrl = TextEditingController();
    final TextEditingController unitsCtrl = TextEditingController(text: '0');

    final List<String> allBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    final List<String> remainingTypes = allBloodTypes
        .where((type) => !availableBloodTypes.contains(type))
        .toList();

    if (remainingTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All blood types are already added')),
      );
      return;
    }

    String? selectedType = remainingTypes.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.add_circle, color: Color(0xFF67D5B5)),
              SizedBox(width: 12),
              Text('Add Blood Type'),
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
                backgroundColor: Color(0xFF67D5B5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$selectedType added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text('Add', style: TextStyle(color: Colors.white)),
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
    if (units == 0) return Colors.grey;
    if (units < 5) return Colors.orange;
    return Colors.green;
  }

  String getStatusText(int units) {
    if (units == 0) return 'Out of Stock';
    if (units < 5) return 'Low Stock';
    return 'Available';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF6F9FB),
        appBar: AppBar(
          title: Text('Inventory Management'),
          backgroundColor: Color(0xFF67D5B5),
        ),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF67D5B5))),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF6F9FB),
      appBar: AppBar(
        title: Text('Inventory Management'),
        backgroundColor: Color(0xFF67D5B5),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: showAddBloodTypeDialog,
            tooltip: 'Add Blood Type',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: loadInventory,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Container(
                color: Color(0xFF67D5B5),
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  onChanged: (value) => setState(() => searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search blood type...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Inventory List
              Expanded(
                child: inventory.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No inventory data',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text('Add Blood Type', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF67D5B5),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: showAddBloodTypeDialog,
                      ),
                    ],
                  ),
                )
                    : filteredInventory.isEmpty
                    ? Center(
                  child: Text(
                    'No matching blood types',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: loadInventory,
                  color: Color(0xFF67D5B5),
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredInventory.length,
                    itemBuilder: (context, index) {
                      final entry = filteredInventory[index];
                      final bloodType = entry.key;
                      final data = entry.value as Map;
                      final units = data['units'] ?? 0;

                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Color(0xFF67D5B5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                bloodType,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF67D5B5),
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$units Units',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis, // Prevent overflow
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: getStatusColor(units).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: getStatusColor(units),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  getStatusText(units),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: getStatusColor(units),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Last updated: ${data['lastUpdated'] != null ? 'Recently' : 'N/A'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.speed, color: Color(0xFF67D5B5)),
                                onPressed: () => showQuickAdjustDialog(bloodType, units),
                                tooltip: 'Quick Adjust',
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => showEditDialog(bloodType, units),
                                tooltip: 'Edit',
                              ),
                            ],
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddBloodTypeDialog,
        backgroundColor: Color(0xFF67D5B5),
        foregroundColor: Colors.white,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('Add Blood Type', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
