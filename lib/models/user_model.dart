import 'package:intl/intl.dart';

class UserModel {
  final int? uid;
  final String name;
  final String mobile;
  final String email;
  final String username;
  final String password;
  final DateTime lmp; // Last Menstrual Period
  final DateTime? edd; // Expected Due Date
  final String? sessionId;
  final int? partnerId;

  const UserModel({
    this.uid,
    required this.name,
    required this.mobile,
    required this.email,
    required this.username,
    required this.password,
    required this.lmp,
    this.edd,
    this.sessionId,
    this.partnerId,
  });

  /// Total days since LMP
  int get daysSinceLmp {
    final diff = DateTime.now().difference(lmp).inDays;
    return diff >= 0 ? diff : 0;
  }

  /// Gestational age in completed weeks
  int get gestationalWeeks => daysSinceLmp ~/ 7;

  /// Remaining days in current gestational week
  int get gestationalDays => daysSinceLmp % 7;

  /// Formatted gestational age: e.g. "24 weeks, 3 days"
  String get gestationalAgeString => '$gestationalWeeks weeks, $gestationalDays days';

  /// Estimated Due Date (EDD) = LMP + 280 days (40 weeks)
  DateTime get estimatedDueDate => edd ?? lmp.add(const Duration(days: 280));

  /// Formatted LMP date string: e.g. "Oct 12, 2024"
  String get formattedLmp => DateFormat.yMMMd().format(lmp);

  /// Formatted EDD date string: e.g. "Jul 19, 2025"
  String get formattedEdd => DateFormat.yMMMd().format(estimatedDueDate);

  factory UserModel.fromJson(Map<String, dynamic> json, {String? password}) {
    // Check if nested in user_data or user
    final Map<String, dynamic> userData = json['user_data'] is Map<String, dynamic>
        ? json['user_data'] as Map<String, dynamic>
        : (json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : json);

    final Map<String, dynamic>? profileData = json['pregnancy_profile'] is Map<String, dynamic>
        ? json['pregnancy_profile'] as Map<String, dynamic>
        : (userData['pregnancy_profile'] is Map<String, dynamic>
            ? userData['pregnancy_profile'] as Map<String, dynamic>
            : null);

    final rawLmp = profileData?['lmp_date'] ?? json['lmp_date'] ?? json['lmp'] ?? userData['lmp_date'] ?? userData['lmp'];
    DateTime parsedLmp;
    if (rawLmp is String && rawLmp.isNotEmpty) {
      parsedLmp = DateTime.tryParse(rawLmp) ?? DateTime.now().subtract(const Duration(days: 140));
    } else {
      parsedLmp = DateTime.now().subtract(const Duration(days: 140));
    }

    final rawDue = profileData?['due_date'] ?? json['due_date'] ?? json['edd'] ?? userData['due_date'];
    DateTime? parsedDue;
    if (rawDue is String && rawDue.isNotEmpty) {
      parsedDue = DateTime.tryParse(rawDue);
    }

    final rawUid = userData['uid'] ?? userData['id'] ?? json['uid'] ?? json['id'] ?? json['user_id'];
    int? parsedUid;
    if (rawUid is int) {
      parsedUid = rawUid;
    } else if (rawUid != null) {
      parsedUid = int.tryParse(rawUid.toString());
    }

    final rawPartnerId = userData['partner_id'] ?? json['partner_id'];
    int? parsedPartnerId;
    if (rawPartnerId is int) {
      parsedPartnerId = rawPartnerId;
    } else if (rawPartnerId is List && rawPartnerId.isNotEmpty && rawPartnerId.first is int) {
      parsedPartnerId = rawPartnerId.first as int;
    }

    final name = userData['name']?.toString() ??
        json['name']?.toString() ??
        userData['partner_name']?.toString() ??
        userData['username']?.toString() ??
        userData['login']?.toString() ??
        'Mama';

    final username = userData['username']?.toString() ??
        userData['login']?.toString() ??
        json['username']?.toString() ??
        json['login']?.toString() ??
        (name.isNotEmpty ? name : 'Mama');

    final sid = userData['session_id']?.toString() ??
        json['session_id']?.toString();

    return UserModel(
      uid: parsedUid,
      name: name,
      mobile: userData['mobile']?.toString() ?? userData['phone']?.toString() ?? json['mobile']?.toString() ?? json['phone']?.toString() ?? '',
      email: userData['email']?.toString() ?? json['email']?.toString() ?? '',
      username: username,
      password: password ?? userData['password']?.toString() ?? json['password']?.toString() ?? '',
      lmp: parsedLmp,
      edd: parsedDue,
      sessionId: sid,
      partnerId: parsedPartnerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'mobile': mobile,
      'email': email,
      'username': username,
      'password': password,
      'lmp': lmp.toIso8601String(),
      'due_date': estimatedDueDate.toIso8601String(),
      'session_id': sessionId,
      'partner_id': partnerId,
    };
  }

  UserModel copyWith({
    int? uid,
    String? name,
    String? mobile,
    String? email,
    String? username,
    String? password,
    DateTime? lmp,
    DateTime? edd,
    String? sessionId,
    int? partnerId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      lmp: lmp ?? this.lmp,
      edd: edd ?? this.edd,
      sessionId: sessionId ?? this.sessionId,
      partnerId: partnerId ?? this.partnerId,
    );
  }
}
