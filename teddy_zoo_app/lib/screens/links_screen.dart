import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../model/animal.dart';
import '../model/zoo_model.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// "Paw triggers" editor: tick the animals this paw reaches; Save publishes
/// the retained `links/<id>` topic.
class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key, required this.id});
  final String id;
  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  late final Set<String> _draft = {...context.read<ZooModel>().animal(widget.id).links};

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ZooModel>();
    final b = Brand.of(context);
    final a = m.animal(widget.id);
    final others = m.ids().where((x) => x != widget.id).toList();
    final n = _draft.length, total = (m.animals.length - 1).clamp(0, 1 << 30);

    return Screen(
      top: Align(alignment: Alignment.centerLeft, child: BackLink(label: m.label(widget.id), onTap: () => context.pop())),
      bottom: Btn('Save $n ${n == 1 ? 'link' : 'links'}', onPressed: () async {
        if (!m.publishLinks(widget.id, _draft.toList())) {
          await alert(context, 'Not connected to the zoo yet; try again in a moment.');
          return;
        }
        if (context.mounted) context.pop();
      }),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H1(a.name.isNotEmpty ? '${a.name}’s paw triggers' : 'This paw triggers'),
          const SizedBox(height: 6),
          const Lead('Tick the animals that should buzz when someone squeezes this paw. Links go one way; their owners choose what their own paws do.'),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Sub('$n of $total animals in your zoo'),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'zoo ', style: body(size: 13, color: b.mute)),
            TextSpan(text: m.zoo, style: monoStyle(context, size: 13)),
          ])),
        ]),
        if (others.isEmpty)
          const Card22(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32), child: Center(child: Sub('No other animals in this zoo yet.')))
        else
          RowsCard(children: [
            for (final x in others) _check(m, x, m.animals[x]!),
          ]),
        const Sub('Offline animals keep their link and catch up when they come back.'),
      ],
    );
  }

  Widget _check(ZooModel m, String x, Animal t) {
    final b = Brand.of(context);
    final on = _draft.contains(x);
    final ownerBit = t.owner.isNotEmpty ? ' · ${m.isMine(t) ? 'yours' : '${t.owner}’s'}' : '';
    return InkWell(
      onTap: () => setState(() => on ? _draft.remove(x) : _draft.add(x)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        child: Row(children: [
          Avatar(t.species, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.label(x), style: display(size: 16, color: b.ink)),
              Sub('${speciesLabel(t.species)}$ownerBit${t.online ? '' : ' · offline'}'),
            ]),
          ),
          Transform.scale(scale: 1.3, child: Checkbox(value: on, onChanged: (v) => setState(() => v == true ? _draft.add(x) : _draft.remove(x)))),
        ]),
      ),
    );
  }
}
