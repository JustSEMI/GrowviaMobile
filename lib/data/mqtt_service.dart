import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'reading.dart';

/// Alamat MQTT bawaan: websocket TLS broker EMQX lewat Cloudflare Tunnel.
/// Jalur debug lokal: `adb reverse tcp:8083 tcp:8083` lalu ws://127.0.0.1:8083/mqtt.
const String defaultMqttUrl = 'wss://mqtt.justsemi.my.id/mqtt';

/// Akun baca khusus aplikasi (bukan akun perangkat Device1/Device2).
const String mqttLiveUsername = 'Growvia';
const String mqttLivePassword = 'GrowviaMobile';

/// Topik data perangkat, identik dengan langganan `mqtt:consume` di backend.
const List<String> mqttLiveTopics = <String>['growvia/node1/data', 'growvia/node2/data'];

/// Uraikan alamat `ws://` atau `wss://` menjadi host, port, dan penanda TLS.
({String host, int port, bool secure}) parseMqttUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const FormatException(
      'Alamat MQTT tidak valid. Gunakan ws://host:port/mqtt atau wss://host/mqtt.',
    );
  }
  final secure = switch (uri.scheme) {
    'wss' => true,
    'ws' => false,
    _ => throw const FormatException('Skema MQTT harus ws:// atau wss://.'),
  };
  final port = uri.port != 0 ? uri.port : (secure ? 443 : 80);
  return (host: uri.host, port: port, secure: secure);
}

/// Terjemahkan satu pesan MQTT `growvia/nodeX/data` menjadi daftar [Reading].
///
/// Aturannya dicerminkan dari `ReadingIngester` di backend: topik asing,
/// JSON rusak, atau metric tak dikenal ditolak tanpa menghasilkan baris palsu.
List<Reading> readingsFromLiveMessage(
  String topic,
  String payload, {
  DateTime? recordedAt,
}) {
  final parts = topic.split('/');
  if (parts.length < 2 || parts.last != 'data') return const [];
  final node = parts[parts.length - 2];
  if (node != 'node1' && node != 'node2') return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on FormatException {
    return const [];
  }
  if (decoded is! Map<String, dynamic>) return const [];
  final when = (recordedAt ?? DateTime.now()).toUtc();
  final readings = <Reading>[];
  for (final entry in kMetricUnits.entries) {
    final raw = decoded[entry.key];
    if (raw is! num || !raw.isFinite) continue;
    readings.add(
      Reading(
        id: when.microsecondsSinceEpoch,
        node: node,
        metric: entry.key,
        value: raw.toDouble(),
        unit: entry.value,
        recordedAt: when,
      ),
    );
  }
  return readings;
}

/// Tanda tangan pabrik sambungan MQTT; dipasang di `main()` dan dipalsukan di test.
typedef MqttLiveServiceFactory =
    MqttLiveService Function({
      required void Function(List<Reading> readings) onReadings,
      required void Function(bool connected, String? error) onStatus,
    });

/// Pabrik bawaan untuk produksi: alamat publik lewat Cloudflare Tunnel.
MqttLiveService defaultMqttLiveFactory({
  required void Function(List<Reading> readings) onReadings,
  required void Function(bool connected, String? error) onStatus,
}) => MqttLiveService(url: defaultMqttUrl, onReadings: onReadings, onStatus: onStatus);

/// Sambungan MQTT langsung untuk aplikasi: berlangganan topik data perangkat
/// dan meneruskan hasil parsing ke [onReadings], status ke [onStatus].
///
/// Koneksi pertama yang gagal dicoba ulang tiap 10 detik; setelah pernah
/// tersambung, sambung-ulang otomatis bawaan paket mqtt_client yang bekerja.
class MqttLiveService {
  MqttLiveService({
    required String url,
    required this.onReadings,
    required this.onStatus,
    String? clientId,
  }) : _endpoint = parseMqttUrl(url),
       _server = url.trim(),
       _clientId = clientId ?? _newClientId();

  final void Function(List<Reading> readings) onReadings;
  final void Function(bool connected, String? error) onStatus;

  final ({String host, int port, bool secure}) _endpoint;

  /// Alamat lengkap termasuk skema dan jalur (`/mqtt`), karena koneksi
  /// websocket memakainya apa adanya untuk handshake HTTP.
  final String _server;
  final String _clientId;
  MqttServerClient? _client;
  Timer? _retry;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updates;
  bool _disposed = false;
  bool _everConnected = false;

  static String _newClientId() =>
      'growvia-mobile-${DateTime.now().millisecondsSinceEpoch}';

  Future<void> connect() async {
    if (_disposed) return;
    final client = MqttServerClient.withPort(
      _server,
      _clientId,
      _endpoint.port,
    )
      ..useWebSocket = true
      ..websocketProtocols = MqttClientConstants.protocolsSingleDefault
      ..keepAlivePeriod = 20
      ..connectTimeoutPeriod = 8000
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..logging(on: false);
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_clientId)
        .authenticateAs(mqttLiveUsername, mqttLivePassword)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.onConnected = () => onStatus(true, null);
    client.onAutoReconnected = () => onStatus(true, null);
    client.onAutoReconnect = () => onStatus(false, 'Menyambung ulang ke MQTT.');
    client.onDisconnected = () {
      onStatus(false, _everConnected ? null : 'MQTT terputus.');
      if (!_disposed) _scheduleRetry();
    };
    _client = client;
    try {
      await client.connect(mqttLiveUsername, mqttLivePassword);
    } catch (_) {
      if (_disposed) return;
      onStatus(false, 'MQTT tidak dapat dihubungi.');
      _closeClient(client);
      _scheduleRetry();
      return;
    }
    if (_disposed) return;
    final state = client.connectionStatus?.state;
    if (state != MqttConnectionState.connected) {
      onStatus(false, 'MQTT menolak koneksi.');
      _closeClient(client);
      _scheduleRetry();
      return;
    }
    _everConnected = true;
    onStatus(true, null);
    for (final topic in mqttLiveTopics) {
      client.subscribe(topic, MqttQos.atLeastOnce);
    }
    _updates = client.updates!.listen((messages) {
      if (_disposed) return;
      final incoming = <Reading>[];
      for (final message in messages) {
        final publication = message.payload;
        if (publication is! MqttPublishMessage) continue;
        final text = MqttPublishPayload.bytesToStringAsString(
          publication.payload.message,
        );
        incoming.addAll(readingsFromLiveMessage(message.topic, text));
      }
      if (incoming.isNotEmpty) onReadings(incoming);
    });
  }

  void _scheduleRetry() {
    _retry ??= Timer(const Duration(seconds: 10), () {
      _retry = null;
      if (!_disposed) connect();
    });
  }

  void _closeClient(MqttServerClient client) {
    try {
      client.disconnect();
    } catch (_) {
      // Koneksi yang gagal terbuka tidak perlu dipaksa tutup dua kali.
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    _updates?.cancel();
    _client?.disconnect();
    _client = null;
  }
}
