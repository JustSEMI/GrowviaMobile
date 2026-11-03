import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:growvia_mobile/core/app_controller.dart';
import 'package:growvia_mobile/core/theme.dart';
import 'package:growvia_mobile/features/users_page.dart';
import 'package:growvia_mobile/features/activity_page.dart';
import 'package:growvia_mobile/features/account_page.dart';
import 'package:growvia_mobile/features/sessions_page.dart';
import 'package:growvia_mobile/features/system_settings_page.dart';
import 'package:growvia_mobile/features/recovery_page.dart';

const settings = <String, String>{
  'update_interval': '10',
  'th_suhu_min': '25',
  'th_suhu_max': '30',
  'th_hum_min': '60',
  'th_hum_max': '80',
  'th_light_min': '20',
  'th_co2_min': '800',
  'th_co2_max': '1200',
  'soil_on': '30',
  'soil_off': '60',
  'tank_min': '20',
  'pump_max_run': '15',
  'pump_mode': 'auto',
  'notif_pompa': '1',
  'notif_cahaya': '1',
  'notif_tandon': '1',
  'notif_offline': '1',
};
Map<String, dynamic> user(
  int id, {
  String role = 'user',
  String? name,
  String? email,
}) => {
  'id': id,
  'name': name ?? (id == 1 ? 'Admin Test' : 'Member Test'),
  'email': email ?? (id == 1 ? 'admin@example.test' : 'member@example.test'),
  'role': role,
  'is_active': true,
  'created_at': '2026-09-01T10:00:00Z',
};
http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
Map<String, dynamic> page(
  List<Object> data, {
  int current = 1,
  int last = 1,
  int? total,
}) => {
  'data': data,
  'meta': {
    'current_page': current,
    'last_page': last,
    'per_page': 15,
    'total': total ?? data.length,
  },
};

