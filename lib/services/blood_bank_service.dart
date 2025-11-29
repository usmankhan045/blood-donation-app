import '../models/blood_bank_model.dart';
import '../repositories/blood_bank_repository.dart';

class BloodBankService {
  final BloodBankRepository _repository = BloodBankRepository();

  // Get current blood bank data
  Future<BloodBankModel?> getCurrentBloodBank(String uid) async {
    try {
      return await _repository.getBloodBankByUid(uid);
    } catch (e) {
      print('Error in BloodBankService.getCurrentBloodBank: $e');
      rethrow;
    }
  }

  // Save or update blood bank profile
  Future<void> saveProfile(String uid, BloodBankModel bloodBank) async {
    try {
      await _repository.saveBloodBankProfile(uid, bloodBank);
    } catch (e) {
      print('Error in BloodBankService.saveProfile: $e');
      rethrow;
    }
  }

  // Update inventory units for a blood type
  Future<void> updateBloodTypeUnits(String uid, String bloodType, int units) async {
    try {
      if (units < 0) {
        throw Exception('Units cannot be negative');
      }
      await _repository.updateInventory(uid, bloodType, units);
    } catch (e) {
      print('Error in BloodBankService.updateBloodTypeUnits: $e');
      rethrow;
    }
  }

  // Add units to existing inventory
  Future<void> addUnits(String uid, String bloodType, int unitsToAdd) async {
    try {
      if (unitsToAdd <= 0) {
        throw Exception('Units to add must be positive');
      }

      BloodBankModel? bloodBank = await getCurrentBloodBank(uid);
      if (bloodBank == null) {
        throw Exception('Blood bank not found');
      }

      if (!bloodBank.inventory.containsKey(bloodType)) {
        throw Exception('Blood type not in inventory');
      }

      int currentUnits = bloodBank.inventory[bloodType]['units'] ?? 0;
      int newUnits = currentUnits + unitsToAdd;

      await _repository.updateInventory(uid, bloodType, newUnits);
    } catch (e) {
      print('Error in BloodBankService.addUnits: $e');
      rethrow;
    }
  }

  // Remove units from existing inventory
  Future<void> removeUnits(String uid, String bloodType, int unitsToRemove) async {
    try {
      if (unitsToRemove <= 0) {
        throw Exception('Units to remove must be positive');
      }

      BloodBankModel? bloodBank = await getCurrentBloodBank(uid);
      if (bloodBank == null) {
        throw Exception('Blood bank not found');
      }

      if (!bloodBank.inventory.containsKey(bloodType)) {
        throw Exception('Blood type not in inventory');
      }

      int currentUnits = bloodBank.inventory[bloodType]['units'] ?? 0;
      int newUnits = currentUnits - unitsToRemove;

      if (newUnits < 0) {
        throw Exception('Cannot remove more units than available');
      }

      await _repository.updateInventory(uid, bloodType, newUnits);
    } catch (e) {
      print('Error in BloodBankService.removeUnits: $e');
      rethrow;
    }
  }

  // Add new blood type to inventory
  Future<void> addNewBloodType(String uid, String bloodType, int initialUnits) async {
    try {
      if (initialUnits < 0) {
        throw Exception('Initial units cannot be negative');
      }

      BloodBankModel? bloodBank = await getCurrentBloodBank(uid);
      if (bloodBank == null) {
        throw Exception('Blood bank not found');
      }

      if (bloodBank.inventory.containsKey(bloodType)) {
        throw Exception('Blood type already exists in inventory');
      }

      await _repository.addBloodTypeToInventory(uid, bloodType, initialUnits);
    } catch (e) {
      print('Error in BloodBankService.addNewBloodType: $e');
      rethrow;
    }
  }

  // Remove blood type from inventory
  Future<void> removeBloodType(String uid, String bloodType) async {
    try {
      await _repository.removeBloodTypeFromInventory(uid, bloodType);
    } catch (e) {
      print('Error in BloodBankService.removeBloodType: $e');
      rethrow;
    }
  }

  // Get all blood banks
  Future<List<BloodBankModel>> getAllBloodBanks() async {
    try {
      return await _repository.getAllBloodBanks();
    } catch (e) {
      print('Error in BloodBankService.getAllBloodBanks: $e');
      rethrow;
    }
  }

  // Get blood banks by city
  Future<List<BloodBankModel>> getBloodBanksByCity(String city) async {
    try {
      return await _repository.getBloodBanksByCity(city);
    } catch (e) {
      print('Error in BloodBankService.getBloodBanksByCity: $e');
      rethrow;
    }
  }

  // Search for blood banks with specific blood type in stock
  Future<List<BloodBankModel>> findBloodBanksByBloodType(String bloodType) async {
    try {
      return await _repository.searchBloodBanksByBloodType(bloodType);
    } catch (e) {
      print('Error in BloodBankService.findBloodBanksByBloodType: $e');
      rethrow;
    }
  }

  // Get blood bank statistics
  Future<Map<String, dynamic>> getStatistics(String uid) async {
    try {
      return await _repository.getBloodBankStats(uid);
    } catch (e) {
      print('Error in BloodBankService.getStatistics: $e');
      rethrow;
    }
  }

  // Stream blood bank for real-time updates
  Stream<BloodBankModel?> streamBloodBank(String uid) {
    return _repository.streamBloodBank(uid);
  }

  // Check if profile is complete
  Future<bool> isProfileComplete(String uid) async {
    try {
      return await _repository.isProfileComplete(uid);
    } catch (e) {
      print('Error in BloodBankService.isProfileComplete: $e');
      return false;
    }
  }

  // Validate inventory data
  bool validateInventoryData(Map<String, int> inventory) {
    for (var entry in inventory.entries) {
      if (entry.value < 0) {
        return false;
      }
    }
    return true;
  }

  // Batch update multiple blood types
  Future<void> batchUpdateInventory(String uid, Map<String, int> updates) async {
    try {
      if (!validateInventoryData(updates)) {
        throw Exception('Invalid inventory data: negative units not allowed');
      }

      await _repository.batchUpdateInventory(uid, updates);
    } catch (e) {
      print('Error in BloodBankService.batchUpdateInventory: $e');
      rethrow;
    }
  }

  // Get low stock alerts
  Future<List<String>> getLowStockAlerts(String uid) async {
    try {
      BloodBankModel? bloodBank = await getCurrentBloodBank(uid);
      if (bloodBank == null) {
        return [];
      }
      return bloodBank.lowStockBloodTypes;
    } catch (e) {
      print('Error in BloodBankService.getLowStockAlerts: $e');
      return [];
    }
  }

  // Get out of stock blood types
  Future<List<String>> getOutOfStockTypes(String uid) async {
    try {
      BloodBankModel? bloodBank = await getCurrentBloodBank(uid);
      if (bloodBank == null) {
        return [];
      }
      return bloodBank.outOfStockBloodTypes;
    } catch (e) {
      print('Error in BloodBankService.getOutOfStockTypes: $e');
      return [];
    }
  }
}