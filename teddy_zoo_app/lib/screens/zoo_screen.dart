import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../model/animal.dart';
import '../model/zoo_model.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ZooScreen extends StatelessWidget {
  const ZooScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ZooModel>();
    final b = Brand.of(context);
    final all = m.animals.length, on = m.animals.values.where((a) => a.online).length;

    String statusText;
    var busy = false, isOn = false, bad = false;
    if (m.error != null) {
      statusText = m.error!;
      bad = true;
    } else if (!validCode(m.zoo)) {
      statusText = 'no zoo yet: add an animal, or scan a zoo code';
    } else if (!m.brokerUp) {
      busy = true;
      statusText = m.connecting ? 'connecting to your zoo…' : 'not connected';
    } else {
      isOn = true;
      statusText = all > 0 ? '$on of $all online' : 'connected · waiting for animals';
    }

    final owners = m.animals.values.map((a) => a.owner.trim()).where((o) => o.isNotEmpty && !sameName(o, m.owner)).toSet().toList()..sort();
    final chips = [('all', 'All'), ('mine', 'Mine'), ('linked', 'Linked to mine'), ('online', 'Online'), for (final o in owners) ('owner:$o', o)];
    final filter = chips.any((c) => c.$1 == m.filter) ? m.filter : 'all';

    final shown = m.ids().where((id) {
      final a = m.animals[id]!;
      return filter == 'all' ||
          (filter == 'mine' && m.isMine(a)) ||
          (filter == 'linked' && m.linkedToMine(id)) ||
          (filter == 'online' && a.online) ||
          (filter.startsWith('owner:') && sameName(a.owner, filter.substring(6)));
    }).toList();

    final emptyText = all > 0
        ? 'No animals match this filter.'
        : validCode(m.zoo)
            ? 'No animals in zoo ${m.zoo} yet. Add one below, or check the code in Settings.'
            : 'Add your first animal below, or scan a friend’s zoo code to join theirs.';

    return Screen(
      top: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Wordmark(),
        IconButton(
          onPressed: () => context.push('/settings'),
          tooltip: 'Settings',
          icon: Icon(Icons.tune_rounded, color: b.mute),
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
        ),
      ]),
      bottom: Btn('Add an animal', icon: const Icon(Icons.add_rounded), onPressed: () => context.push('/add')),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Expanded(child: H1('My zoo', size: 30)),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'zoo code ', style: body(size: 13, color: b.mute)),
              TextSpan(text: m.zoo.isEmpty ? '–' : m.zoo, style: monoStyle(context, size: 13)),
            ])),
          ),
        ]),
        StatusRow(statusText, on: isOn, busy: busy, bad: bad),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 2),
            clipBehavior: Clip.none,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Chip40(chips[i].$2, selected: chips[i].$1 == filter, onTap: () => m.setFilter(chips[i].$1)),
          ),
        ),
        if (shown.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32), child: Sub(emptyText, align: TextAlign.center))
        else
          for (final (i, id) in shown.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            _AnimalCard(id: id, animal: m.animals[id]!),
          ],
        const SizedBox(height: 56),
      ],
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.id, required this.animal});
  final String id;
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final m = context.read<ZooModel>();
    final b = Brand.of(context);
    final a = animal;
    final mine = m.isMine(a), linked = !mine && m.linkedToMine(id);
    final ownerLine = mine
        ? 'Yours · paw triggers ${a.links.isNotEmpty ? a.links.map((x) => m.animals[x] != null ? m.label(x) : x).join(', ') : 'nothing yet'}'
        : (a.owner.isNotEmpty ? 'Owned by ${a.owner}' : 'No owner yet');
    return Card22(
      opacity: a.online ? 1 : .7,
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/animal/${Uri.encodeComponent(id)}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(children: [
          Avatar(a.species, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(m.label(id), overflow: TextOverflow.ellipsis, style: display(size: 17, color: b.ink, height: 1.2))),
                if (mine) ...[const SizedBox(width: 8), const Tag('mine')],
                if (linked) ...[const SizedBox(width: 8), const Tag('linked', mine: false)],
              ]),
              const SizedBox(height: 2),
              Text.rich(TextSpan(children: [
                TextSpan(text: '${speciesLabel(a.species)} · ', style: body(size: 13, color: b.mute)),
                TextSpan(text: id, style: mono(size: 13, color: b.mute)),
              ])),
              Sub(ownerLine),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Dot(on: a.online),
              const SizedBox(height: 4),
              Text(a.online ? 'online' : 'offline', style: body(size: 11, color: b.mute)),
            ]),
          ),
        ]),
      ),
    );
  }
}
