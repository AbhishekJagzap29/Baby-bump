import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/auth_api_service.dart';
import '../core/network/bump_api_service.dart';
import '../database/app_database.dart';
import '../features/auth/auth_provider.dart';
import '../models/bump_entry.dart';

class BumpRepository {
  final AppDatabase _db = AppDatabase.instance;
  final BumpApiService _apiService;

  BumpRepository({BumpApiService? apiService})
      : _apiService = apiService ?? BumpApiService();

  /// Fetches bump logs with priority given to the remote server API,
  /// syncing incoming records to local SQLite and falling back to SQLite if offline.
  Future<List<BumpEntry>> getAllEntries({
    int? uid,
    String? date,
    void Function(UserLogCounts counts)? onCountsReceived,
  }) async {
    try {
      final res = await _apiService.getBumpLogs(uid: uid, date: date);
      if (res.success && res.data.isNotEmpty) {
        if (res.userLogCounts != null && onCountsReceived != null) {
          onCountsReceived(res.userLogCounts!);
        }

        // Cache remote records into local SQLite for offline resilience
        for (final entry in res.data) {
          try {
            await _db.insertBump(entry);
          } catch (_) {
            // Already cached or conflict ignored
          }
        }
        return res.data;
      } else if (res.success && res.data.isEmpty) {
        if (res.userLogCounts != null && onCountsReceived != null) {
          onCountsReceived(res.userLogCounts!);
        }
        return [];
      }
    } catch (_) {
      // Network failure, fallback to local storage
    }

    // Fallback: local SQLite records
    if (date != null && date.isNotEmpty) {
      return _db.getEntriesByDate(date);
    }
    return _db.getAllEntries();
  }

  /// Saves entry locally in SQLite, then synchronizes to the remote Odoo server.
  Future<CreateBumpResponse> addEntry(BumpEntry entry, {int? uid}) async {
    // 1. Insert locally first for instant offline readiness
    int? localId;
    try {
      localId = await _db.insertBump(entry);
    } catch (_) {}

    final localEntry = entry.copyWith(id: localId ?? entry.id);

    // 2. Sync to server API
    final apiResponse = await _apiService.createBumpLog(entry: localEntry, uid: uid);

    if (apiResponse.success && apiResponse.entry != null) {
      // Update local entry with server ID
      try {
        await _db.insertBump(apiResponse.entry!);
      } catch (_) {}
      return apiResponse;
    }

    // If server call was offline/unreachable, entry is safely stored locally
    if (apiResponse.error == 'Network Error' || apiResponse.error == 'Timeout') {
      return CreateBumpResponse(
        success: true,
        message: 'Bump logged locally (offline mode).',
        entry: localEntry,
      );
    }

    return apiResponse;
  }
}

final bumpApiServiceProvider = Provider<BumpApiService>((ref) {
  final authService = ref.watch(authApiServiceProvider);
  return BumpApiService(authService: authService);
});

final bumpRepositoryProvider = Provider<BumpRepository>((ref) {
  final apiService = ref.watch(bumpApiServiceProvider);
  return BumpRepository(apiService: apiService);
});

/// Holds the latest user log counts returned by the backend:
/// today_logs_count, total_logs_count, today_bumps_count, total_bumps_count
final userLogCountsProvider = StateProvider<UserLogCounts?>((ref) => null);

class BumpEntriesNotifier extends StateNotifier<AsyncValue<List<BumpEntry>>> {
  final BumpRepository _repository;
  final Ref _ref;

  BumpEntriesNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadEntries();
  }

  Future<void> loadEntries({int? uid, String? date}) async {
    try {
      state = const AsyncValue.loading();
      final user = _ref.read(authProvider).currentUser;
      final effectiveUid = uid ?? user?.uid;
      if (user?.sessionId != null && user!.sessionId!.isNotEmpty) {
        AuthApiService.setSessionId(user.sessionId);
      }
      final entries = await _repository.getAllEntries(
        uid: effectiveUid,
        date: date,
        onCountsReceived: (counts) {
          _ref.read(userLogCountsProvider.notifier).state = counts;
        },
      );
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<CreateBumpResponse> addEntry(BumpEntry entry, {int? uid}) async {
    final user = _ref.read(authProvider).currentUser;
    final effectiveUid = uid ?? user?.uid;
    if (user?.sessionId != null && user!.sessionId!.isNotEmpty) {
      AuthApiService.setSessionId(user.sessionId);
    }

    final response = await _repository.addEntry(entry, uid: effectiveUid);

    // Update user log counts from server response if available
    if (response.userLogCounts != null) {
      _ref.read(userLogCountsProvider.notifier).state = response.userLogCounts;
    }

    await loadEntries(uid: effectiveUid);
    return response;
  }
}

final bumpEntriesProvider =
    StateNotifierProvider<BumpEntriesNotifier, AsyncValue<List<BumpEntry>>>((ref) {
  final repo = ref.watch(bumpRepositoryProvider);
  return BumpEntriesNotifier(repo, ref);
});

// Computed provider for today's entries
final todayEntriesProvider = Provider<List<BumpEntry>>((ref) {
  final allAsync = ref.watch(bumpEntriesProvider);
  return allAsync.maybeWhen(
    data: (entries) {
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      return entries.where((e) => e.date == todayStr).toList();
    },
    orElse: () => [],
  );
});

// Computed provider for grouped history
final groupedHistoryProvider = Provider<Map<String, List<BumpEntry>>>((ref) {
  final allAsync = ref.watch(bumpEntriesProvider);
  return allAsync.maybeWhen(
    data: (entries) {
      final map = <String, List<BumpEntry>>{};
      for (final e in entries) {
        if (!map.containsKey(e.date)) {
          map[e.date] = [];
        }
        map[e.date]!.add(e);
      }
      return map;
    },
    orElse: () => {},
  );
});
