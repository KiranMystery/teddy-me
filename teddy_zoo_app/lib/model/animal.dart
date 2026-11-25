/// One animal in the zoo, as seen through the retained MQTT topics.
class Animal {
  Animal({this.online = false, this.led = 0, this.name = '', this.species = '', this.owner = '', List<String>? links})
      : links = links ?? [];

  bool online;
  int led;
  String name;
  String species;
  String owner;
  List<String> links;
}

const ledNames = ['off', 'slow pulse, like a heartbeat', 'steady on'];
const speciesLabels = {'elephant': 'Elephant', 'bear': 'Bear'};

String speciesLabel(String? s) {
  final k = (s ?? '').toLowerCase();
  if (speciesLabels.containsKey(k)) return speciesLabels[k]!;
  if (k.isEmpty) return 'Unknown species';
  return k[0].toUpperCase() + k.substring(1);
}

String animalLabel(String id, Animal? a) {
  if (a == null) return 'Animal $id';
  if (a.name.isNotEmpty) return a.name;
  if (a.species.isNotEmpty) return '${speciesLabel(a.species)} $id';
  return 'Animal $id';
}

bool sameName(String? a, String? b) => (a ?? '').trim().toLowerCase() == (b ?? '').trim().toLowerCase();

final _codeRe = RegExp(r'^[a-z0-9]{4,32}$', caseSensitive: false);
bool validCode(String? c) => _codeRe.hasMatch(c ?? '');

String genCode() {
  const a = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = DateTime.now().microsecondsSinceEpoch;
  var seed = r;
  final sb = StringBuffer();
  for (var i = 0; i < 8; i++) {
    seed = (seed * 6364136223846793005 + 1442695040888963407) & 0x7fffffffffffffff;
    sb.write(a[(seed >> 33) % a.length]);
  }
  return sb.toString();
}

/// The zoo share link. The native app always uses the short iome.uk form;
/// the host rewrites /zoo/<code> to zoo.html?join=<code> for the web app.
const shareHost = 'iome.uk';
String shareUrl(String code) => 'https://$shareHost/zoo/${Uri.encodeComponent(code)}';
const defaultBroker = 'wss://broker.emqx.io:8084/mqtt';
