import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'animal.dart';

/// Everything the screens share: the zoo code, who you are, the broker, the
/// animals (built from the retained state/meta/links topics) and the MQTT
/// client. One instance lives for the whole app.
class ZooModel extends ChangeNotifier {
  ZooModel(this._prefs) {
    zoo = (_prefs.getString('teddy.pair') ?? '').trim();
    owner = (_prefs.getString('teddy.owner') ?? '').trim();
    broker = (_prefs.getString('teddy.broker') ?? defaultBroker).trim();
    themeMode = switch (_prefs.getString('teddy-theme')) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
  }

  final SharedPreferences _prefs;

  Map<String, Animal> animals = {};
  String zoo = '';
  String owner = '';
  String broker = defaultBroker;
  String filter = 'all';
  ThemeMode themeMode = ThemeMode.system;

  /// The zoo being previewed from a join link, if any, and the one to go back to.
  String? join;
  String? _joinPrev;

  /// Set by the add flow while it waits for a freshly set-up animal to come online.
  String pendingAddId = '';
  VoidCallback? onPendingOnline;

  MqttServerClient? _client;
  bool _connected = false;
  String? error;
  StreamSubscription? _sub;

  bool get brokerUp => _client != null && _connected;
  bool get connecting => _client != null && !_connected;

  Animal animal(String id) => animals.putIfAbsent(id, Animal.new);
  bool isMine(Animal a) => owner.isNotEmpty && sameName(a.owner, owner);
  bool linkedToMine(String id) {
    final a = animals[id];
    return animals.entries.any((e) => e.key != id && isMine(e.value) && e.value.links.contains(id)) ||
        (a != null && a.links.any((x) => animals[x] != null && isMine(animals[x]!)));
  }

  /// Ids sorted mine first, then by label.
  List<String> ids() {
    final l = animals.keys.toList();
    l.sort((x, y) {
      final m = (isMine(animals[y]!) ? 1 : 0) - (isMine(animals[x]!) ? 1 : 0);
      if (m != 0) return m;
      return animalLabel(x, animals[x]).toLowerCase().compareTo(animalLabel(y, animals[y]).toLowerCase());
    });
    return l;
  }

  String label(String id) => animalLabel(id, animals[id]);

  String get ssidHint => _prefs.getString('teddy.ssid') ?? '';
  void rememberSsid(String s) => _prefs.setString('teddy.ssid', s);
  void rememberMyBear(String id) => _prefs.setString('teddy.myBear', id);

