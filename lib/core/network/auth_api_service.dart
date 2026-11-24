import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/api_constants.dart';
import '../../models/user_model.dart';

class AuthResponse {
  final bool success;
  final String message;
  final String? error;
  final UserModel? user;
  final String? sessionId;

  const AuthResponse({
    required this.success,
    required this.message,
    this.error,
    this.user,
    this.sessionId,
  });

  factory AuthResponse.success({
    required UserModel user,
    String message = 'Login successful.',
    String? sessionId,
  }) {
    return AuthResponse(
      success: true,
      message: message,
      user: user,
      sessionId: sessionId ?? user.sessionId,
    );
  }

  factory AuthResponse.failure({
    required String message,
    String? error,
  }) {
    return AuthResponse(
      success: false,
      message: message,
      error: error,
    );
  }
}

class AuthApiService {
  final http.Client _client;
  static String? _currentSessionId;

  AuthApiService({http.Client? client}) : _client = client ?? http.Client();

  String? get currentSessionId => _currentSessionId;

  static void setSessionId(String? sid) {
    _currentSessionId = sid;
  }

  /// Ensures a valid Odoo session cookie exists bound to the target database
  Future<String?> ensureSession({
    String? webLoginUrl,
    String? db,
  }) async {
    if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
      return _currentSessionId;
    }

