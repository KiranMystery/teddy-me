import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../model/animal.dart';
import '../model/zoo_model.dart';
import '../theme.dart';
import '../widgets/paw.dart';
import '../widgets/ui.dart';

class AnimalScreen extends StatefulWidget {
  const AnimalScreen({super.key, required this.id});
  final String id;
  @override
  State<AnimalScreen> createState() => _AnimalScreenState();
}

class _AnimalScreenState extends State<AnimalScreen> with WidgetsBindingObserver {
  Timer? _hold;

  bool get holding => _hold != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _pawUp(silent: true);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Phone locked, app switched, call came in: stop at once (the animal also
  /// stops by itself 1.2 s after the last motor:1).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pawUp();
  }

  // hold to buzz: re-send motor:1 every 400 ms, motor:0 on release
  void _pawDown() {
    final m = context.read<ZooModel>();
    final a = m.animal(widget.id);
    if (holding || !(m.brokerUp && a.online)) return;
    HapticFeedback.lightImpact();
    m.send(widget.id, {'motor': 1});
    _hold = Timer.periodic(const Duration(milliseconds: 400), (_) => m.send(widget.id, {'motor': 1}));
    setState(() {});
  }

  void _pawUp({bool silent = false}) {
    if (_hold == null) return;
    _hold!.cancel();
    _hold = null;
    context.read<ZooModel>().send(widget.id, {'motor': 0});
    if (!silent && mounted) setState(() {});
  }

  Future<void> _openEdit() async {
    final m = context.read<ZooModel>();
    final r = await showSheet<(String, String, String)>(context, builder: (ctx) => _EditSheet(id: widget.id, animal: m.animal(widget.id), title: 'Edit ${m.label(widget.id)}'));
    if (r == null || !mounted) return;
    final a = m.animal(widget.id);
    a.name = r.$1;
    a.species = r.$2;
    a.owner = r.$3;
    if (!m.publishMeta(widget.id)) await alert(context, 'Not connected to the zoo yet; try again in a moment.');
  }

  Future<void> _mine() async {
    final m = context.read<ZooModel>();
    if (m.owner.isEmpty) {
      final n = await promptText(context, 'Your name, so the zoo knows which animals are yours:', hint: 'e.g. Kiran');
      if (n == null || n.trim().isEmpty) return;
      m.setOwner(n);
    }
    m.animal(widget.id).owner = m.owner;
    m.publishMeta(widget.id);
  }

