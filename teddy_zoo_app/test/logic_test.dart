import 'package:flutter_test/flutter_test.dart';
import 'package:teddy_zoo_app/model/animal.dart';
import 'package:teddy_zoo_app/model/zoo_model.dart';
import 'package:teddy_zoo_app/services/ble_setup.dart';

void main() {
  group('labels and codes', () {
    test('animalLabel falls back to species + id, then Animal id', () {
      expect(animalLabel('7c2a9f', Animal(name: 'Ellie')), 'Ellie');
      expect(animalLabel('7c2a9f', Animal(species: 'bear')), 'Bear 7c2a9f');
      expect(animalLabel('7c2a9f', Animal(species: 'dragon')), 'Dragon 7c2a9f');
      expect(animalLabel('7c2a9f', Animal()), 'Animal 7c2a9f');
      expect(animalLabel('7c2a9f', null), 'Animal 7c2a9f');
    });
    test('validCode is 4–32 letters or digits', () {
      expect(validCode('azvn6tre'), isTrue);
      expect(validCode('abc'), isFalse);
      expect(validCode('has space'), isFalse);
      expect(validCode(null), isFalse);
    });
    test('genCode makes 8 unambiguous chars', () {
      final c = genCode();
      expect(c.length, 8);
      expect(RegExp(r'^[abcdefghjkmnpqrstuvwxyz23456789]{8}$').hasMatch(c), isTrue);
    });
    test('shareUrl is the short iome.uk link', () {
      expect(shareUrl('azvn6tre'), 'https://iome.uk/zoo/azvn6tre');
    });
  });

  group('INFO parsing', () {
    test('id and wifi failure reasons', () {
      expect(infoId('id=7c2a9f mode=setup wifi=none pair='), '7c2a9f');
      expect(wifiFailText('id=7c2a9f mode=setup wifi=none pair='), '');
      expect(wifiFailText('id=7c2a9f mode=setup wifi=fail:202 pair=azvn6tre'), 'wrong password');
      expect(wifiFailText('id=7c2a9f mode=setup wifi=fail:201 pair=x'), 'network not found');
      expect(wifiFailText('id=7c2a9f mode=setup wifi=fail:77 pair=x'), 'reason 77');
      expect(wifiFailText('id=7c2a9f mode=setup wifi=fail pair=x'), 'unknown reason');
    });
    test('NETS json', () {
      final n = WifiNet.parse('[{"s":"Home","r":-47,"l":1},{"s":"Cafe","r":-80,"l":0}]');
      expect(n.length, 2);
      expect(n.first.ssid, 'Home');
      expect(n.first.locked, isTrue);
      expect(n.last.locked, isFalse);
      expect(WifiNet.parse('garbage'), isEmpty);
    });
  });

  group('broker url', () {
    test('wss default', () {
      final t = BrokerTarget.parse('wss://broker.emqx.io:8084/mqtt');
      expect(t.server, 'wss://broker.emqx.io/mqtt');
      expect(t.port, 8084);
      expect(t.websocket, isTrue);
    });
    test('plain mqtt host', () {
      final t = BrokerTarget.parse('mqtt://home.local:1884');
      expect(t.server, 'home.local');
      expect(t.port, 1884);
      expect(t.websocket, isFalse);
      expect(BrokerTarget.parse('home.local').port, 1883);
      expect(BrokerTarget.parse('mqtts://home.local').secure, isTrue);
    });
  });
}
