import 'package:intl/intl.dart';

class BumpEntry {
  final int? id;
  final String? name;
  final String date; // YYYY-MM-DD
  final String? day; // Monday, Tuesday, etc.
  final String time; // HH:mm (24-hour)
  final String location; // One of 15 locations or server location name
  final int? locationId;
  final int count; // manual bump count
  final String? observation;
  final String? note; // optional personal note
  final int? profileId;
  final String? profileName;
  final int? userId;
  final String? userName;
  final String createdAt; // ISO string

  BumpEntry({
    this.id,
    this.name,
    required this.date,
    this.day,
    required this.time,
    required this.location,
    this.locationId,
    required this.count,
    this.observation,
    this.note,
    this.profileId,
    this.profileName,
    this.userId,
    this.userName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'time': time,
      'location': location,
      'bump_count': count,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory BumpEntry.fromMap(Map<String, dynamic> map) {
    final rawCount = map['bump_count'] ?? map['count'] ?? 1;
    final int countVal =
        rawCount is int ? rawCount : int.tryParse(rawCount.toString()) ?? 1;

    String locName = 'Center / Navel Area';
    int? locId;
    if (map['bump_location'] is Map) {
      final bLoc = map['bump_location'] as Map;
      locId = bLoc['id'] is int ? bLoc['id'] as int : null;
      final n = bLoc['name']?.toString() ?? '';
      if (n.isNotEmpty) locName = n;
    } else if (map['location'] != null && map['location'].toString().isNotEmpty) {
      locName = map['location'].toString();
    } else if (map['location_name'] != null &&
        map['location_name'].toString().isNotEmpty) {
      locName = map['location_name'].toString();
    }

    final rawId = map['id'];
    final int? parsedId =
        rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);

    return BumpEntry(
      id: parsedId,
      name: map['name']?.toString(),
      date: map['date']?.toString() ?? DateTime.now().toIso8601String().substring(0, 10),
      day: map['day']?.toString(),
      time: map['time']?.toString() ?? '12:00',
      location: locName,
      locationId: locId,
      count: countVal,
      observation: map['observation']?.toString(),
      note: map['note']?.toString(),
      profileId: map['profile_id'] is int ? map['profile_id'] as int : null,
      profileName: map['profile_name']?.toString(),
      userId: map['user_id'] is int ? map['user_id'] as int : null,
      userName: map['user_name']?.toString(),
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toApiPayload({int? uid, String? db}) {
    String dayVal = day ?? '';
    if (dayVal.isEmpty) {
      try {
        final parsed = DateTime.parse(date);
        dayVal = DateFormat('EEEE').format(parsed);
      } catch (_) {
        dayVal = '';
      }
    }

    return {
      'date': date,
      if (dayVal.isNotEmpty) 'day': dayVal,
      'time': time,
      'bump_count': count,
      'bump_location': location,
      'location': location,
      if (locationId != null) 'location_id': locationId,
      if (note != null && note!.isNotEmpty) 'note': note,
      if (note != null && note!.isNotEmpty) 'notes': note,
      if (observation != null && observation!.isNotEmpty) 'observation': observation,
      if (profileId != null) 'profile_id': profileId,
      if (name != null && name!.isNotEmpty) 'name': name,
      if (uid != null) 'uid': uid,
      if (uid != null) 'user_id': uid,
      if (db != null) 'db': db,
    };
  }

  BumpEntry copyWith({
    int? id,
    String? name,
    String? date,
    String? day,
    String? time,
    String? location,
    int? locationId,
    int? count,
    String? observation,
    String? note,
    int? profileId,
    String? profileName,
    int? userId,
    String? userName,
    String? createdAt,
  }) {
    return BumpEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      day: day ?? this.day,
      time: time ?? this.time,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      count: count ?? this.count,
      observation: observation ?? this.observation,
      note: note ?? this.note,
      profileId: profileId ?? this.profileId,
      profileName: profileName ?? this.profileName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class UserLogCounts {
  final int userId;
  final String userName;
  final int todayLogsCount;
  final int totalLogsCount;
  final int todayBumpsCount;
  final int totalBumpsCount;
  final String? selectedDate;
  final String? selectedDay;

  const UserLogCounts({
    required this.userId,
    required this.userName,
    required this.todayLogsCount,
    required this.totalLogsCount,
    required this.todayBumpsCount,
    required this.totalBumpsCount,
    this.selectedDate,
    this.selectedDay,
  });

  factory UserLogCounts.fromJson(Map<String, dynamic> json) {
    return UserLogCounts(
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      userName: json['user_name']?.toString() ?? '',
      todayLogsCount: json['today_logs_count'] is int
          ? json['today_logs_count'] as int
          : int.tryParse(json['today_logs_count']?.toString() ?? '0') ?? 0,
      totalLogsCount: json['total_logs_count'] is int
          ? json['total_logs_count'] as int
          : int.tryParse(json['total_logs_count']?.toString() ?? '0') ?? 0,
      todayBumpsCount: json['today_bumps_count'] is int
          ? json['today_bumps_count'] as int
          : int.tryParse(json['today_bumps_count']?.toString() ?? '0') ?? 0,
      totalBumpsCount: json['total_bumps_count'] is int
          ? json['total_bumps_count'] as int
          : int.tryParse(json['total_bumps_count']?.toString() ?? '0') ?? 0,
      selectedDate: json['selected_date']?.toString(),
      selectedDay: json['selected_day']?.toString(),
    );
  }
}

class BumpLogsResponse {
  final bool success;
  final String? message;
  final String? error;
  final List<BumpEntry> data;
  final int page;
  final int limit;
  final int totalRecords;
  final int totalPages;
  final UserLogCounts? userLogCounts;

  const BumpLogsResponse({
    required this.success,
    this.message,
    this.error,
    this.data = const [],
    this.page = 1,
    this.limit = 20,
    this.totalRecords = 0,
    this.totalPages = 0,
    this.userLogCounts,
  });

  factory BumpLogsResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    final dataList = json['data'] is List ? json['data'] as List : [];
    final entries = dataList
        .whereType<Map<String, dynamic>>()
        .map((item) => BumpEntry.fromMap(item))
        .toList();

    final pagination = json['pagination'] is Map ? json['pagination'] as Map : {};
    final counts = json['user_log_counts'] is Map
        ? UserLogCounts.fromJson(Map<String, dynamic>.from(json['user_log_counts']))
        : null;

    return BumpLogsResponse(
      success: success,
      message: json['message']?.toString(),
      error: json['error']?.toString(),
      data: entries,
      page: pagination['page'] is int ? pagination['page'] as int : 1,
      limit: pagination['limit'] is int ? pagination['limit'] as int : 20,
      totalRecords: pagination['total_records'] is int
          ? pagination['total_records'] as int
          : entries.length,
      totalPages: pagination['total_pages'] is int
          ? pagination['total_pages'] as int
          : (entries.isNotEmpty ? 1 : 0),
      userLogCounts: counts,
    );
  }

  factory BumpLogsResponse.failure({required String message, String? error}) {
    return BumpLogsResponse(
      success: false,
      message: message,
      error: error,
      data: const [],
    );
  }
}

class CreateBumpResponse {
  final bool success;
  final String message;
  final String? error;
  final BumpEntry? entry;
  final UserLogCounts? userLogCounts;

  const CreateBumpResponse({
    required this.success,
    required this.message,
    this.error,
    this.entry,
    this.userLogCounts,
  });

  factory CreateBumpResponse.success({
    required BumpEntry entry,
    String message = 'Baby bump logged successfully.',
    UserLogCounts? userLogCounts,
  }) {
    return CreateBumpResponse(
      success: true,
      message: message,
      entry: entry,
      userLogCounts: userLogCounts,
    );
  }

  factory CreateBumpResponse.failure({
    required String message,
    String? error,
    BumpEntry? entry,
  }) {
    return CreateBumpResponse(
      success: false,
      message: message,
      error: error,
      entry: entry,
    );
  }
}
