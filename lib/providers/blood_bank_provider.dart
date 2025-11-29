import 'package:flutter/foundation.dart';
import '../models/blood_bank_model.dart';
import '../services/blood_bank_service.dart';

class BloodBankProvider with ChangeNotifier {
  final BloodBankService _service = BloodBankService();

  BloodBankModel? _currentBloodBank;
  Map<String, dynamic>? _statistics;
  bool _isLoading = false;
  String? _error;

  // Getters
  BloodBankModel? get currentBloodBank => _currentBloodBank;
  Map<String, dynamic>? get statistics => _statistics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasBloodBank => _currentBloodBank != null;
  bool get isProfileComplete => _currentBloodBank?.profileCompleted ?? false;

  // Load blood bank data
  Future<void> loadBloodBank(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentBloodBank = await _service.getCurrentBloodBank(uid);

      if (_currentBloodBank != null) {
        await loadStatistics(uid);
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading blood bank: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load statistics
  Future<void> loadStatistics(String uid) async {
    try {
      _statistics = await _service.getStatistics(uid);
      notifyListeners();
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  // Save profile
  Future<bool> saveProfile(String uid, BloodBankModel bloodBank) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.saveProfile(uid, bloodBank);
      _currentBloodBank = bloodBank;

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error saving profile: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update inventory for a blood type
  Future<bool> updateInventory(String uid, String bloodType, int units) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.updateBloodTypeUnits(uid, bloodType, units);
      await loadBloodBank(uid); // Reload to get updated data

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error updating inventory: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add units to inventory
  Future<bool> addUnits(String uid, String bloodType, int unitsToAdd) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.addUnits(uid, bloodType, unitsToAdd);
      await loadBloodBank(uid);

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error adding units: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove units from inventory
  Future<bool> removeUnits(String uid, String bloodType, int unitsToRemove) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.removeUnits(uid, bloodType, unitsToRemove);
      await loadBloodBank(uid);

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error removing units: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new blood type
  Future<bool> addNewBloodType(String uid, String bloodType, int initialUnits) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.addNewBloodType(uid, bloodType, initialUnits);
      await loadBloodBank(uid);

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error adding blood type: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove blood type
  Future<bool> removeBloodType(String uid, String bloodType) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.removeBloodType(uid, bloodType);
      await loadBloodBank(uid);

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error removing blood type: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Batch update inventory
  Future<bool> batchUpdateInventory(String uid, Map<String, int> updates) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _service.batchUpdateInventory(uid, updates);
      await loadBloodBank(uid);

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error batch updating inventory: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get low stock alerts
  List<String> getLowStockAlerts() {
    return _currentBloodBank?.lowStockBloodTypes ?? [];
  }

  // Get out of stock types
  List<String> getOutOfStockTypes() {
    return _currentBloodBank?.outOfStockBloodTypes ?? [];
  }

  // Get available stock
  Map<String, int> getAvailableStock() {
    return _currentBloodBank?.availableStock ?? {};
  }

  // Get total units
  int getTotalUnits() {
    return _currentBloodBank?.totalUnits ?? 0;
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Refresh data
  Future<void> refresh(String uid) async {
    await loadBloodBank(uid);
  }

  // Clear all data
  void clear() {
    _currentBloodBank = null;
    _statistics = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}