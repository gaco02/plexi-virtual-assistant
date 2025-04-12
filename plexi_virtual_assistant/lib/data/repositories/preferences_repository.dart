import '../models/user_preferences.dart';
import '../../services/api_service.dart';

class PreferencesRepository {
  final ApiService _apiService;

  PreferencesRepository(this._apiService);

  Future<Map<String, dynamic>> getPreferences() async {
    try {
      print('🔍 PreferencesRepository: Fetching user preferences from server');
      final response = await _apiService.get('/api/auth/preferences');
      print(
          '✅ PreferencesRepository: Successfully retrieved preferences: ${response['preferred_name'] ?? 'No name set'}');
      return response;
    } catch (e) {
      print('❌ PreferencesRepository: Error fetching preferences: $e');
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
      print(
          '🔍 PreferencesRepository: Saving preferences to server: ${preferences['preferred_name'] ?? 'No name'}');
      print(
          '💾 PreferencesRepository: Full preferences data being sent: $preferences');

      // First attempt
      try {
        await _apiService.post('/api/auth/preferences', preferences);
        // Immediately fetch updated preferences after saving
        print('🔍 PreferencesRepository: Refreshing preferences after save');
        await getPreferences();
        print('✅ PreferencesRepository: Successfully saved preferences');
        return true;
      } catch (firstError) {
        // Check if it's a foreign key constraint error
        if (firstError.toString().contains('foreign key constraint') ||
            firstError.toString().contains('500')) {
          print(
              '🕐 PreferencesRepository: Detected possible race condition with user creation. Waiting 2 seconds before retry...');

          // Wait for 2 seconds to allow user creation to complete
          await Future.delayed(const Duration(seconds: 2));

          // Second attempt after delay
          try {
            print(
                '🔄 PreferencesRepository: Retrying save preferences after delay');
            await _apiService.post('/api/auth/preferences', preferences);
            print(
                '✅ PreferencesRepository: Successfully saved preferences on retry');
            await getPreferences();
            return true;
          } catch (retryError) {
            print(
                '❌ PreferencesRepository: Error saving preferences on retry: $retryError');
            return false;
          }
        } else {
          // Not a foreign key error, just rethrow
          print(
              '❌ PreferencesRepository: Error saving preferences: $firstError');
          return false;
        }
      }
    } catch (e) {
      print('❌ PreferencesRepository: Unexpected error in savePreferences: $e');
      return false;
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    try {
      final jsonData = preferences.toJson();
      print(
          '🔍 PreferencesRepository: Updating preferences: ${jsonData['preferred_name'] ?? 'No name'}');

      await _apiService.put(
        '/api/auth/preferences',
        jsonData,
      );
      print('✅ PreferencesRepository: Successfully updated preferences');
    } catch (e) {
      print('❌ PreferencesRepository: Failed to update preferences: $e');
      throw Exception('Failed to update preferences: $e');
    }
  }
}
