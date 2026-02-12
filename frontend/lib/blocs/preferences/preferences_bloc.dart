import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_preferences.dart';
import '../../data/repositories/preferences_repository.dart';

// Events
abstract class PreferencesEvent {}

class LoadPreferences extends PreferencesEvent {}

class SavePreferences extends PreferencesEvent {
  final UserPreferences preferences;
  SavePreferences(this.preferences);
}

class UpdatePreference extends PreferencesEvent {
  final UserPreferences Function(UserPreferences) update;
  UpdatePreference(this.update);
}

// States
abstract class PreferencesState {}

class PreferencesInitial extends PreferencesState {}

class PreferencesLoading extends PreferencesState {}

class PreferencesLoaded extends PreferencesState {
  final UserPreferences preferences;
  PreferencesLoaded(this.preferences);
}

class PreferencesError extends PreferencesState {
  final String message;
  PreferencesError(this.message);
}

// Bloc
class PreferencesBloc extends Bloc<PreferencesEvent, PreferencesState> {
  final PreferencesRepository _repository;

  PreferencesBloc(this._repository) : super(PreferencesInitial()) {
    on<LoadPreferences>((event, emit) async {
      try {
        emit(PreferencesLoading());
        final prefs = await _repository.getPreferences();
        emit(PreferencesLoaded(UserPreferences.fromJson(prefs)));
      } catch (e) {
        // Emit empty preferences instead of error
        emit(PreferencesLoaded(UserPreferences()));
      }
    });

    on<UpdatePreference>((event, emit) async {
      try {
        if (state is PreferencesLoaded) {
          final currentPrefs = (state as PreferencesLoaded).preferences;
          final updatedPrefs = event.update(currentPrefs);
          await _repository.updatePreferences(updatedPrefs);
          emit(PreferencesLoaded(updatedPrefs));
        }
      } catch (e) {
        emit(PreferencesError(e.toString()));
      }
    });

    on<SavePreferences>((event, emit) async {
      try {
        print(
            'DEBUG: SavePreferences event received with name: ${event.preferences.preferredName}');

        // First check if we have existing preferences
        UserPreferences mergedPreferences;

        if (state is PreferencesLoaded) {
          // Get current preferences
          final currentPrefs = (state as PreferencesLoaded).preferences;
          print('DEBUG: Current preferences: ${currentPrefs.preferredName}');

          // Create merged preferences - use new values if provided, otherwise keep current ones
          mergedPreferences = currentPrefs.copyWith(
            preferredName: event.preferences.preferredName,
            monthlySalary: event.preferences.monthlySalary,
            currentWeight: event.preferences.currentWeight,
            height: event.preferences.height,
            age: event.preferences.age,
            dailyCalorieTarget: event.preferences.dailyCalorieTarget,
            weightGoal: event.preferences.weightGoal,
            activityLevel: event.preferences.activityLevel,
            targetWeight: event.preferences.targetWeight,
            sex: event.preferences.sex,
          );
        } else {
          // No existing preferences, use the new ones directly
          mergedPreferences = event.preferences;
        }

        print(
            'DEBUG: Merged preferences name: ${mergedPreferences.preferredName}');
        print('DEBUG: Saving preferences to repository...');

        // Save the merged preferences
        final success =
            await _repository.savePreferences(mergedPreferences.toJson());
        print('DEBUG: Save result: $success');

        if (success) {
          print('DEBUG: Emitting PreferencesLoaded state');
          emit(PreferencesLoaded(mergedPreferences));
        } else {
          print('DEBUG: Save failed, emitting error');
          emit(PreferencesError('Failed to save preferences'));
        }
      } catch (e) {
        print('DEBUG: Exception in SavePreferences: $e');
        emit(PreferencesError('Error saving preferences: $e'));
      }
    });
  }
}
