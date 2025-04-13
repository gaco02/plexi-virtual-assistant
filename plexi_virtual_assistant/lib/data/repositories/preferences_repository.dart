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
      // First attempt
      try {
        await _apiService.post('/api/auth/preferences', preferences);
        // Immediately fetch updated preferences after saving

        await getPreferences();

        return true;
      } catch (firstError) {
        // Check if it's a foreign key constraint error
        if (firstError.toString().contains('foreign key constraint') ||
            firstError.toString().contains('500')) {
          // Wait for 2 seconds to allow user creation to complete
          await Future.delayed(const Duration(seconds: 2));

          // Second attempt after delay
          try {
            await _apiService.post('/api/auth/preferences', preferences);
            await getPreferences();
            return true;
          } catch (retryError) {
            return false;
          }
        } else {
          // Not a foreign key error, just rethrow
          return false;
        }
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    try {
      final jsonData = preferences.toJson();

      await _apiService.put(
        '/api/auth/preferences',
        jsonData,
      );
    } catch (e) {
      throw Exception('Failed to update preferences: $e');
    }
  }
}
