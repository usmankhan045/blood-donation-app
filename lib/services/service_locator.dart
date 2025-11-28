// services/service_locator.dart
import 'donor_matching_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late DonorMatchingService _donorMatchingService;

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) {
      print('⚠️ ServiceLocator already initialized');
      return;
    }

    print('🔄 Initializing ServiceLocator...');

    // ✅ Create service instances
    _donorMatchingService = DonorMatchingService();

    _isInitialized = true;
    print('✅ ServiceLocator initialized successfully');
  }

  // Getters for services
  static DonorMatchingService get donorMatching => _instance._donorMatchingService;

  // Check if services are ready
  static bool get isInitialized => _instance._isInitialized;

  // Reset for testing
  static void reset() {
    _instance._isInitialized = false;
    print('🔄 ServiceLocator reset');
  }
}