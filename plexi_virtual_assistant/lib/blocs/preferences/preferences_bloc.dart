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
        // First check if we have existing preferences
        UserPreferences mergedPreferences;

        if (state is PreferencesLoaded) {
          // Get current preferences
          final currentPrefs = (state as PreferencesLoaded).preferences;

          // Create merged preferences using copyWith to preserve existing values
          mergedPreferences = currentPrefs.copyWith(
            preferredName:
                event.preferences.preferredName ?? currentPrefs.preferredName,
            monthlySalary:
                event.preferences.monthlySalary ?? currentPrefs.monthlySalary,
            currentWeight:
                event.preferences.currentWeight ?? currentPrefs.currentWeight,
            height: event.preferences.height ?? currentPrefs.height,
            age: event.preferences.age ?? currentPrefs.age,
            dailyCalorieTarget: event.preferences.dailyCalorieTarget ??
                currentPrefs.dailyCalorieTarget,
            weightGoal: event.preferences.weightGoal ?? currentPrefs.weightGoal,
            activityLevel:
                event.preferences.activityLevel ?? currentPrefs.activityLevel,
            targetWeight:
                event.preferences.targetWeight ?? currentPrefs.targetWeight,
            sex: event.preferences.sex ?? currentPrefs.sex,
          );
        } else {
          // No existing preferences, use the new ones directly
          mergedPreferences = event.preferences;
        }

        // Save the merged preferences
        final success =
            await _repository.savePreferences(mergedPreferences.toJson());
        if (success) {
          emit(PreferencesLoaded(mergedPreferences));
        }
      } catch (e) {
        // Keep current state on error
        if (state is PreferencesLoaded) {
          emit(state);
        }
      }
    });
  }
}
