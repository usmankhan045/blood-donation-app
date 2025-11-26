class BloodCompatibilityService {
  // Blood type compatibility matrix
  // Key: Recipient blood type, Value: List of compatible donor blood types
  static final Map<String, List<String>> _compatibilityMap = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], // Universal recipient
    'AB-': ['A-', 'B-', 'AB-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'], // Universal donor
  };

  /// Check if a donor can donate to a recipient
  static bool canDonate(String donorBloodType, String recipientBloodType) {
    return _compatibilityMap[recipientBloodType]?.contains(donorBloodType) ?? false;
  }

  /// Get all compatible donor blood types for a recipient
  static List<String> getCompatibleDonorTypes(String recipientBloodType) {
    return _compatibilityMap[recipientBloodType] ?? [];
  }

  /// Get compatibility description
  static String getCompatibilityDescription(String recipientBloodType) {
    final compatibleTypes = getCompatibleDonorTypes(recipientBloodType);

    if (compatibleTypes.isEmpty) return 'No compatible donors';
    if (compatibleTypes.length == 1 && compatibleTypes.first == 'O-') {
      return 'Only O- donors (Universal donor)';
    }
    if (compatibleTypes.length == 8) {
      return 'All blood types (Universal recipient)';
    }

    return 'Compatible with: ${compatibleTypes.join(', ')}';
  }

  /// Get priority score for matching (higher = better match)
  static int getMatchPriority(String donorBloodType, String recipientBloodType) {
    if (!canDonate(donorBloodType, recipientBloodType)) return 0;

    // Priority: Exact match > same type different Rh > universal donor
    if (donorBloodType == recipientBloodType) return 3; // Exact match
    if (donorBloodType == 'O-') return 2; // Universal donor
    if (donorBloodType[0] == recipientBloodType[0]) return 1; // Same ABO type

    return 1; // Compatible but different type
  }
}