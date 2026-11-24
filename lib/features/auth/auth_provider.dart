import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/auth_api_service.dart';
import '../../models/user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final String username;
  final UserModel? currentUser;
  final bool isLoading;
  final String? errorMessage;
  final List<UserModel> registeredUsers;
  final String serverIp;
  final String database;

  const AuthState({
    required this.isAuthenticated,
    this.username = '',
    this.currentUser,
    this.isLoading = false,
    this.errorMessage,
    this.registeredUsers = const [],
    this.serverIp = '168.144.73.80',
    this.database = 'baby',
  });

  factory AuthState.initial() {
    final defaultUser = UserModel(
      name: 'Mama Priya',
      mobile: '9876543210',
      email: 'mama@example.com',
      username: 'Mama',
      password: '123456',
      lmp: DateTime.now().subtract(const Duration(days: 140)), // ~20 weeks
    );

    return AuthState(
      isAuthenticated: false,
      username: '',
      currentUser: null,
      isLoading: false,
      registeredUsers: [defaultUser],
      serverIp: ApiRouts.serverIp,
      database: ApiRouts.databaseName,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    String? username,
    UserModel? currentUser,
    bool? isLoading,
    String? errorMessage,
    List<UserModel>? registeredUsers,
    String? serverIp,
    String? database,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      registeredUsers: registeredUsers ?? this.registeredUsers,
      serverIp: serverIp ?? this.serverIp,
      database: database ?? this.database,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApiService _apiService;

  AuthNotifier({AuthApiService? apiService})
      : _apiService = apiService ?? AuthApiService(),
        super(AuthState.initial());

  Future<bool> register({
    required String name,
    required String mobile,
    required String email,
    required String username,
    required String password,
    required DateTime lmp,
    DateTime? dueDate,
  }) async {
    final trimmedName = name.trim();
    final trimmedMobile = mobile.trim();
    final trimmedEmail = email.trim();
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();

    state = state.copyWith(isLoading: true, errorMessage: null);

    // Call remote Odoo registration API
    final response = await _apiService.register(
      name: trimmedName,
      mobile: trimmedMobile,
      email: trimmedEmail,
      username: trimmedUsername,
      password: trimmedPassword,
      lmp: lmp,
      dueDate: dueDate,
      db: state.database,
    );

    if (response.success && response.user != null) {
      final updatedList = List<UserModel>.from(state.registeredUsers)..add(response.user!);

      state = state.copyWith(
        isAuthenticated: true,
        username: response.user!.name.isNotEmpty ? response.user!.name : response.user!.username,
        currentUser: response.user,
        isLoading: false,
        registeredUsers: updatedList,
        errorMessage: null,
      );
      return true;
    }

    // If server was offline or unreachable, save locally as fallback
    if (response.error == 'Network Error' || response.error == 'Timeout') {
      final newUser = UserModel(
        name: trimmedName,
        mobile: trimmedMobile,
        email: trimmedEmail,
        username: trimmedUsername,
        password: trimmedPassword,
        lmp: lmp,
        edd: dueDate,
      );

      final updatedList = List<UserModel>.from(state.registeredUsers)..add(newUser);

      state = state.copyWith(
        isAuthenticated: true,
        username: trimmedName.isNotEmpty ? trimmedName : trimmedUsername,
        currentUser: newUser,
        isLoading: false,
        registeredUsers: updatedList,
        errorMessage: null,
      );
      return true;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: response.message,
    );
    return false;
  }

  /// Authenticates using the remote Odoo backend login API:
  /// POST http://168.144.73.80:8080/api/auth/login
  /// with payload: {"username": ..., "password": ..., "db": "baby"}
  Future<bool> login(
    String usernameOrEmail,
    String password, {
    String? database,
  }) async {
    final query = usernameOrEmail.trim();
    final trimmedPass = password.trim();
    final targetDb = database ?? state.database;

    if (query.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your username or email');
      return false;
    }

    if (trimmedPass.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your password');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    // Call the server REST Login API
    final response = await _apiService.login(
      username: query,
      password: trimmedPass,
      db: targetDb,
    );

    if (response.success && response.user != null) {
      state = state.copyWith(
        isAuthenticated: true,
        username: response.user!.name.isNotEmpty ? response.user!.name : response.user!.username,
        currentUser: response.user,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    }

    // If server authentication failed, check registered local users as offline fallback
    final localMatch = state.registeredUsers.cast<UserModel?>().firstWhere(
          (u) =>
              u != null &&
              (u.username.toLowerCase() == query.toLowerCase() ||
                  u.email.toLowerCase() == query.toLowerCase()),
          orElse: () => null,
        );

    if (localMatch != null && localMatch.password == trimmedPass) {
      state = state.copyWith(
        isAuthenticated: true,
        username: localMatch.name.isNotEmpty ? localMatch.name : localMatch.username,
        currentUser: localMatch,
        isLoading: false,
        errorMessage: null,
      );
      return true;
    }

    // Set server error message
    state = state.copyWith(
      isLoading: false,
      errorMessage: response.message,
    );
    return false;
  }

  void logout() {
    _apiService.clearSession();
    state = state.copyWith(
      isAuthenticated: false,
      username: '',
      currentUser: null,
      errorMessage: null,
    );
  }
}

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(authApiServiceProvider);
  return AuthNotifier(apiService: apiService);
});
