import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../model/animal.dart';
import '../model/zoo_model.dart';
import '../services/ble_setup.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Add an animal over Bluetooth, four steps (see AddController).
class AddAnimalScreen extends StatefulWidget {
  const AddAnimalScreen({super.key});
  @override
  State<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends State<AddAnimalScreen> {
  late final AddController add = AddController(context.read<ZooModel>());
  final _ssid = TextEditingController();
  final _pass = TextEditingController();
  final _pair = TextEditingController();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  bool _showPass = false;
  int _lastStep = 1;

  @override
  void initState() {
    super.initState();
    add.addListener(_onStep);
  }

  void _onStep() {
    if (add.step != _lastStep) {
      _lastStep = add.step;
      if (add.step == 1) {
        _pass.clear();
        _ssid.clear();
        _pair.clear();
        _showPass = false;
      }
      if (add.step == 4 && _owner.text.isEmpty) _owner.text = context.read<ZooModel>().owner;
    }
  }

  @override
  void dispose() {
    add.removeListener(_onStep);
    add.dispose();
    for (final c in [_ssid, _pass, _pair, _name, _owner]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: add,
      builder: (context, _) {
        final b = Brand.of(context);
        return Screen(
          top: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            BackLink(onTap: () => context.pop()),
            Steps(add.step),
            const SizedBox(width: 44),
          ]),
          bottom: _bottom(b),
          children: switch (add.step) { 1 => _step1(b), 2 => _step2(b), 3 => _step3(b), _ => _step4(b) },
        );
      },
    );
  }

  Widget _title(String eyebrow, Widget h1, Widget lead) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Eyebrow(eyebrow),
        const SizedBox(height: 6),
        h1,
        const SizedBox(height: 6),
        lead,
      ]);

  // ------------------------------------------------------------------ step 1
  List<Widget> _step1(Brand b) {
    final m = context.watch<ZooModel>();
    return [
      _title(
        'Step 1 of 4',
        const H1('Find your animal'),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Switch it on. While it is not set up yet it shows itself over Bluetooth as ', style: body(size: 15, color: b.mute)),
          TextSpan(text: 'Teddy', style: body(size: 15, weight: FontWeight.w600, color: b.mute)),
          TextSpan(text: '.', style: body(size: 15, color: b.mute)),
        ])),
      ),
      if (!add.bleAvailable)
        Card22(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: b.err, width: 4))),
            padding: const EdgeInsets.only(left: 12),
            child: Text('This device can’t do Bluetooth LE. Everything else in the zoo still works; set animals up from another phone.', style: body(size: 14, color: b.ink, height: 1.5)),
          ),
        ),
      StatusRow(add.status, bad: add.statusBad, busy: add.statusBusy, on: add.connected),
      if (!validCode(m.zoo) && m.join == null) const SizedBox.shrink(),
      for (final f in add.found)
        Card22(
          padding: const EdgeInsets.all(12),
          onTap: add.connected ? null : () => add.connectTo(f.device),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: b.line, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.bluetooth_rounded, color: b.mute)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.device.platformName.isNotEmpty ? f.device.platformName : 'Teddy', style: display(size: 17, color: b.ink)),
                  Sub('New · not set up yet · ${barsFor(f.rssi) >= 3 ? 'near' : 'further away'}'),
                ]),
              ),
              Radio22(add.device?.remoteId == f.device.remoteId),
            ]),
          ),
        ),
      if (add.connected && add.id.isNotEmpty)
        Card22(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: b.line, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.bluetooth_rounded, color: b.mute)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Teddy ${add.id}', style: display(size: 17, color: b.ink)),
                Sub(add.fail.isNotEmpty ? 'Could not join WiFi last time: ${add.fail}' : 'New · not set up yet', color: add.fail.isNotEmpty ? b.err : null),
              ]),
            ),
            const Radio22(true),
          ]),
        ),
    ];
  }

  // ------------------------------------------------------------------ step 2
  List<Widget> _step2(Brand b) {
    final m = context.watch<ZooModel>();
    final picked = add.pick != null;
    final other = add.pick == -1;
    final net = !other && picked && add.pick! < add.nets.length ? add.nets[add.pick!] : null;
    if (picked && _pair.text.isEmpty) _pair.text = validCode(m.zoo) ? m.zoo : genCode();
    return [
      _title(
        'Step 2 of 4',
        const H1('Put it on your WiFi'),
        Lead('Teddy ${add.id} looks for networks itself. Pick yours; nothing to type but the password. 2.4 GHz only.'),
      ),
      if (add.scanningNets)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [const ScanningBars(), const SizedBox(height: 12), Text('Scanning for networks…', style: body(size: 14, color: b.mute))]),
        )
      else ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Sub('Strongest first'), TextBtn('Rescan', onPressed: add.scanNets)]),
        Card22(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (final (i, n) in add.nets.indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: b.line),
              InkWell(
                onTap: () => add.setPick(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(children: [
                    Bars(barsFor(n.rssi)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(n.ssid, style: body(color: b.ink, weight: add.pick == i ? FontWeight.w600 : FontWeight.w400))),
                    if (n.locked) ...[Icon(Icons.lock_outline_rounded, size: 18, color: b.mute), const SizedBox(width: 12)],
                    Radio22(add.pick == i),
                  ]),
                ),
              ),
            ],
            if (add.nets.isNotEmpty) Divider(height: 1, thickness: 1, color: b.line),
            InkWell(
              onTap: () => add.setPick(-1),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(children: [
                  SizedBox(width: 24, child: Icon(Icons.notes_rounded, size: 20, color: b.mute)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Other', style: body(color: b.ink, weight: FontWeight.w500)),
                      Sub(add.nets.isNotEmpty ? 'Hidden network · type it in' : 'Nothing found · type it in'),
                    ]),
                  ),
                  Radio22(other),
                ]),
              ),
            ),
          ]),
        ),
        if (picked)
          Card22(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (other) ...[
                Field('Network name', child: TextField(controller: _ssid, autofocus: true, autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none, style: body(color: b.ink), decoration: const InputDecoration(hintText: 'Exactly as the router has it'))),
                const SizedBox(height: 14),
              ],
              if (other || (net?.locked ?? false)) ...[
                Field(
                  'Password for ${other ? 'it' : net!.ssid}',
                  help: add.fail.isNotEmpty ? 'Last time it could not join: ${add.fail}. Tap Show to check what you type.' : null,
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _pass,
                        obscureText: !_showPass,
                        autofocus: !other,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: body(color: b.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(_showPass ? 'Hide' : 'Show', onPressed: () => setState(() => _showPass = !_showPass)),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              Field(
                'Zoo code',
                help: 'Your zoo’s code, already filled in. Animals with the same code see and trigger each other; New starts a separate zoo.',
                child: Row(children: [
                  Expanded(child: TextField(controller: _pair, autocorrect: false, enableSuggestions: false, style: monoStyle(context, size: 16, letterSpacing: 1))),
                  const SizedBox(width: 8),
                  Pill('New', onPressed: () => setState(() => _pair.text = genCode())),
                ]),
              ),
            ]),
          ),
        if (picked)
          Btn('Send to the animal', onPressed: add.sending
              ? null
              : () async {
                  FocusScope.of(context).unfocus();
                  final err = await add.sendSetup(ssidText: _ssid.text, pass: _pass.text, pair: _pair.text.trim());
                  if (err != null && mounted) alert(this.context, err);
                }),
        Btn('Forget WiFi on this animal', kind: BtnKind.quiet, onPressed: () async {
          final err = await add.forgetWifi();
          if (!mounted) return;
          alert(this.context, err ?? 'WiFi forgotten on Teddy ${add.id}.');
        }),
      ],
    ];
  }

  // ------------------------------------------------------------------ step 3
  List<Widget> _step3(Brand b) {
    return [
      _title(
        'Step 3 of 4',
        H1('Joining ${add.ssid}'),
        const Lead('The animal is restarting and joining your WiFi. Bluetooth drops now; that is expected.'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          const Avatar('elephant', size: 96, shadow: true),
          const SizedBox(height: 16),
          Row(mainAxisSize: MainAxisSize.min, children: [const Dot(busy: true), const SizedBox(width: 8), Text('Restarting and joining WiFi…', style: body(size: 14, color: b.mute))]),
          const SizedBox(height: 16),
          const Sub('Its light blinks until it is online, then it buzzes once.'),
        ]),
      ),
      if (add.showHelp)
        const Sub('Not online yet. If its light is still blinking it could not join, usually a wrong password. Connect again over Bluetooth and the animal says why.', align: TextAlign.center),
    ];
  }

  // ------------------------------------------------------------------ step 4
  List<Widget> _step4(Brand b) {
    final m = context.watch<ZooModel>();
    final a = m.animals[add.id];
    final online = a?.online ?? false;
    return [
      _title(
        'Step 4 of 4',
        const H1('Give it a name'),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'It is in your zoo. The id ', style: body(size: 15, color: b.mute)),
          TextSpan(text: add.id, style: monoStyle(context)),
          TextSpan(text: ' stays on the animal; the rest is yours to change.', style: body(size: 15, color: b.mute)),
        ])),
      ),
      Row(children: [
        Avatar(add.species, size: 64),
        const SizedBox(width: 14),
        Expanded(child: StatusRow(online ? 'online · ${add.ssid}' : 'waiting for it to come online', heart: online, busy: !online)),
      ]),
      Card22(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Field('Name', child: TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, style: body(color: b.ink), decoration: const InputDecoration(hintText: 'Ellie'))),
          const SizedBox(height: 14),
          Field('Species', child: Seg<String>(value: add.species, items: const [('elephant', 'Elephant'), ('bear', 'Bear'), ('other', 'Other')], onChanged: add.setSpecies)),
          const SizedBox(height: 14),
          Field('Owner', child: TextField(controller: _owner, textCapitalization: TextCapitalization.words, style: body(color: b.ink), decoration: const InputDecoration(hintText: 'Your name'))),
        ]),
      ),
    ];
  }

  Widget? _bottom(Brand b) {
    switch (add.step) {
      case 1:
        if (!add.bleAvailable) return null;
        return Btn(add.scanningBle ? 'Looking…' : 'Connect over Bluetooth', onPressed: add.scanningBle || add.connected ? null : add.startBleScan);
      case 2:
        return null;
      case 3:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (add.showSkip) Btn('Continue without waiting', kind: BtnKind.secondary, onPressed: add.arrived),
          if (add.showHelp) ...[const SizedBox(height: 8), Btn('Connect again over Bluetooth', kind: BtnKind.quiet, onPressed: add.retryBle)],
        ]);
      default:
        return Btn('Add to my zoo', onPressed: () async {
          final ok = add.finish(name: _name.text.trim(), owner: _owner.text.trim());
          if (!ok && mounted) await alert(this.context, 'Not connected to the zoo yet. Open the animal later and tap Edit to name it.');
          if (!mounted) return;
          context.go('/animal/${Uri.encodeComponent(add.id)}');
        });
    }
  }
}