    try {
      final targetDb = db ?? ApiRouts.databaseName;
      final targetUrl = webLoginUrl ?? ApiRouts.webLogin;
      final uri = Uri.parse('$targetUrl?db=$targetDb');
      final request = http.Request('GET', uri)..followRedirects = false;

      final streamedResponse = await _client.send(request).timeout(ApiRouts.timeout);
      final rawCookie = streamedResponse.headers['set-cookie'];

      if (rawCookie != null && rawCookie.isNotEmpty) {
        _currentSessionId = _extractSessionId(rawCookie);
      }
      return _currentSessionId;
    } catch (_) {
      // In case session initialization fails, continue to attempt direct login
      return _currentSessionId;
    }
  }

  /// Extracts the session_id token from the Set-Cookie header
  String? _extractSessionId(String setCookieHeader) {
    final match = RegExp(r'session_id=([a-zA-Z0-9_-]+)').firstMatch(setCookieHeader);
    return match?.group(1);
  }

  /// Calls the Odoo REST Login API endpoint:
  /// POST ApiRouts.loginAPI
  ///
  /// Expected payload:
  /// {
  ///   "username": "user@example.com",
  ///   "password": "yourpassword",
  ///   "db": "baby"
  /// }
  Future<AuthResponse> login({
    required String username,
    required String password,
    String? db,
    String? loginUrl,
  }) async {
    final trimmedUser = username.trim();
    final trimmedPass = password.trim();
    final targetDb = db ?? ApiRouts.databaseName;
    final targetEndpoint = loginUrl ?? ApiRouts.loginAPI;

    if (trimmedUser.isEmpty || trimmedPass.isEmpty) {
      return AuthResponse.failure(
        message: 'Both username and password are required.',
        error: 'Missing credentials',
      );
    }

    try {
      // 1. Initialize Odoo session for multi-db routing if needed
      if (_currentSessionId == null) {
        await ensureSession(db: targetDb);
      }

      // 2. Prepare headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (_currentSessionId != null && _currentSessionId!.isNotEmpty) {
        headers['Cookie'] = 'session_id=$_currentSessionId';
      }

      // 3. Prepare payload matching server expectations
      final body = jsonEncode({
        'username': trimmedUser,
        'login': trimmedUser,
        'password': trimmedPass,
        'db': targetDb,
      });

      final endpoint = Uri.parse(targetEndpoint);
      final response = await _client
          .post(endpoint, headers: headers, body: body)
          .timeout(ApiRouts.timeout);

      // Check for session update in response headers
      final responseCookie = response.headers['set-cookie'];
      if (responseCookie != null && responseCookie.isNotEmpty) {
        final newSid = _extractSessionId(responseCookie);
        if (newSid != null) {
          _currentSessionId = newSid;
        }
      }

      // 4. Parse response
      Map<String, dynamic> jsonResponse;
      try {
        jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        if (response.statusCode == 404) {
          return AuthResponse.failure(
            message: 'Server login endpoint not found (404). Please verify server route.',
            error: 'Not Found',
          );
        }
        return AuthResponse.failure(
          message: 'Server returned an invalid response (HTTP ${response.statusCode}).',
          error: 'Invalid Response',
        );
      }

      final isSuccess = jsonResponse['success'] == true;
      final message = jsonResponse['message']?.toString() ??
          (isSuccess ? 'Login successful.' : 'Authentication failed.');

      if (isSuccess && response.statusCode == 200) {
        final data = jsonResponse['data'];
        final Map<String, dynamic> userData =
            data is Map<String, dynamic> ? data : <String, dynamic>{};

        // Extract session ID if returned inside data payload
        final sid = userData['session_id']?.toString() ?? _currentSessionId;
        if (sid != null && sid.isNotEmpty) {
          _currentSessionId = sid;
        }

        final user = UserModel.fromJson(
          userData,
          password: trimmedPass,
        ).copyWith(
          username: trimmedUser,
          sessionId: _currentSessionId,
        );

        return AuthResponse.success(
          user: user,
          message: message,
          sessionId: _currentSessionId,
        );
      } else {
        final error = jsonResponse['error']?.toString();
        return AuthResponse.failure(
          message: message,
          error: error,
        );
      }
    } on SocketException {
      return AuthResponse.failure(
        message: 'Could not connect to server ($targetEndpoint). Please check network connection.',
        error: 'Network Error',
      );
    } on TimeoutException {
      return AuthResponse.failure(
        message: 'Connection timed out while contacting server. Please try again.',
        error: 'Timeout',
      );
    } catch (e) {
      return AuthResponse.failure(
        message: 'An unexpected error occurred: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Calls the Odoo REST Registration API endpoint:
  /// POST /api/auth/register (or /api/register)
  ///
  /// Expected payload:
  /// {
  ///   "name": "Jane Doe",
  ///   "mobile": "+1 555-0199",
  ///   "email": "jane@example.com",
  ///   "username": "janedoe",
  ///   "password": "yourpassword",
  ///   "lmp_date": "2026-07-01",
  ///   "due_date": "2027-04-07",
  ///   "db": "baby"
  /// }
  Future<AuthResponse> register({
    required String name,
    required String mobile,
    required String email,
    required String username,
    required String password,
    required DateTime lmp,
    DateTime? dueDate,
    String? db,
    String? registerUrl,
    bool isRetry = false,
  }) async {
    final trimmedName = name.trim();
    final trimmedMobile = mobile.trim();
    final trimmedEmail = email.trim();
    final trimmedUser = username.trim();
    final trimmedPass = password.trim();
    final targetDb = db ?? ApiRouts.databaseName;
    final targetEndpoint = registerUrl ?? ApiRouts.registerAPI;

    // Client-side quick validations
    if (trimmedName.isEmpty) {
      return AuthResponse.failure(message: 'Full Name is required.', error: 'Missing full_name');
    }
    if (trimmedUser.length < 3) {
      return AuthResponse.failure(message: 'Username must be at least 3 characters long.', error: 'Invalid username');
    }
    if (trimmedPass.length < 6) {
      return AuthResponse.failure(message: 'Password must be at least 6 characters long.', error: 'Weak password');
    }
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      return AuthResponse.failure(message: 'Please enter a valid email address.', error: 'Invalid email');
    }

    try {
      // 1. Ensure active session bound to target database
      String? activeSid = _currentSessionId;
      if (activeSid == null || activeSid.isEmpty) {
        activeSid = await ensureSession(db: targetDb);
      }

      // 2. Prepare headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (activeSid != null && activeSid.isNotEmpty) {
        headers['Cookie'] = 'session_id=$activeSid';
      }

      // 3. Prepare payload matching server expectations
      final lmpStr = DateFormat('yyyy-MM-dd').format(lmp);
      final dueStr = DateFormat('yyyy-MM-dd').format(
        dueDate ?? lmp.add(const Duration(days: 280)),
      );

      final body = jsonEncode({
        'name': trimmedName,
        'full_name': trimmedName,
        'mobile': trimmedMobile,
        'phone': trimmedMobile,
        'email': trimmedEmail,
        'username': trimmedUser,
        'login': trimmedUser,
        'password': trimmedPass,
        'lmp_date': lmpStr,
        'lmp': lmpStr,
        'due_date': dueStr,
        'edd': dueStr,
        'db': targetDb,
        if (activeSid != null && activeSid.isNotEmpty) 'session_id': activeSid,
      });

      final queryParams = <String, String>{
        'db': targetDb,
        if (activeSid != null && activeSid.isNotEmpty) 'session_id': activeSid,
      };

      final baseUri = Uri.parse(targetEndpoint);
      final endpoint = baseUri.replace(queryParameters: queryParams);

      final response = await _client
          .post(endpoint, headers: headers, body: body)
          .timeout(ApiRouts.timeout);

      // Handle session expiry (404) with single auto-retry
      if (response.statusCode == 404 && !isRetry) {
        clearSession();
        final refreshedSid = await ensureSession(db: targetDb);
        if (refreshedSid != null && refreshedSid.isNotEmpty) {
          return register(
            name: name,
            mobile: mobile,
            email: email,
            username: username,
            password: password,
            lmp: lmp,
            dueDate: dueDate,
            db: db,
            registerUrl: registerUrl,
            isRetry: true,
          );
        }
      }

      // Check for session update in response headers
      final responseCookie = response.headers['set-cookie'];
      if (responseCookie != null && responseCookie.isNotEmpty) {
        final newSid = _extractSessionId(responseCookie);
        if (newSid != null) {
          _currentSessionId = newSid;
        }
      }

      // 4. Parse response
      Map<String, dynamic> jsonResponse;
      try {
        jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        if (response.statusCode == 404) {
          return AuthResponse.failure(
            message: 'Server registration endpoint not found (404). Please verify server route.',
            error: 'Not Found',
          );
        }
        return AuthResponse.failure(
          message: 'Server returned an invalid response (HTTP ${response.statusCode}).',
          error: 'Invalid Response',
        );
      }

      final isSuccess = jsonResponse['success'] == true;
      final message = jsonResponse['message']?.toString() ??
          (isSuccess ? 'User registered successfully.' : 'Registration failed.');

      if (isSuccess && (response.statusCode == 200 || response.statusCode == 201)) {
        final data = jsonResponse['data'] is Map<String, dynamic>
            ? jsonResponse['data'] as Map<String, dynamic>
            : <String, dynamic>{};

        // Extract session ID
        final userData = data['user_data'] is Map<String, dynamic>
            ? data['user_data'] as Map<String, dynamic>
            : data;
        final sid = userData['session_id']?.toString() ??
            data['session_id']?.toString() ??
            _currentSessionId;

        if (sid != null && sid.isNotEmpty) {
          _currentSessionId = sid;
        }

        final user = UserModel.fromJson(
          data,
          password: trimmedPass,
        ).copyWith(
          name: trimmedName,
          mobile: trimmedMobile,
          email: trimmedEmail,
          username: trimmedUser,
          lmp: lmp,
          sessionId: _currentSessionId,
        );

        return AuthResponse.success(
          user: user,
          message: message,
          sessionId: _currentSessionId,
        );
      } else {
        final error = jsonResponse['error']?.toString();
        return AuthResponse.failure(
          message: message,
          error: error,
        );
      }
    } on SocketException {
      return AuthResponse.failure(
        message: 'Could not connect to server ($targetEndpoint). Please check network connection.',
        error: 'Network Error',
      );
    } on TimeoutException {
      return AuthResponse.failure(
        message: 'Connection timed out while contacting server. Please try again.',
        error: 'Timeout',
      );
    } catch (e) {
      return AuthResponse.failure(
        message: 'An unexpected error occurred: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  void clearSession() {
    _currentSessionId = null;
  }
}
