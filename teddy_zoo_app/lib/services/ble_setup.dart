import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../model/animal.dart';
import '../model/zoo_model.dart';

/// BLE service and characteristics of teddy_link.ino.
final serviceUuid = Guid('0e7a1000-7edd-4bea-a000-5eed12345678');
final setupUuid = Guid('0e7a1003-7edd-4bea-a000-5eed12345678'); // write "ssid\tpassword\tzoocode", "scan", "reset"
final infoUuid = Guid('0e7a1004-7edd-4bea-a000-5eed12345678'); // read "id=… mode=… wifi=none|fail:<n>|ok pair=…"; notifies ok=saved / scan=done / scan=failed / error=…
final netsUuid = Guid('0e7a1005-7edd-4bea-a000-5eed12345678'); // read JSON [{"s":ssid,"r":rssi,"l":locked}] after scan=done

/// `wifi=fail:<reason>` in INFO: the ESP32's disconnect reason from the last attempt.
const wifiReasons = {
  201: 'network not found',
  202: 'wrong password',
  15: 'wrong password (handshake timed out)',
  200: 'the router stopped answering',
  203: 'the router refused the connection',
  8: 'the router dropped it',
};

String wifiFailText(String info) {
  final m = RegExp(r'wifi=fail(?::(\d+))?').firstMatch(info);
  if (m == null) return '';
  final r = int.tryParse(m.group(1) ?? '');
  if (r == null) return 'unknown reason';
  return wifiReasons[r] ?? 'reason $r';
}

String infoId(String info) => RegExp(r'id=(\w+)').firstMatch(info)?.group(1) ?? '?';

