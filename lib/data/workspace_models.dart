// Model data ketat. Data server yang tidak valid tidak boleh dianggap sebagai pembacaan sukses.
Map<String, dynamic> jsonObject(dynamic value) {
  if (value is! Map<String, dynamic>) throw const FormatException();
  return value;
}

T jsonValue<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (!json.containsKey(key) || value is! T) throw const FormatException();
  return value;
}

Map<String, String> stringMap(dynamic value) {
  final map = jsonObject(value);
  return Map.unmodifiable(
    map.map((key, value) {
      if (value is! String) throw const FormatException();
      return MapEntry(key, value);
    }),
  );
}

DateTime parseApiDate(dynamic value) {
  if (value is! String) throw const FormatException();
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) throw const FormatException();
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year ||
      date.month != month ||
      date.day != day ||
      int.parse(match[4]!) > 23 ||
      int.parse(match[5]!) > 59 ||
      int.parse(match[6]!) > 59) {
    throw const FormatException();
  }
  if (!value.endsWith('Z')) {
    final offset = value.substring(value.length - 5).split(':');
    if (int.parse(offset[0]) > 23 || int.parse(offset[1]) > 59) {
      throw const FormatException();
    }
  }
  return DateTime.parse(value);
}

DateTime? _nullableDate(Map<String, dynamic> json, String key) {
  final value = jsonValue<Object?>(json, key);
  return value == null ? null : parseApiDate(value);
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.createdAt,
  });
  final int id;
  final String name, email, role;
  final bool isActive;
  final DateTime? createdAt;
  bool get isAdmin => role == 'admin';
  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final role = jsonValue<String>(json, 'role');
    if (role != 'user' && role != 'admin') throw const FormatException();
    return UserAccount(
      id: jsonValue<int>(json, 'id'),
      name: jsonValue<String>(json, 'name'),
      email: jsonValue<String>(json, 'email'),
      role: role,
      isActive: jsonValue<bool>(json, 'is_active'),
      createdAt: json.containsKey('created_at')
          ? _nullableDate(json, 'created_at')
          : null,
    );
  }
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.action,
    required this.label,
    required this.actorName,
    required this.subjectName,
    required this.fields,
    required this.createdAt,
  });
  final int id;
  final String action, label, actorName;
  final String? subjectName;
  final List<String> fields;
  final DateTime createdAt;
  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
    id: jsonValue<int>(json, 'id'),
    action: jsonValue<String>(json, 'action'),
    label: jsonValue<String>(json, 'label'),
    actorName: jsonValue<String>(json, 'actor_name'),
    subjectName: jsonValue<String?>(json, 'subject_name'),
    fields: List.unmodifiable(
      jsonValue<List>(json, 'fields').map((value) {
        if (value is! String) throw const FormatException();
        return value;
      }),
    ),
    createdAt: parseApiDate(json['created_at']),
  );
}

class DeviceSession {
  const DeviceSession({
    required this.kind,
    required this.label,
    required this.device,
    required this.ip,
    required this.current,
    required this.lastActive,
    required this.expiresAt,
  });
  final String kind, label, device;
  final String? ip;
  final bool current;
  final DateTime? lastActive, expiresAt;
  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    final kind = jsonValue<String>(json, 'kind');
    if (kind != 'web' && kind != 'mobile') throw const FormatException();
    return DeviceSession(
      kind: kind,
      label: jsonValue<String>(json, 'label'),
      device: jsonValue<String>(json, 'device'),
      ip: jsonValue<String?>(json, 'ip'),
      current: jsonValue<bool>(json, 'current'),
      lastActive: _nullableDate(json, 'last_active'),
      expiresAt: _nullableDate(json, 'expires_at'),
    );
  }
}

class ApiPage<T> {
  const ApiPage({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.actions = const {},
    this.webSupported = false,
  });
  final List<T> data;
  final int currentPage, lastPage, total;
  final Map<String, String> actions;
  final bool webSupported;
  bool get hasNext => currentPage < lastPage;
  bool get hasPrevious => currentPage > 1;
  factory ApiPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = jsonObject(json['meta']);
    final current = jsonValue<int>(meta, 'current_page');
    final last = jsonValue<int>(meta, 'last_page');
    final total = jsonValue<int>(meta, 'total');
    final perPage = jsonValue<int>(meta, 'per_page');
    if (current < 1 || last < 1 || total < 0 || perPage < 1) {
      throw const FormatException();
    }
    return ApiPage(
      data: List.unmodifiable(
        jsonValue<List>(json, 'data').map((v) => parse(jsonObject(v))),
      ),
      currentPage: current,
      lastPage: last,
      total: total,
      actions: json.containsKey('actions')
          ? stringMap(json['actions'])
          : const {},
      webSupported: json.containsKey('web_supported')
          ? jsonValue<bool>(json, 'web_supported')
          : false,
    );
  }
}

class WorkspaceData {
  const WorkspaceData({
    required this.settings,
    required this.counts,
    required this.recentActivities,
    required this.telemetryAvailable,
  });
  final Map<String, String> settings;
  final Map<String, int>? counts;
  final List<ActivityEntry> recentActivities;
  final bool telemetryAvailable;
  factory WorkspaceData.fromJson(Map<String, dynamic> json) {
    final counts = jsonValue<Object?>(json, 'counts');
    return WorkspaceData(
      settings: stringMap(json['settings']),
      counts: counts == null
          ? null
          : Map.unmodifiable(
              jsonObject(counts).map((key, value) {
                if (value is! int || value < 0) throw const FormatException();
                return MapEntry(key, value);
              }),
            ),
      recentActivities: List.unmodifiable(
        jsonValue<List>(
          json,
          'recent_activities',
        ).map((v) => ActivityEntry.fromJson(jsonObject(v))),
      ),
      telemetryAvailable: jsonValue<bool>(json, 'telemetry_available'),
    );
  }
}
