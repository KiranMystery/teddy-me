import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../model/animal.dart';
import '../model/zoo_model.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Landing screen for a scanned QR / https://iome.uk/zoo/<code> link.
/// Previews the zoo over MQTT without saving it until "Join".
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.code});
  final String code;
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = context.read<ZooModel>();
      if (!validCode(widget.code)) {
        context.go('/');
        return;
      }
      m.joinStart(widget.code);
    });
  }

  void _leave(bool keep) {
    context.read<ZooModel>().joinLeave(keep: keep);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ZooModel>();
    final b = Brand.of(context);
    final all = m.ids();
    final owners = all.map((id) => m.animals[id]!.owner.trim()).where((o) => o.isNotEmpty).toSet().toList();
    final one = owners.length == 1 ? owners.first : null;
    final avatars = all.isNotEmpty ? all.take(3).map((id) => m.animals[id]!.species).toList() : ['elephant', 'elephant'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(false);
      },
      child: Screen(
        top: const Center(child: Wordmark()),
        bottom: Column(mainAxisSize: MainAxisSize.min, children: [
          Btn(one != null ? 'Join $one’s zoo' : 'Join this zoo', onPressed: () => _leave(true)),
          const SizedBox(height: 10),
          Btn('Not now', kind: BtnKind.secondary, onPressed: () => _leave(false)),
        ]),
        children: [
          Column(children: [
            SizedBox(
              height: 64,
              child: Stack(alignment: Alignment.center, children: [
                for (final (i, s) in avatars.indexed)
                  Transform.translate(
                    offset: Offset((i - (avatars.length - 1) / 2) * 50, 0),
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(64 * .3 + 4), border: Border.all(color: b.paper, width: 4)),
                      child: Avatar(s, size: 64),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            H1(one != null ? 'Join $one’s zoo?' : 'Join this zoo?', align: TextAlign.center),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: 'You scanned zoo code ', style: body(size: 15, color: b.mute)),
                TextSpan(text: widget.code, style: monoStyle(context)),
                TextSpan(text: '.', style: body(size: 15, color: b.mute)),
              ]),
              textAlign: TextAlign.center,
            ),
          ]),
          Card22(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Animals you’ll see'),
              const SizedBox(height: 10),
              if (all.isEmpty)
                Sub(m.brokerUp ? 'No animals in this zoo yet, or they are all asleep.' : 'Looking…')
              else
                for (final (i, id) in all.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  MiniRow(
                    species: m.animals[id]!.species,
                    title: m.label(id),
                    sub: '${speciesLabel(m.animals[id]!.species)}${m.animals[id]!.owner.isNotEmpty ? ' · ${m.animals[id]!.owner}’s' : ''}',
                    online: m.animals[id]!.online,
                  ),
                ],
            ]),
          ),
          Card22(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(children: [
              _check(b, 'Their animals show in your zoo; yours show in theirs.'),
              const SizedBox(height: 10),
              _check(b, 'Either of you can link paws between them, so a squeeze reaches the other house.'),
              const SizedBox(height: 10),
              _check(b, 'Your animals stay yours. Leave the zoo any time in Settings.'),
            ]),
          ),
          const Sub('Any animal you set up from now on joins this zoo too.', align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _check(Brand b, String t) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.check_rounded, size: 20, color: b.brand)),
        const SizedBox(width: 10),
        Expanded(child: Text(t, style: body(size: 14, color: b.mute))),
      ]);
}