class WifiNet {
  WifiNet(this.ssid, this.rssi, this.locked);
  final String ssid;
  final int rssi;
  final bool locked;
  static List<WifiNet> parse(String json) {
    try {
      final d = jsonDecode(json);
      if (d is! List) return [];
      return d.whereType<Map>().map((e) => WifiNet('${e['s'] ?? ''}', (e['r'] is num) ? (e['r'] as num).toInt() : -100, e['l'] == 1 || e['l'] == true)).where((n) => n.ssid.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}

/// A Teddy seen while scanning.
class FoundAnimal {
  FoundAnimal(this.device, this.rssi);
  final BluetoothDevice device;
  int rssi;
}

/// State machine for "Add an animal": the four steps of zoo.html's add flow.
///  1 find (BLE scan, connect, read INFO)
///  2 WiFi: scan via SETUP="scan" + INFO notify scan=done + NETS read; send ssid\tpass\tcode
///  3 joining: wait for `state/<id>` online over MQTT (15 s: skip; 30 s: help + retry BLE)
///  4 name / species / owner → retained `meta/<id>`
class AddController extends ChangeNotifier {
  AddController(this.zoo);
  final ZooModel zoo;

  int step = 1;
  String status = 'not connected';
  bool statusBad = false;
  bool statusBusy = false;
  bool scanningBle = false;
  bool bleAvailable = true;
  List<FoundAnimal> found = [];

  BluetoothDevice? device;
  BluetoothCharacteristic? _setup, _info, _nets;
  String id = '';
  String fail = '';
  bool get connected => device?.isConnected ?? false;

  bool scanningNets = false;
  List<WifiNet> nets = [];
  /// Index into [nets], or -1 for "Other", or null for nothing picked.
  int? pick;
  String ssid = '';
  bool sending = false;

  bool showSkip = false, showHelp = false;
  Timer? _waitTimer, _helpTimer, _savedFallback;
  String species = 'elephant';

  final _subs = <StreamSubscription>[];

  void _set(String text, {bool bad = false, bool busy = false}) {
    status = text;
    statusBad = bad;
    statusBusy = busy;
    notifyListeners();
  }

  // ----------------------------------------------------------------- step 1
  Future<void> startBleScan() async {
    found = [];
    scanningBle = true;
    _set('looking for an animal called “Teddy”…', busy: true);
    try {
      if (!await FlutterBluePlus.isSupported) {
        bleAvailable = false;
        scanningBle = false;
        _set('this phone has no Bluetooth LE', bad: true);
        return;
      }
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (_) {}
        }
        final s2 = await FlutterBluePlus.adapterState.where((s) => s != BluetoothAdapterState.unknown).first.timeout(const Duration(seconds: 5), onTimeout: () => state);
        if (s2 != BluetoothAdapterState.on) {
          scanningBle = false;
          _set('Bluetooth is off. Turn it on in Settings and try again.', bad: true);
          return;
        }
      }
      final sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final i = found.indexWhere((f) => f.device.remoteId == r.device.remoteId);
          if (i >= 0) {
            found[i].rssi = r.rssi;
          } else {
            found.add(FoundAnimal(r.device, r.rssi));
          }
        }
        found.sort((a, b) => b.rssi.compareTo(a.rssi));
        notifyListeners();
      }, onError: (e) => _set('scan failed: $e', bad: true));
      _subs.add(sub);
      await FlutterBluePlus.startScan(withServices: [serviceUuid], timeout: const Duration(seconds: 12));
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      await sub.cancel();
      _subs.remove(sub);
      scanningBle = false;
      if (step == 1 && device == null) {
        _set(found.isEmpty ? 'no animal found. Is it switched on and not set up yet?' : 'tap the animal to connect', bad: found.isEmpty);
      }
    } catch (e) {
      scanningBle = false;
      _set('couldn’t scan: $e', bad: true);
    }
  }

  Future<void> stopBleScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<void> connectTo(BluetoothDevice d) async {
    await stopBleScan();
    device = d;
    _set('connecting…', busy: true);
    try {
      await d.connect(license: License.nonprofit, timeout: const Duration(seconds: 15), mtu: null);
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await d.requestMtu(256);
        } catch (_) {}
      }
      _subs.add(d.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && device == d && step < 3) {
          _resetBle();
          step = 1;
          id = '';
          _set('Bluetooth dropped. Connect again.', bad: true);
        }
      }));
      final services = await d.discoverServices();
      final svc = services.where((s) => s.uuid == serviceUuid).firstOrNull;
      if (svc == null) throw Exception('not a Teddy (no setup service)');
      for (final c in svc.characteristics) {
        if (c.uuid == setupUuid) _setup = c;
        if (c.uuid == infoUuid) _info = c;
        if (c.uuid == netsUuid) _nets = c;
      }
      if (_setup == null || _info == null) throw Exception('setup characteristics missing');
      final info = utf8.decode(await _info!.read(), allowMalformed: true);
      id = infoId(info);
      fail = wifiFailText(info);
      _set('connected to Teddy $id${fail.isNotEmpty ? ' · WiFi failed last time: $fail' : ''}', bad: fail.isNotEmpty);
      try {
        await _info!.setNotifyValue(true);
        _subs.add(_info!.onValueReceived.listen((v) => _onInfo(utf8.decode(v, allowMalformed: true))));
      } catch (_) {}
      step = 2;
      pick = null;
      if (_nets != null) {
        scanNets();
      } else {
        nets = [];
        scanningNets = false;
        pick = -1;
      }
      notifyListeners();
    } catch (e) {
      _resetBle();
      _set('couldn’t connect: ${_short(e)}', bad: true);
    }
  }

  String _short(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  void _onInfo(String v) {
    if (v.startsWith('ok=saved')) {
      saved();
    } else if (v.startsWith('scan=done')) {
      readNets();
    } else if (v.startsWith('scan=failed')) {
      nets = [];
      scanningNets = false;
      pick = -1;
      notifyListeners();
    } else if (v.startsWith('error')) {
      sending = false;
      _set('the animal said: $v', bad: true);
    }
  }

  // ----------------------------------------------------------------- step 2
  Future<void> _write(String s) async {
    final c = _setup;
    if (c == null) throw Exception('not connected');
    final bytes = utf8.encode(s);
    // SETUP is write-with-response only on the firmware; long values need a long write.
    await c.write(bytes, withoutResponse: false, allowLongWrite: bytes.length > 20);
  }

  Future<void> scanNets() async {
    if (_setup == null) return;
    scanningNets = true;
    pick = null;
    notifyListeners();
    try {
      await _write('scan');
    } catch (_) {
      nets = [];
      scanningNets = false;
      pick = -1;
      notifyListeners();
    }
  }

  Future<void> readNets() async {
    try {
      nets = _nets == null ? [] : WifiNet.parse(utf8.decode(await _nets!.read(), allowMalformed: true));
    } catch (_) {
      nets = [];
    }
    scanningNets = false;
    final saved = zoo.ssidHint;
    final i = nets.indexWhere((n) => n.ssid == saved);
    pick = i >= 0 ? i : (nets.isEmpty ? -1 : null);
    notifyListeners();
  }

  void setPick(int? i) {
    pick = i;
    notifyListeners();
  }

  /// Returns an error message, or null when the setup string went out.
  Future<String?> sendSetup({required String ssidText, required String pass, required String pair}) async {
    final other = pick == -1;
    final s = other ? ssidText.trim() : (pick != null && pick! < nets.length ? nets[pick!].ssid : '');
    if (s.isEmpty) return 'The network name is empty.';
    if (!validCode(pair)) return 'A zoo code is 4 to 32 letters or digits.';
    if ('$s$pass$pair'.contains('\t')) return 'No tabs allowed.';
    sending = true;
    notifyListeners();
    try {
      await _write('$s\t$pass\t$pair');
      ssid = s;
      zoo.rememberSsid(s);
      if (pair != zoo.zoo) {
        zoo.saveZoo(pair);
        zoo.connect(pair);
      }
      // if the animal's ok=saved never arrives, assume it rebooted
      _savedFallback = Timer(const Duration(milliseconds: 2500), () {
        if (step == 2) saved();
      });
      return null;
    } catch (e) {
      sending = false;
      notifyListeners();
      return 'Sending failed: ${_short(e)}';
    }
  }

  Future<String?> forgetWifi() async {
    try {
      await _write('reset');
      return null;
    } catch (e) {
      return 'Failed: ${_short(e)}';
    }
  }

  // ----------------------------------------------------------------- step 3
  void saved() {
    if (step != 2) return;
    _savedFallback?.cancel();
    sending = false;
    step = 3;
    showSkip = false;
    showHelp = false;
    zoo.pendingAddId = id;
    zoo.onPendingOnline = arrived;
    notifyListeners();
    final a = zoo.animals[id];
    if (a != null && a.online) {
      arrived();
      return;
    }
    _waitTimer = Timer(const Duration(seconds: 15), () {
      showSkip = true;
      notifyListeners();
    });
    _helpTimer = Timer(const Duration(seconds: 30), () {
      showHelp = true;
      notifyListeners();
    });
  }

  void arrived() {
    if (step != 3) return;
    _waitTimer?.cancel();
    _helpTimer?.cancel();
    step = 4;
    notifyListeners();
  }

  /// "Connect again over Bluetooth": back to step 1, keeping nothing.
  void retryBle() {
    leave();
    step = 1;
    notifyListeners();
    startBleScan();
  }

  // ----------------------------------------------------------------- step 4
  /// Publishes the retained meta and returns whether the broker took it.
  bool finish({required String name, required String owner}) {
    if (owner.isNotEmpty && zoo.owner.isEmpty) zoo.setOwner(owner);
    final a = zoo.animal(id);
    a.name = name;
    a.species = species;
    a.owner = owner;
    final ok = zoo.publishMeta(id);
    zoo.pendingAddId = '';
    zoo.onPendingOnline = null;
    zoo.rememberMyBear(id);
    return ok;
  }

  void setSpecies(String s) {
    species = s;
    notifyListeners();
  }

  // ------------------------------------------------------------------ reset
  void _resetBle() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    final d = device;
    device = null;
    _setup = null;
    _info = null;
    _nets = null;
    if (d != null) {
      d.disconnect().catchError((_) {});
    }
  }

  void leave() {
    _waitTimer?.cancel();
    _helpTimer?.cancel();
    _savedFallback?.cancel();
    stopBleScan();
    _resetBle();
    zoo.pendingAddId = '';
    zoo.onPendingOnline = null;
    step = 1;
    id = '';
    fail = '';
    nets = [];
    scanningNets = false;
    pick = null;
    sending = false;
    species = 'elephant';
    showSkip = false;
    showHelp = false;
    found = [];
    scanningBle = false;
    status = 'not connected';
    statusBad = false;
    statusBusy = false;
  }

  @override
  void dispose() {
    leave();
    super.dispose();
  }
}
