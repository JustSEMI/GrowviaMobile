import 'package:flutter_test/flutter_test.dart';
import 'package:growvia_mobile/data/workspace_models.dart';

Map<String, dynamic> userJson() => {
  'id': 7,
  'name': 'A',
  'email': 'a@example.test',
  'role': 'admin',
  'is_active': true,
};
Map<String, dynamic> activityJson() => {
  'id': 1,
  'action': 'updated',
  'label': 'Updated',
  'actor_name': 'A',
  'subject_name': null,
  'fields': ['Name'],
  'created_at': '2026-09-17T00:00:00Z',
};
void main() {
  test('account role, active state and optional creation date are strict', () {
    final user = UserAccount.fromJson(userJson());
    expect(user.isAdmin, isTrue);
    expect(user.isActive, isTrue);
    expect(user.createdAt, isNull);
    expect(
      UserAccount.fromJson({...userJson(), 'role': 'user', 'is_active': false})
          .isAdmin,
      isFalse,
    );
    expect(
      UserAccount.fromJson({
        ...userJson(),
        'created_at': '2026-09-17T00:00:00Z',
      }).createdAt!.isUtc,
      isTrue,
    );
    for (final bad in [
      {'role': 'owner'},
      {'role': null},
      {'is_active': 1},
      {'id': '7'},
      {'created_at': 'bad'},
    ]) {
      expect(
        () => UserAccount.fromJson({...userJson(), ...bad}),
        throwsFormatException,
      );
    }
  });
  test('activity and session strictly parse nullable fields', () {
    expect(ActivityEntry.fromJson(activityJson()).fields, ['Name']);
    expect(
      () => ActivityEntry.fromJson({
        ...activityJson(),
        'fields': [1],
      }),
      throwsFormatException,
    );
    expect(
      () => ActivityEntry.fromJson({
        ...activityJson(),
        'created_at': '2026-02-30T00:00:00Z',
      }),
      throwsFormatException,
    );
    expect(
      () => ActivityEntry.fromJson({
        ...activityJson(),
        'created_at': '2026-09-17T00:00:00+25:80',
      }),
      throwsFormatException,
    );
    final json = <String, dynamic>{
      'kind': 'mobile',
      'label': 'Phone',
      'device': 'Android',
      'ip': null,
      'current': true,
      'last_active': null,
      'expires_at': null,
    };
    expect(DeviceSession.fromJson(json).current, isTrue);
    expect(
      () => DeviceSession.fromJson({...json, 'kind': 'other'}),
      throwsFormatException,
    );
    expect(
      () => DeviceSession.fromJson({...json, 'current': 'true'}),
      throwsFormatException,
    );
  });
  test('page uses exact public pagination and optional extension metadata', () {
    final json = <String, dynamic>{
      'data': [userJson()],
      'meta': {'current_page': 2, 'last_page': 3, 'per_page': 15, 'total': 32},
      'actions': {'updated': 'Updated'},
      'web_supported': true,
    };
    final page = ApiPage<UserAccount>.fromJson(json, UserAccount.fromJson);
    expect(page.data.single.id, 7);
    expect(page.currentPage, 2);
    expect(page.lastPage, 3);
    expect(page.total, 32);
    expect(page.hasNext, isTrue);
    expect(page.hasPrevious, isTrue);
    expect(page.actions, {'updated': 'Updated'});
    expect(page.webSupported, isTrue);
    expect(
      () => ApiPage<UserAccount>.fromJson({
        ...json,
        'meta': {},
      }, UserAccount.fromJson),
      throwsFormatException,
    );
    expect(
      () => ApiPage<UserAccount>.fromJson({
        ...json,
        'actions': {'x': 3},
      }, UserAccount.fromJson),
      throwsFormatException,
    );
  });
  test('workspace validates settings, counts and unavailable telemetry', () {
    final json = <String, dynamic>{
      'settings': {'pump_mode': 'auto'},
      'counts': {'users_total': 2},
      'recent_activities': [activityJson()],
      'telemetry_available': false,
    };
    final workspace = WorkspaceData.fromJson(json);
    expect(workspace.settings['pump_mode'], 'auto');
    expect(workspace.counts!['users_total'], 2);
    expect(workspace.recentActivities.single.actorName, 'A');
    expect(workspace.telemetryAvailable, isFalse);
    expect(WorkspaceData.fromJson({...json, 'counts': null}).counts, isNull);
    for (final bad in [
      {
        'settings': {'x': 1},
      },
      {
        'counts': {'x': '2'},
      },
      {'recent_activities': null},
      {'telemetry_available': 'false'},
    ]) {
      expect(
        () => WorkspaceData.fromJson({...json, ...bad}),
        throwsFormatException,
      );
    }
  });
}
