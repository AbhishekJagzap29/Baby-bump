import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../../models/bump_entry.dart';
import 'auth_api_service.dart';

class BumpApiService {
  final http.Client _client;
  final AuthApiService _authService;

  BumpApiService({
    http.Client? client,
    AuthApiService? authService,
  })  : _client = client ?? http.Client(),
        _authService = authService ?? AuthApiService();

  /// Retrieves logged baby bumps from GET /api/bump/logs
  ///
  /// Query parameters:
  /// - [uid]: User ID (defaults to session user if logged in)
  /// - [date]: Optional single date filter (YYYY-MM-DD)
  /// - [startDate]: Optional start date filter (YYYY-MM-DD)
  /// - [endDate]: Optional end date filter (YYYY-MM-DD)
  /// - [locationId]: Optional location ID
  /// - [page]: Page number (default 1)
  /// - [limit]: Number of records per page (default 20)
  /// - [db]: Database name (defaults to ApiRouts.databaseName)
  /// - [sessionId]: Explicit session ID (optional)
  Future<BumpLogsResponse> getBumpLogs({
    int? uid,
    String? date,
    String? startDate,
    String? endDate,
    int? locationId,
    int page = 1,
    int limit = 50,
    String? db,
    String? sessionId,
    bool isRetry = false,
  }) async {
    final targetDb = db ?? ApiRouts.databaseName;

    try {
      // 1. Ensure active session bound to target database
      String? activeSid = sessionId ?? _authService.currentSessionId;
      if (activeSid == null || activeSid.isEmpty) {
        activeSid = await _authService.ensureSession(db: targetDb);
      }

      final queryParams = <String, String>{
        'db': targetDb,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (uid != null) {
        queryParams['uid'] = uid.toString();
        queryParams['user_id'] = uid.toString();
      }
      if (activeSid != null && activeSid.isNotEmpty) {
        queryParams['session_id'] = activeSid;
      }
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['start_date'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['end_date'] = endDate;
      }
      if (locationId != null) {
        queryParams['location_id'] = locationId.toString();
      }

      final baseUri = Uri.parse(ApiRouts.getBumpLogs);
      final uri = baseUri.replace(queryParameters: queryParams);

      final headers = <String, String>{
        'Accept': 'application/json',
      };

      if (activeSid != null && activeSid.isNotEmpty) {
        headers['Cookie'] = 'session_id=$activeSid';
      }

      final response = await _client.get(uri, headers: headers).timeout(ApiRouts.timeout);

      // If server returned 404 (due to expired session cookie in Odoo multi-db),
      // refresh session and retry once
      if (response.statusCode == 404 && !isRetry) {
        _authService.clearSession();
        final refreshedSid = await _authService.ensureSession(db: targetDb);
        if (refreshedSid != null && refreshedSid.isNotEmpty) {
          return getBumpLogs(
            uid: uid,
            date: date,
            startDate: startDate,
            endDate: endDate,
            locationId: locationId,
            page: page,
            limit: limit,
            db: targetDb,
            sessionId: refreshedSid,
            isRetry: true,
          );
        }
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return BumpLogsResponse.fromJson(body);
      } else if (response.statusCode == 401) {
        return BumpLogsResponse.failure(
          message: 'Authentication required. Please sign in.',
          error: 'Unauthorized',
        );
      } else {
        return BumpLogsResponse.failure(
          message: 'Failed to fetch bump logs (HTTP ${response.statusCode})',
          error: 'HTTP_${response.statusCode}',
        );
      }
    } on SocketException {
      return BumpLogsResponse.failure(
        message: 'Could not connect to server. Showing local records.',
        error: 'Network Error',
      );
    } on TimeoutException {
      return BumpLogsResponse.failure(
        message: 'Connection timed out. Showing local records.',
        error: 'Timeout',
      );
    } catch (e) {
      return BumpLogsResponse.failure(
        message: 'Failed to fetch logs: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Logs a new baby bump entry to POST /api/bump/create (or /api/bump/log)
  ///
  /// Expected payload:
  /// - date (YYYY-MM-DD, defaults to today)
  /// - day (Monday..Sunday)
  /// - time (HH:MM in 24h format)
  /// - bump_location / location_id / location (name or ID)
  /// - bump_count (positive integer >= 1)
  /// - observation (optional)
  /// - note / notes (optional)
  /// - uid / user_id
  /// - db (target database name)
  Future<CreateBumpResponse> createBumpLog({
    required BumpEntry entry,
    int? uid,
    String? db,
    String? sessionId,
    bool isRetry = false,
  }) async {
    final targetDb = db ?? ApiRouts.databaseName;

    try {
      String? activeSid = sessionId ?? _authService.currentSessionId;
      if (activeSid == null || activeSid.isEmpty) {
        activeSid = await _authService.ensureSession(db: targetDb);
      }

      final queryParams = <String, String>{
        'db': targetDb,
        if (uid != null) 'uid': uid.toString(),
        if (uid != null) 'user_id': uid.toString(),
        if (activeSid != null && activeSid.isNotEmpty) 'session_id': activeSid,
      };

      final baseUri = Uri.parse(ApiRouts.createBumpLog);
      final uri = baseUri.replace(queryParameters: queryParams);

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (activeSid != null && activeSid.isNotEmpty) {
        headers['Cookie'] = 'session_id=$activeSid';
      }

      final body = jsonEncode(entry.toApiPayload(uid: uid, db: targetDb));

      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(ApiRouts.timeout);

      // If server returned 404 (due to expired session cookie in Odoo multi-db),
      // refresh session and retry once
      if (response.statusCode == 404 && !isRetry) {
        _authService.clearSession();
        final refreshedSid = await _authService.ensureSession(db: targetDb);
        if (refreshedSid != null && refreshedSid.isNotEmpty) {
          return createBumpLog(
            entry: entry,
            uid: uid,
            db: targetDb,
            sessionId: refreshedSid,
            isRetry: true,
          );
        }
      }

      Map<String, dynamic> resBody;
      try {
        resBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return CreateBumpResponse.failure(
          message: 'Server returned unexpected response (${response.statusCode}).',
          error: 'Invalid JSON',
          entry: entry,
        );
      }

      final isSuccess = resBody['success'] == true;
      final message = resBody['message']?.toString() ??
          (isSuccess ? 'Baby bump logged successfully.' : 'Failed to log baby bump.');

      if (isSuccess && (response.statusCode == 200 || response.statusCode == 201)) {
        final data = resBody['data'] is Map<String, dynamic>
            ? resBody['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        final savedEntry = BumpEntry.fromMap(data);

        final counts = resBody['user_log_counts'] is Map
            ? UserLogCounts.fromJson(Map<String, dynamic>.from(resBody['user_log_counts']))
            : null;

        return CreateBumpResponse.success(
          entry: savedEntry,
          message: message,
          userLogCounts: counts,
        );
      } else {
        return CreateBumpResponse.failure(
          message: message,
          error: resBody['error']?.toString(),
          entry: entry,
        );
      }
    } on SocketException {
      return CreateBumpResponse.failure(
        message: 'Saved locally. Could not connect to server.',
        error: 'Network Error',
        entry: entry,
      );
    } on TimeoutException {
      return CreateBumpResponse.failure(
        message: 'Saved locally. Server connection timed out.',
        error: 'Timeout',
        entry: entry,
      );
    } catch (e) {
      return CreateBumpResponse.failure(
        message: 'Saved locally. Error: ${e.toString()}',
        error: e.toString(),
        entry: entry,
      );
    }
  }
}
