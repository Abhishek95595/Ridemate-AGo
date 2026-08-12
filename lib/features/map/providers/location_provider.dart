import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_model.dart';
import '../repository/location_repository.dart';
import '../services/location_service.dart';

/// Provider for SharedPreferences instance.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Override in main.dart
});

/// Provider for the current user location.
final userLocationProvider = StateProvider<Position?>((ref) => null);

/// Provider for the LocationService.
final locationServiceProvider = Provider((ref) => LocationService());

/// Provider for the LocationRepository.
final locationRepositoryProvider = Provider((ref) {
  final service = ref.watch(locationServiceProvider);
  final prefs = ref.watch(sharedPrefsProvider);
  return LocationRepository(service, prefs);
});

/// State notifier for managing search logic, debouncing, and UI states.
class LocationSearchNotifier
    extends StateNotifier<AsyncValue<List<LocationModel>>> {
  final LocationRepository _repository;
  Timer? _debounce;
  CancelToken? _cancelToken;

  LocationSearchNotifier(this._repository) : super(const AsyncValue.data([]));

  void onQueryChanged(String query) {
    if (query.isEmpty) {
      state = AsyncValue.data(_repository.getRecentSearches());
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _performSearch(query),
    );
  }

  Future<void> _performSearch(String query) async {
    state = const AsyncValue.loading();

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final results = await _repository.search(
        query,
        cancelToken: _cancelToken,
      );
      state = AsyncValue.data(results);
    } catch (e) {
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}

/// Provider for the search logic.
final locationSearchProvider =
    StateNotifierProvider<
      LocationSearchNotifier,
      AsyncValue<List<LocationModel>>
    >((ref) {
      final repo = ref.watch(locationRepositoryProvider);
      return LocationSearchNotifier(repo);
    });