class Harness {
  Harness({this.role = 'admin', this.handler}) {
    app = AppController(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/login')) {
          return jsonResponse({
            'token': 'test-token',
            'user': user(1, role: role),
          });
        }
        if (request.url.path.endsWith('/readings')) {
          return jsonResponse({'data': []});
        }
        if (request.url.path.endsWith('/auth/logout')) {
          return http.Response('', 204);
        }
        final custom = await handler?.call(request);
        if (custom != null) return custom;
        if (request.url.path.endsWith('/users')) {
          return jsonResponse(page([user(1, role: role), user(2)]));
        }
        if (request.url.path.endsWith('/activities')) {
          return jsonResponse({
            ...page([]),
            'actions': {'user.created': 'Pengguna ditambahkan'},
            'timezone': 'UTC',
          });
        }
        if (request.url.path.endsWith('/settings')) {
          return jsonResponse({'settings': settings});
        }
        if (request.url.path.endsWith('/account/sessions')) {
          return jsonResponse({
            ...page([
              {
                'kind': 'mobile',
                'label': 'Ponsel uji',
                'device': 'Growvia Mobile',
                'ip': null,
                'current': true,
                'last_active': '2026-09-17T08:30:00+07:00',
                'expires_at': null,
              },
            ]),
            'web_supported': true,
          });
        }
        return jsonResponse({'message': 'Unexpected test request'}, 500);
      }),
    );
  }
  final String role;
  final FutureOr<http.Response?> Function(http.Request)? handler;
  final requests = <http.Request>[];
  late final AppController app;
  Future<void> start({bool login = true}) async {
    await app.initialize();
    if (login) await app.login('admin@example.test', 'test-password');
    requests.clear();
  }
}

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? GrowviaTheme.dark() : GrowviaTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('management-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: scrollable,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(Key(key));
  await reveal(tester, finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, String key, String option) async {
  await tap(tester, key);
  final target = find.byKey(Key('$key-option-$option'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDownAll(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'growvia.api_url': 'https://growvia.example/api/v1',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('protected users page refuses unauthenticated access', (
    tester,
  ) async {
    final h = Harness();
    await h.start(login: false);
    await mount(tester, UsersPage(controller: h.app));
    expect(find.text('Masuk diperlukan'), findsOneWidget);
    expect(h.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
    h.app.dispose();
  });

  testWidgets(
    'member denied all administrator pages and preview makes no requests',
    (tester) async {
      final h = Harness(role: 'user');
      await h.start();
      for (final widget in [
        UsersPage(controller: h.app),
        ActivityPage(controller: h.app),
        SystemSettingsPage(controller: h.app),
      ]) {
        await mount(tester, widget);
        expect(find.text('Akses administrator diperlukan'), findsOneWidget);
      }
      expect(h.requests, isEmpty);
      await h.app.logout();
      h.app.enterPreview();
      h.requests.clear();
      for (final widget in [
        UsersPage(controller: h.app),
        ActivityPage(controller: h.app),
        SystemSettingsPage(controller: h.app),
        AccountPage(controller: h.app),
        SessionsPage(controller: h.app),
        RecoveryPage(controller: h.app),
      ]) {
        await mount(tester, widget);
        expect(find.text('Mode pratinjau'), findsOneWidget);
      }
      expect(h.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets(
    'user creation exposes field errors then only receipts a successful write',
    (tester) async {
      var writes = 0;
      final h = Harness(
        handler: (r) {
          if (r.method == 'POST' && r.url.path.endsWith('/users')) {
            writes++;
            final body = jsonDecode(r.body) as Map;
            expect(body['name'], 'New Member');
            expect(body['role'], 'user');
            if (writes == 1) {
              return jsonResponse({
                'message': 'Periksa data.',
                'errors': {
                  'email': ['Email sudah digunakan.'],
                  'name': ['Nama perlu diperiksa.'],
                },
              }, 422);
            }
            return jsonResponse({
              'user': user(3, name: 'New Member'),
              'message': 'Created',
            }, 201);
          }
          return null;
        },
      );
      await h.start();
      await mount(tester, UsersPage(controller: h.app));
      await tap(tester, 'user-add');
      await enter(tester, 'user-name', 'New Member');
      await enter(tester, 'user-email', 'new@example.test');
      await enter(tester, 'user-password', 'new-password');
      await tap(tester, 'user-save');
      await reveal(tester, find.byKey(const Key('management-errors')));
      expect(find.textContaining('Email sudah digunakan.'), findsWidgets);
      expect(find.textContaining('Nama perlu diperiksa.'), findsWidgets);
      expect(find.byKey(const Key('management-receipt')), findsNothing);
      await tap(tester, 'user-save');
      await reveal(tester, find.byKey(const Key('management-receipt')));
      expect(find.text('Pengguna baru berhasil ditambahkan.'), findsOneWidget);
      expect(writes, 2);
      await tap(tester, 'user-add');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('user-password')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets(
    'self protections and sensitive edit require actor password; status and delete confirmed',
    (tester) async {
      final h = Harness(
        handler: (r) {
          if (r.method == 'PATCH' && r.url.path.endsWith('/users/2')) {
            return jsonResponse({
              'user': user(2, email: 'changed@example.test'),
              'message': 'Saved',
            });
          }
          if (r.url.path.endsWith('/users/2/status')) {
            return jsonResponse({
              'user': {...user(2), 'is_active': false},
              'message': 'Saved',
            });
          }
          if (r.method == 'DELETE') return http.Response('', 204);
          return null;
        },
      );
      await h.start();
      await mount(tester, UsersPage(controller: h.app));
      await reveal(tester, find.byKey(const Key('user-edit-1')));
      expect(find.byKey(const Key('user-delete-1')), findsNothing);
      expect(find.byKey(const Key('user-status-1')), findsNothing);
      await tap(tester, 'user-edit-1');
      await reveal(tester, find.byKey(const Key('user-name')));
      expect(find.byKey(const Key('user-role')), findsNothing);
      await reveal(tester, find.text('Batal').first);
      await tester.tap(find.text('Batal').first);
      await tester.pumpAndSettle();
      await tap(tester, 'user-edit-2');
      await enter(tester, 'user-email', 'changed@example.test');
      await tap(tester, 'user-save');
      expect(h.requests.where((r) => r.method == 'PATCH'), isEmpty);
      await enter(tester, 'user-admin-password', 'actor-password');
      await tap(tester, 'user-save');
      final edit = h.requests.singleWhere(
        (r) => r.url.path.endsWith('/users/2') && r.method == 'PATCH',
      );
      expect(jsonDecode(edit.body)['admin_password'], 'actor-password');
      await tap(tester, 'user-status-2');
      expect(h.requests.where((r) => r.url.path.endsWith('/status')), isEmpty);
      await tester.tap(find.byKey(const Key('management-confirm')));
      await tester.pumpAndSettle();
      expect(
        jsonDecode(
          h.requests.singleWhere((r) => r.url.path.endsWith('/status')).body,
        )['is_active'],
        false,
      );
      await tap(tester, 'user-delete-2');
      await tester.tap(find.byKey(const Key('management-confirm')));
      await tester.pumpAndSettle();
      expect(h.requests.where((r) => r.method == 'DELETE').length, 1);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets('users filters and pagination are explicit, not per build', (
    tester,
  ) async {
    final h = Harness(
      handler: (r) => r.url.path.endsWith('/users')
          ? jsonResponse(
              page(
                [user(2)],
                current: int.parse(r.url.queryParameters['page'] ?? '1'),
                last: 2,
                total: 16,
              ),
            )
          : null,
    );
    await h.start();
    await mount(tester, UsersPage(controller: h.app));
    expect(h.requests.length, 1);
    await enter(tester, 'users-q', 'Member');
    await choose(tester, 'users-role', 'user');
    await choose(tester, 'users-status', 'active');
    await choose(tester, 'users-sort', 'name_asc');
    expect(h.requests.length, 1);
    await tap(tester, 'users-apply');
    expect(h.requests.last.url.queryParameters, containsPair('q', 'Member'));
    expect(h.requests.last.url.queryParameters, containsPair('role', 'user'));
    expect(
      h.requests.last.url.queryParameters,
      containsPair('status', 'active'),
    );
    expect(
      h.requests.last.url.queryParameters,
      containsPair('sort', 'name_asc'),
    );
    await tap(tester, 'page-next');
    expect(h.requests.last.url.queryParameters['page'], '2');
    await tester.pumpWidget(const SizedBox());
    h.app.dispose();
  });

  testWidgets('activity filters validate dates, use UTC and show safe labels', (
    tester,
  ) async {
    final h = Harness(
      handler: (r) => r.url.path.endsWith('/activities')
          ? jsonResponse({
              ...page([
                {
                  'id': 8,
                  'action': 'user.created',
                  'label': 'Pengguna ditambahkan',
                  'actor_name': 'Admin Test',
                  'subject_name': 'Member Test',
                  'fields': ['Nama', 'Email'],
                  'created_at': '2026-09-17T08:30:00+07:00',
                },
              ]),
              'actions': {'user.created': 'Pengguna ditambahkan'},
              'timezone': 'UTC',
            })
          : null,
    );
    await h.start();
    await mount(tester, ActivityPage(controller: h.app));
    await enter(tester, 'activity-from', '2026-02-30');
    await tap(tester, 'activity-apply');
    expect(h.requests.length, 1);
    await enter(tester, 'activity-from', '2026-09-01');
    await enter(tester, 'activity-to', '2026-09-30');
    await enter(tester, 'activity-q', 'Member');
    await choose(tester, 'activity-action', 'user.created');
    await tap(tester, 'activity-apply');
    expect(h.requests.last.url.queryParameters['from'], '2026-09-01');
    expect(h.requests.last.url.queryParameters['action'], 'user.created');
    await reveal(tester, find.text('2026-09-17 01:30 UTC'));
    expect(find.text('Kolom: Nama, Email'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    h.app.dispose();
  });

  testWidgets(
    'account verifies email change, adopts rotated token, clears credentials, stays on page',
    (tester) async {
      final h = Harness(
        handler: (r) {
          if (r.url.path.endsWith('/account/profile')) {
            final body = jsonDecode(r.body) as Map;
            return jsonResponse({
              'user': user(
                1,
                role: 'admin',
                name: body['name'],
                email: body['email'],
              ),
              'token': 'rotated-profile',
              'message': 'Saved',
            });
          }
          if (r.url.path.endsWith('/account/password')) {
            return jsonResponse({
              'user': user(1, role: 'admin', email: 'changed@example.test'),
              'token': 'rotated-password',
              'message': 'Saved',
            });
          }
          return null;
        },
      );
      await h.start();
      await mount(tester, AccountPage(controller: h.app));
      await enter(tester, 'account-email', 'changed@example.test');
      await tap(tester, 'account-save');
      expect(h.requests, isEmpty);
      await enter(tester, 'account-verification', 'test-password');
      await tap(tester, 'account-save');
      expect(h.app.session!.token, 'rotated-profile');
      await reveal(tester, find.byKey(const Key('account-verification')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('account-verification')))
            .controller!
            .text,
        isEmpty,
      );
      await enter(tester, 'account-current-password', 'test-password');
      await enter(tester, 'account-new-password', 'replacement-password');
      await enter(tester, 'account-confirmation', 'replacement-password');
      await tap(tester, 'account-change-password');
      expect(h.app.session!.token, 'rotated-password');
      expect(
        h.requests.last.headers['Authorization'],
        'Bearer rotated-profile',
      );
      await reveal(tester, find.byKey(const Key('account-new-password')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('account-new-password')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Akun saya'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets(
    'sessions use UTC, require confirmation, and reload after revoke',
    (tester) async {
      final h = Harness(
        handler: (r) => r.url.path.endsWith('/revoke-others')
            ? jsonResponse({
                'user': user(1, role: 'admin'),
                'token': 'rotated-session',
                'message': 'Revoked',
              })
            : null,
      );
      await h.start();
      await mount(tester, SessionsPage(controller: h.app));
      await reveal(tester, find.text('Aktif terakhir: 2026-09-17 01:30 UTC'));
      await enter(tester, 'sessions-password', 'test-password');
      await tap(tester, 'sessions-revoke');
      expect(h.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.byKey(const Key('management-confirm')));
      await tester.pumpAndSettle();
      expect(h.app.session!.token, 'rotated-session');
      await reveal(tester, find.byKey(const Key('sessions-password')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('sessions-password')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        h.requests
            .where((r) => r.url.path.endsWith('/account/sessions'))
            .length,
        2,
      );
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets(
    'settings validate ranges, save only selected non-MQTT section and re-read',
    (tester) async {
      final stored = Map<String, String>.of(settings);
      final h = Harness(
        handler: (r) {
          if (!r.url.path.endsWith('/settings')) return null;
          if (r.method == 'PATCH') {
            final body = jsonDecode(r.body) as Map;
            for (final entry in (body['values'] as Map).entries) {
              stored[entry.key as String] = entry.value is bool
                  ? (entry.value == true ? '1' : '0')
                  : '${entry.value}';
            }
            return jsonResponse({'settings': stored, 'message': 'Saved'});
          }
          return jsonResponse({'settings': stored});
        },
      );
      await h.start();
      await mount(tester, SystemSettingsPage(controller: h.app));
      await enter(tester, 'setting-update_interval', '2');
      await tap(tester, 'settings-save');
      expect(h.requests.where((r) => r.method == 'PATCH'), isEmpty);
      await enter(tester, 'setting-update_interval', '20');
      await tap(tester, 'settings-save');
      final body = jsonDecode(
        h.requests.singleWhere((r) => r.method == 'PATCH').body,
      );
      expect(body, {
        'section': 'general',
        'values': {'update_interval': 20},
      });
      expect(stored['update_interval'], '20');
      await choose(tester, 'settings-section', 'notifications');
      await choose(tester, 'setting-notif_pompa', '0');
      await tap(tester, 'settings-save');
      expect(
        jsonDecode(
          h.requests.where((r) => r.method == 'PATCH').last.body,
        )['values']['notif_pompa'],
        false,
      );
      await choose(tester, 'settings-section', 'climate');
      await enter(tester, 'setting-th_suhu_min', '35');
      await tap(tester, 'settings-save');
      expect(h.requests.where((r) => r.method == 'PATCH').length, 2);
      await enter(tester, 'setting-th_suhu_min', '24');
      await tap(tester, 'settings-save');
      expect(stored['th_suhu_min'], '24');
      expect(
        jsonDecode(
          h.requests.where((r) => r.method == 'PATCH').last.body,
        )['section'],
        'climate',
      );
      await choose(tester, 'settings-section', 'soil');
      await enter(tester, 'setting-soil_on', '65');
      await tap(tester, 'settings-save');
      expect(h.requests.where((r) => r.method == 'PATCH').length, 3);
      await enter(tester, 'setting-soil_on', '25');
      await choose(tester, 'setting-pump_mode', 'manual');
      await tap(tester, 'settings-save');
      expect(stored['pump_mode'], 'manual');
      expect(
        jsonDecode(
          h.requests.where((r) => r.method == 'PATCH').last.body,
        )['section'],
        'soil',
      );
      expect(h.requests.every((r) => !r.body.contains('mqtt')), true);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  test('recovery parser rejects malformed, duplicate, and unsafe links without normalizing tokens', () {
    final token = List.filled(64, 'a').join();
    expect(
      parseRecoveryLink(
        'https://growvia.example/reset-sandi/$token?email=person%2Bfarm%40example.test',
        baseUrl: 'https://growvia.example/api/v1',
      )?.email,
      'person+farm@example.test',
    );
    for (final link in [
      'javascript:alert(1)',
      'https://user:secret@growvia.example/reset-sandi/$token?email=a%40b.test',
      'https://growvia.example/reset-sandi/$token?email=a%40b.test&email=b%40b.test',
      'https://growvia.example/reset-sandi/short?email=a%40b.test',
      'https://growvia.example/reset-sandi/$token?email=a%40b.test#token',
      'https://growvia.example/reset-sandi/$token?email=a%00%40b.test',
      'https://growvia.example/reset-sandi/$token?email=a%40b.test&redirect=https://other.test',
    ]) {
      expect(
        parseRecoveryLink(link, baseUrl: 'https://growvia.example/api/v1'),
        isNull,
      );
    }
  });

  testWidgets(
    'recovery neutral request and reset validation never fetch pasted URL',
    (tester) async {
      final h = Harness(
        handler: (r) =>
            r.url.path.endsWith('/auth/forgot-password') ||
                r.url.path.endsWith('/auth/reset-password')
            ? jsonResponse({'message': 'Processed'})
            : null,
      );
      await h.start(login: false);
      await mount(tester, RecoveryPage(controller: h.app));
      await enter(tester, 'recovery-request-email', 'person@example.test');
      await tap(tester, 'recovery-request');
      await reveal(tester, find.byKey(const Key('recovery-receipt')));
      expect(
        find.textContaining('Jika alamat tersebut memenuhi syarat'),
        findsOneWidget,
      );
      final token = List.filled(64, 'a').join();
      await enter(
        tester,
        'recovery-link',
        'https://growvia.example/reset-sandi/$token?email=person%40example.test',
      );
      await tap(tester, 'recovery-parse');
      expect(h.requests.length, 1);
      await enter(tester, 'recovery-password', 'new-password');
      await enter(tester, 'recovery-confirmation', 'mismatch');
      await tap(tester, 'recovery-reset');
      expect(h.requests.length, 1);
      await enter(tester, 'recovery-confirmation', 'new-password');
      await tap(tester, 'recovery-reset');
      expect(h.requests.length, 2);
      expect(h.requests.every((r) => r.url.host == 'growvia.example'), true);
      expect(jsonDecode(h.requests.last.body)['token'], token);
      await reveal(tester, find.byKey(const Key('recovery-password')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('recovery-password')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets(
    'late private list completion cannot overlay login after logout',
    (tester) async {
      final pending = Completer<http.Response>();
      final h = Harness(
        handler: (r) => r.url.path.endsWith('/users') ? pending.future : null,
      );
      await h.start();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: GrowviaTheme.light(),
          home: const Scaffold(body: Text('Login root')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => UsersPage(controller: h.app)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await h.app.logout();
      await tester.pumpAndSettle();
      pending.complete(
        jsonResponse(page([user(2, name: 'PRIVATE LATE USER')])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Login root'), findsOneWidget);
      expect(find.text('PRIVATE LATE USER'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets('failed list read exposes retry and an honest empty state', (
    tester,
  ) async {
    var reads = 0;
    final h = Harness(
      handler: (r) {
        if (r.url.path.endsWith('/users')) {
          reads++;
          return reads == 1
              ? jsonResponse({'message': 'Unavailable'}, 503)
              : jsonResponse(page([]));
        }
        return null;
      },
    );
    await h.start();
    await mount(tester, UsersPage(controller: h.app));
    await tap(tester, 'management-retry');
    await reveal(tester, find.text('Tidak ada pengguna'));
    expect(reads, 2);
    expect(find.text('Tidak ada pengguna'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    h.app.dispose();
  });

  testWidgets(
    'failed account, sessions, settings, and reset writes never show success',
    (tester) async {
      final h = Harness(
        handler: (r) => r.method == 'PATCH' || r.method == 'POST'
            ? jsonResponse({
                'message': 'Perubahan ditolak.',
                'errors': {
                  'current_password': ['Verifikasi gagal.'],
                  'password': ['Tidak dapat disimpan.'],
                  'update_interval': ['Interval ditolak.'],
                },
              }, 422)
            : null,
      );
      await h.start();
      await mount(tester, AccountPage(controller: h.app));
      await enter(tester, 'account-name', 'Different name');
      await tap(tester, 'account-save');
      expect(find.byKey(const Key('management-errors')), findsOneWidget);
      expect(find.byKey(const Key('management-receipt')), findsNothing);
      expect(h.app.session!.name, 'Admin Test');
      await mount(tester, SessionsPage(controller: h.app));
      await enter(tester, 'sessions-password', 'incorrect-password');
      await tap(tester, 'sessions-revoke');
      await tester.tap(find.byKey(const Key('management-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('management-errors')), findsOneWidget);
      expect(find.byKey(const Key('management-receipt')), findsNothing);
      expect(h.app.session!.token, 'test-token');
      await mount(tester, SystemSettingsPage(controller: h.app));
      await enter(tester, 'setting-update_interval', '25');
      await tap(tester, 'settings-save');
      expect(find.byKey(const Key('management-errors')), findsOneWidget);
      expect(find.byKey(const Key('management-receipt')), findsNothing);
      await h.app.logout();
      await mount(tester, RecoveryPage(controller: h.app));
      final token = List.filled(64, 'b').join();
      await enter(
        tester,
        'recovery-link',
        'https://growvia.example/reset-sandi/$token?email=person%40example.test',
      );
      await tap(tester, 'recovery-parse');
      await enter(tester, 'recovery-password', 'new-password');
      await enter(tester, 'recovery-confirmation', 'new-password');
      await tap(tester, 'recovery-reset');
      expect(find.byKey(const Key('management-errors')), findsOneWidget);
      expect(find.byKey(const Key('recovery-receipt')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets('profile-only refresh keeps an authenticated pushed route open', (
    tester,
  ) async {
    final h = Harness(
      handler: (r) => r.url.path.endsWith('/account/profile')
          ? jsonResponse({
              'user': user(1, role: 'admin', name: 'Updated Name'),
              'message': 'Saved',
            })
          : null,
    );
    await h.start();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: GrowviaTheme.light(),
        home: const Scaffold(body: Text('Shell root')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => AccountPage(controller: h.app)),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'account-name', 'Updated Name');
    await tap(tester, 'account-save');
    expect(navigator.currentState!.canPop(), true);
    expect(find.text('Akun saya'), findsOneWidget);
    expect(h.app.session!.name, 'Updated Name');
    expect(h.app.session!.token, 'test-token');
    await tester.pumpWidget(const SizedBox());
    h.app.dispose();
  });

  testWidgets(
    'late account write after logout cannot show a success receipt or restore route',
    (tester) async {
      final pending = Completer<http.Response>();
      final h = Harness(
        handler: (r) =>
            r.url.path.endsWith('/account/profile') ? pending.future : null,
      );
      await h.start();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: GrowviaTheme.light(),
          home: const Scaffold(body: Text('Login root')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => AccountPage(controller: h.app)),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'account-name', 'Late profile');
      await reveal(tester, find.byKey(const Key('account-save')));
      await tester.tap(find.byKey(const Key('account-save')));
      await tester.pump();
      await h.app.logout();
      await tester.pumpAndSettle();
      pending.complete(
        jsonResponse({
          'user': user(1, role: 'admin', name: 'Late profile'),
          'message': 'Saved',
        }),
      );
      await tester.pumpAndSettle();
      expect(h.app.session, isNull);
      expect(find.text('Login root'), findsOneWidget);
      expect(find.byKey(const Key('management-receipt')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets(
    'selectors and confirmation remain usable on small landscape with large text',
    (tester) async {
      final h = Harness();
      await h.start();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(640, 360);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, UsersPage(controller: h.app), scale: 2, dark: true);
      await choose(tester, 'users-role', 'admin');
      expect(tester.takeException(), isNull);
      expect(find.text('Hak akses: Administrator'), findsOneWidget);
      await tap(tester, 'user-delete-2');
      await tester.ensureVisible(find.byKey(const Key('management-confirm')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(h.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets('members may manage only their own account and sessions', (
    tester,
  ) async {
    final h = Harness(role: 'user');
    await h.start();
    await mount(tester, AccountPage(controller: h.app));
    expect(find.byKey(const Key('account-name')), findsOneWidget);
    await tap(tester, 'account-sessions');
    expect(find.text('Perangkat & sesi'), findsOneWidget);
    expect(h.requests.single.url.path, '/api/v1/account/sessions');
    await tester.pumpWidget(const SizedBox());
    h.app.dispose();
  });

  testWidgets(
    '401 closes a pushed management route and clears cached private data',
    (tester) async {
      final h = Harness(
        handler: (r) => r.url.path.endsWith('/users')
            ? jsonResponse({'message': 'Expired'}, 401)
            : null,
      );
      await h.start();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: GrowviaTheme.light(),
          home: const Scaffold(body: Text('Login root')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => UsersPage(controller: h.app)),
      );
      await tester.pumpAndSettle();
      expect(h.app.session, isNull);
      expect(find.text('Login root'), findsOneWidget);
      expect(navigator.currentState!.canPop(), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );

  testWidgets(
    'all management pages scroll without overflow at text scale two portrait and landscape',
    (tester) async {
      final h = Harness();
      await h.start();
      final widgets = <Widget>[
        UsersPage(controller: h.app),
        ActivityPage(controller: h.app),
        AccountPage(controller: h.app),
        SessionsPage(controller: h.app),
        SystemSettingsPage(controller: h.app),
      ];
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(360, 800), const Size(800, 360)]) {
        tester.view.physicalSize = size;
        for (final widget in widgets) {
          await mount(tester, widget, scale: 2, dark: size.width > size.height);
          if (widget is UsersPage) await tap(tester, 'user-add');
          for (var i = 0; i < 8; i++) {
            await tester.drag(
              find.byKey(const Key('management-scroll')),
              const Offset(0, -400),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
      await h.app.logout();
      await mount(
        tester,
        RecoveryPage(controller: h.app),
        scale: 2,
        dark: true,
      );
      for (var i = 0; i < 8; i++) {
        await tester.drag(
          find.byKey(const Key('management-scroll')),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      h.app.dispose();
    },
  );
}
