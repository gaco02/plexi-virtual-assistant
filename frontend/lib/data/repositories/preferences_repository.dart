import '../models/user_preferences.dart';
import '../../services/api_service.dart';

class PreferencesRepository {
  final ApiService _apiService;

  PreferencesRepository(this._apiService);

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await _apiService.get('/api/auth/preferences');
      return response;
    } catch (e) {
      // Return empty preferences instead of throwing
      return {
        'preferred_name': null,
        'monthly_salary': null,
        'current_weight': null,
        'height': null,
        'age': null,
        'daily_calorie_target': null,
        'weight_goal': null,
        'activity_level': null,
        'target_weight': null,
        'sex': null,
      };
    }
  }

  Future<bool> savePreferences(Map<String, dynamic> preferences) async {
    try {
      print('DEBUG: Attempting to save preferences: $preferences');
      // First attempt
      try {
        print('DEBUG: Making first API call to /api/auth/preferences');
        await _apiService.post('/api/auth/preferences', preferences);
        print('DEBUG: First API call successful');

        // Immediately fetch updated preferences after saving
        await getPreferences();
        print('DEBUG: Successfully saved and fetched preferences');
        return true;
      } catch (firstError) {
        print('DEBUG: First attempt failed with error: $firstError');
        // Check if it's a foreign key constraint error
        if (firstError.toString().contains('foreign key constraint') ||
            firstError.toString().contains('500')) {
          print(
              'DEBUG: Detected foreign key constraint error, retrying after delay');
          // Wait for 2 seconds to allow user creation to complete
          await Future.delayed(const Duration(seconds: 2));

          // Second attempt after delay
          try {
            print('DEBUG: Making second API call after delay');
            await _apiService.post('/api/auth/preferences', preferences);
            await getPreferences();
            print('DEBUG: Second attempt successful');
            return true;
          } catch (retryError) {
            print('DEBUG: Second attempt also failed: $retryError');
            return false;
          }
        } else {
          // Not a foreign key error, just rethrow
          print('DEBUG: Not a foreign key error, returning false');
          return false;
        }
      }
    } catch (e) {
      print('DEBUG: Outer catch block error: $e');
      return false;
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    try {
      final jsonData = preferences.toJson();

      await _apiService.post('/api/auth/preferences', jsonData);
    } catch (e) {
      throw Exception('Failed to update preferences: $e');
    }
  }
}