  Future<void> _toSetup() async {
    final m = context.read<ZooModel>();
    final ok = await confirm(context, 'Send ${m.label(widget.id)} back to Bluetooth setup? It forgets its WiFi and leaves the zoo until you set it up again.', ok: 'Send');
    if (ok) m.sendToSetup(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ZooModel>();
    final b = Brand.of(context);
    final id = widget.id;
    final a = m.animal(id);
    final mine = m.isMine(a), linked = m.linkedToMine(id), live = m.brokerUp && a.online;
    final name = m.label(id);
    final led = a.led.clamp(0, 2);
    final hint = holding
        ? '$name is buzzing · let go to stop'
        : live
            ? '$name buzzes for as long as you hold'
            : a.online
                ? 'connecting…'
                : 'offline: it will buzz again when it is back on WiFi';
    final targets = a.links.where((x) => x != id).toList();

    return Screen(
      top: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        BackLink(label: 'Zoo', onTap: () => context.pop()),
        TextBtn('Edit', onPressed: _openEdit),
      ]),
      children: [
        // hero
        Row(children: [
          Avatar(a.species, size: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: display(size: 26, color: b.ink, height: 1.15))),
                if (mine || linked) ...[const SizedBox(width: 8), Tag(mine ? 'mine' : 'linked', mine: mine)],
              ]),
              const SizedBox(height: 2),
              Text.rich(TextSpan(children: [
                TextSpan(text: '${speciesLabel(a.species)} · ', style: body(size: 13, color: b.mute)),
                TextSpan(text: id, style: mono(size: 13, color: b.mute)),
                TextSpan(text: ' · ${a.owner.isNotEmpty ? '${a.owner}${mine ? ' (you)' : ''}' : 'no owner yet'}', style: body(size: 13, color: b.mute)),
              ])),
              const SizedBox(height: 2),
              StatusRow(a.online ? 'online · on WiFi' : 'offline', heart: a.online),
            ]),
          ),
        ]),
        // paw
        Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: PawButton(on: holding, enabled: live, onDown: _pawDown, onUp: _pawUp),
          ),
          const SizedBox(height: 6),
          Sub(hint, align: TextAlign.center),
        ]),
        // light
        Card22(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.lightbulb_outline_rounded, size: 28, color: led != 0 ? b.brand : b.mute),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const H2('Light'), Sub(ledNames[led])]),
            ]),
            const SizedBox(height: 12),
            Seg<int>(
              value: led,
              enabled: live,
              items: const [(0, 'Off'), (1, 'Pulse'), (2, 'Steady')],
              onChanged: (v) => m.send(id, {'led': v}),
            ),
          ]),
        ),
        // paw triggers
        Card22(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const H2('Paw triggers'),
                  Sub('Squeeze ${a.name.isNotEmpty ? '${a.name}’s' : 'its'} paw and these buzz. Its own light goes steady while held.'),
                ]),
              ),
              TextBtn('Edit', onPressed: () => context.push('/links/${Uri.encodeComponent(id)}')),
            ]),
            const SizedBox(height: 10),
            if (targets.isEmpty)
              const Sub('Nothing yet. Tap Edit to choose which animals this paw reaches.')
            else
              for (final (i, x) in targets.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                Builder(builder: (_) {
                  final t = m.animals[x];
                  final back = t != null && t.links.contains(id);
                  final sub = t != null ? '${speciesLabel(t.species)}${t.owner.isNotEmpty ? ' · ${t.owner}’s' : ''}' : 'not seen yet';
                  return MiniRow(species: t?.species, title: t != null ? m.label(x) : 'Animal $x', sub: '$sub${back ? ' · also triggers this one' : ''}', online: t?.online ?? false);
                }),
              ],
          ]),
        ),
        // details
        RowsCard(children: [
          KvRow('Name', v: a.name.isNotEmpty ? a.name : '–', chevron: true, onTap: _openEdit),
          KvRow('Species', v: speciesLabel(a.species), chevron: true, onTap: _openEdit),
          KvRow('Owner', v: a.owner.isNotEmpty ? a.owner : '–', chevron: true, onTap: _openEdit),
          KvRow('Id', v: id, mono: true),
        ]),
        if (!mine) Btn("It's mine", kind: BtnKind.secondary, onPressed: _mine),
        Btn('Send back to Bluetooth setup…', kind: BtnKind.danger, onPressed: live ? _toSetup : null),
      ],
    );
  }
}

/// Edit name / species / owner. Returns (name, species, owner) on Save.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.id, required this.animal, required this.title});
  final String id;
  final Animal animal;
  final String title;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.animal.name);
  late final _owner = TextEditingController(text: widget.animal.owner);
  late String _species = () {
    final s = widget.animal.species.toLowerCase();
    return speciesLabels.containsKey(s) ? s : (s.isNotEmpty ? 'other' : 'elephant');
  }();

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      H2(widget.title, size: 20),
      const SizedBox(height: 14),
      Field('Name', child: TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, style: body(color: b.ink))),
      const SizedBox(height: 14),
      Field('Species', child: Seg<String>(value: _species, items: const [('elephant', 'Elephant'), ('bear', 'Bear'), ('other', 'Other')], onChanged: (v) => setState(() => _species = v))),
      const SizedBox(height: 14),
      Field('Owner', child: TextField(controller: _owner, textCapitalization: TextCapitalization.words, style: body(color: b.ink), decoration: const InputDecoration(hintText: 'who it belongs to'))),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Btn('Cancel', kind: BtnKind.secondary, onPressed: () => Navigator.pop(context))),
        const SizedBox(width: 10),
        Expanded(
          child: Btn('Save', onPressed: () {
            final cur = widget.animal.species.toLowerCase();
            // "Other" keeps a custom species string already on the animal
            final species = _species == 'other' ? (speciesLabels.containsKey(cur) ? 'other' : (cur.isNotEmpty ? widget.animal.species : 'other')) : _species;
            Navigator.pop(context, (_name.text.trim(), species, _owner.text.trim()));
          }),
        ),
      ]),
    ]);
  }
}