  // ---------------------------------------------------------------- settings
  void setOwner(String v) {
    owner = v.trim();
    _prefs.setString('teddy.owner', owner);
    notifyListeners();
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    _prefs.setString('teddy-theme', switch (m) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', _ => 'system' });
    notifyListeners();
  }

  void setBroker(String v) {
    broker = v.trim().isEmpty ? defaultBroker : v.trim();
    _prefs.setString('teddy.broker', broker);
    connect(zoo);
  }

  void setFilter(String f) {
    filter = f;
    notifyListeners();
  }

  void saveZoo(String code) {
    zoo = code;
    _prefs.setString('teddy.pair', code);
  }

  void leaveZoo() {
    _prefs.remove('teddy.pair');
    connect('');
  }

  // ------------------------------------------------------------------ broker
  Future<void> connect(String code) async {
    await _dropClient();
    animals = {};
    zoo = code;
    error = null;
    notifyListeners();
    if (!validCode(zoo)) return;

    final target = BrokerTarget.parse(broker);
    final clientId = 'teddyapp-${Random().nextInt(0xffffff).toRadixString(16).padLeft(6, '0')}';
    final c = MqttServerClient.withPort(target.server, clientId, target.port);
    c.logging(on: false);
    c.useWebSocket = target.websocket;
    c.secure = target.secure;
    c.websocketProtocols = const ['mqtt'];
    c.keepAlivePeriod = 30;
    c.autoReconnect = true;
    c.resubscribeOnAutoReconnect = true;
    c.setProtocolV311();
    c.connectionMessage = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    c.onConnected = () {
      if (_client != c) return;
      _connected = true;
      notifyListeners();
    };
    c.onDisconnected = () {
      if (_client != c) return;
      _connected = false;
      notifyListeners();
    };
    c.onAutoReconnect = () {
      if (_client != c) return;
      _connected = false;
      notifyListeners();
    };
    c.onAutoReconnected = () {
      if (_client != c) return;
      _connected = true;
      notifyListeners();
    };
    _client = c;
    final zooNow = zoo;
    try {
      final status = await c.connect();
      if (_client != c) return;
      if (status?.state != MqttConnectionState.connected) {
        error = 'broker error: ${status?.returnCode ?? status?.state}';
        _connected = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      if (_client != c) return;
      error = 'broker error: $e';
      _connected = false;
      notifyListeners();
      return;
    }
    _connected = true;
    _sub = c.updates?.listen((events) {
      for (final e in events) {
        final msg = e.payload;
        if (msg is! MqttPublishMessage) continue;
        String payload;
        try {
          payload = utf8.decode(msg.payload.message, allowMalformed: true);
        } catch (_) {
          payload = '';
        }
        _onMessage(e.topic, payload);
      }
    });
    for (final t in ['teddy/$zooNow/state/+', 'teddy/$zooNow/meta/+', 'teddy/$zooNow/links/+']) {
      c.subscribe(t, MqttQos.atMostOnce);
    }
    notifyListeners();
  }

  void _onMessage(String topic, String payload) {
    final parts = topic.split('/');
    if (parts.length < 4) return;
    final kind = parts[2], id = parts[3];
    if (id.isEmpty) return;
    final a = animal(id);
    Map<String, dynamic> j = {};
    try {
      final d = jsonDecode(payload);
      if (d is Map<String, dynamic>) j = d;
    } catch (_) {}
    switch (kind) {
      case 'state':
        final on = j['online'];
        a.online = on == true || on == 1 || on == '1';
        a.led = (j['led'] is num) ? (j['led'] as num).toInt() : int.tryParse('${j['led']}') ?? 0;
      case 'meta':
        a.name = '${j['name'] ?? ''}';
        a.species = '${j['species'] ?? ''}';
        a.owner = '${j['owner'] ?? ''}';
      case 'links':
        final ids = j['ids'];
        a.links = ids is List ? ids.whereType<String>().toList() : [];
      default:
        return;
    }
    if (kind == 'state' && pendingAddId.isNotEmpty && id == pendingAddId && a.online) onPendingOnline?.call();
    notifyListeners();
  }

  Future<void> _dropClient() async {
    await _sub?.cancel();
    _sub = null;
    final c = _client;
    _client = null;
    _connected = false;
    if (c != null) {
      c.autoReconnect = false;
      try {
        c.disconnect();
      } catch (_) {}
    }
  }

  void _publish(String sub, Map<String, dynamic> obj, {bool retain = false}) {
    final c = _client;
    if (c == null || !_connected) return;
    final b = MqttClientPayloadBuilder()..addUTF8String(jsonEncode(obj));
    c.publishMessage('teddy/$zoo/$sub', MqttQos.atMostOnce, b.payload!, retain: retain);
  }

  /// touch: {"from":"app","to":id, ...} — motor 1/0 or led 0/1/2.
  void send(String id, Map<String, dynamic> obj) {
    if (!brokerUp || id.isEmpty) return;
    _publish('touch', {'from': 'app', 'to': id, ...obj});
  }

  bool publishRetained(String sub, Map<String, dynamic> obj) {
    if (!brokerUp) return false;
    _publish(sub, obj, retain: true);
    return true;
  }

  bool publishMeta(String id) {
    final a = animal(id);
    final ok = publishRetained('meta/$id', {'name': a.name, 'species': a.species, 'owner': a.owner});
    notifyListeners();
    return ok;
  }

  bool publishLinks(String id, List<String> ids) {
    animal(id).links = List.of(ids);
    final ok = publishRetained('links/$id', {'ids': ids});
    notifyListeners();
    return ok;
  }

  void sendToSetup(String id) {
    if (!brokerUp) return;
    _publish('cmd/$id', {'cmd': 'setup'});
  }

  // -------------------------------------------------------------------- join
  /// Preview a zoo from a scanned code without saving it.
  void joinStart(String code) {
    code = code.trim();
    if (!validCode(code) || join == code) return;
    _joinPrev = zoo;
    join = code;
    connect(code);
  }

  void joinLeave({required bool keep}) {
    final code = join;
    if (code == null) return;
    join = null;
    if (keep) {
      saveZoo(code);
      notifyListeners();
    } else if (_joinPrev != zoo) {
      connect(_joinPrev ?? '');
    }
    _joinPrev = null;
  }

  @override
  void dispose() {
    _dropClient();
    super.dispose();
  }
}

/// Broker URL → what mqtt_client wants. Accepts wss://host:port/path,
/// ws://…, mqtt://host:port, mqtts://host:port, or a bare host.
class BrokerTarget {
  BrokerTarget(this.server, this.port, {required this.websocket, required this.secure});
  final String server;
  final int port;
  final bool websocket;
  final bool secure;

  static BrokerTarget parse(String s) {
    var u = Uri.tryParse(s.contains('://') ? s : 'mqtt://$s');
    if (u == null || u.host.isEmpty) u = Uri.parse(defaultBroker);
    final scheme = u.scheme.toLowerCase();
    switch (scheme) {
      case 'ws':
      case 'wss':
        final port = u.hasPort ? u.port : (scheme == 'wss' ? 443 : 80);
        final path = u.path.isEmpty ? '/mqtt' : u.path;
        return BrokerTarget('$scheme://${u.host}$path', port, websocket: true, secure: false);
      case 'mqtts':
      case 'ssl':
      case 'tls':
        return BrokerTarget(u.host, u.hasPort ? u.port : 8883, websocket: false, secure: true);
      default:
        return BrokerTarget(u.host, u.hasPort ? u.port : 1883, websocket: false, secure: false);
    }
  }
}
