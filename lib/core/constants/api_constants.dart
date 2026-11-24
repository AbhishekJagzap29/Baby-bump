class ApiRouts {
  /// BASE URL & LIVE DATABASE
  static String databaseName = 'baby';
  static String base = 'http://168.144.73.80:8080/';

  /// AUTH APIS
  static String loginAPI = '${base}api/auth/login';
  static String registerAPI = '${base}api/auth/register';

  /// ODOO SESSION
  static String webLogin = '${base}web/login';

  /// BABY BUMP COUNTER APIS
  static String getBumpLogs = '${base}api/bump/logs';
  static String createBumpLog = '${base}api/bump/create';

  /// NETWORK TIMEOUT
  static const Duration timeout = Duration(seconds: 15);

  /// Backwards-compatibility aliases
  static String get serverIp => '168.144.73.80';
  static String get defaultDb => databaseName;
}
