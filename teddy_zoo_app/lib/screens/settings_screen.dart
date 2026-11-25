import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/animal.dart';
import '../model/zoo_model.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _owner = TextEditingController(text: context.read<ZooModel>().owner);
  late final TextEditingController _broker = TextEditingController(text: context.read<ZooModel>().broker);
  final _pair = TextEditingController();
  String _copyLabel = 'Copy code';

  @override
  void dispose() {
    _owner.dispose();
    _broker.dispose();
    _pair.dispose();
    super.dispose();
  }

  void _switchZoo() {
    final c = _pair.text.trim();
    if (!validCode(c)) {
      alert(context, 'A zoo code is 4 to 32 letters or digits.');
      return;
    }
    final m = context.read<ZooModel>();
    m.saveZoo(c);
    m.connect(c);
    _pair.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<ZooModel>();
    final b = Brand.of(context);
    final all = m.animals.length, mine = m.animals.values.where(m.isMine).length;
    final hasZoo = validCode(m.zoo);
    final url = shareUrl(m.zoo);

    final inputStyle = body(size: 16, color: b.ink);
    final smallInput = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: b.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: b.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: b.brand, width: 2)),
    );

    return Screen(
      top: Align(alignment: Alignment.centerLeft, child: BackLink(label: 'Zoo', onTap: () => context.pop())),
      children: [
        const H1('Settings'),
        const Eyebrow('You'),
        RowsCard(children: [
          KvRow('My name',
              minHeight: 56,
              valueWidget: SizedBox(
                width: 170,
                child: TextField(
                  controller: _owner,
                  textAlign: TextAlign.right,
                  style: inputStyle,
                  textCapitalization: TextCapitalization.words,
                  decoration: smallInput.copyWith(hintText: 'e.g. Kiran'),
                  onChanged: m.setOwner,
                ),
              )),
          KvRow('Theme',
              minHeight: 56,
              valueWidget: Seg<ThemeMode>(
                small: true,
                value: m.themeMode,
                items: const [(ThemeMode.system, 'Auto'), (ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark')],
                onChanged: m.setTheme,
              )),
        ]),
        const Eyebrow('Your zoo'),
        Card22(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(children: [
                _QrBox(size: 96, data: hasZoo ? url : null),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Zoo code', style: body(size: 15, color: b.mute)),
                    Text(hasZoo ? m.zoo : '–', style: monoStyle(context, size: 22, letterSpacing: 1.8)),
                    const SizedBox(height: 2),
                    const Sub('Point a phone camera at the code: the app opens and joins your zoo.'),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Row(children: [
                Expanded(
                  child: Pill(_copyLabel, expand: true, onPressed: hasZoo
                      ? () async {
                          await Clipboard.setData(ClipboardData(text: m.zoo));
                          setState(() => _copyLabel = 'Copied');
                          Future.delayed(const Duration(milliseconds: 1500), () {
                            if (mounted) setState(() => _copyLabel = 'Copy code');
                          });
                        }
                      : null),
                ),
                const SizedBox(width: 8),
                Expanded(child: Pill('Share zoo', primary: true, expand: true, onPressed: hasZoo ? () => _share(context, m.zoo) : null)),
              ]),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 12), child: Sub('Anyone with this code joins your zoo and can see and trigger your animals. Share it with family, not the world.')),
            Divider(height: 1, thickness: 1, color: b.line),
            KvRow('Animals', minHeight: 56, v: all > 0 ? '$all · $mine yours' : '–'),
            Divider(height: 1, thickness: 1, color: b.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Switch to another zoo', style: body(size: 15, color: b.mute)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _pair,
                      style: monoStyle(context, size: 16, letterSpacing: 1),
                      autocorrect: false,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _switchZoo(),
                      decoration: smallInput.copyWith(hintText: 'zoo code', hintStyle: body(size: 16, color: b.mute)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pill('Switch', onPressed: _switchZoo),
                ]),
              ]),
            ),
          ]),
        ),
        const Eyebrow('Advanced'),
        Card22(
          padding: const EdgeInsets.all(16),
          child: Field(
            'Broker',
            help: 'Where the animals and this app meet. Leave it unless you run your own.',
            child: Focus(
              onFocusChange: (has) {
                if (!has && _broker.text.trim() != m.broker) {
                  m.setBroker(_broker.text);
                  _broker.text = m.broker;
                }
              },
              child: TextField(
                controller: _broker,
                style: monoStyle(context, size: 13),
                autocorrect: false,
                keyboardType: TextInputType.url,
                onSubmitted: (v) {
                  m.setBroker(v);
                  _broker.text = m.broker;
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(children: [
            const Wordmark(height: 18),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Teddy zoo · an IoME thing · ', style: body(size: 13, color: b.mute)),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => launchUrl(Uri.parse('https://github.com/KiranMystery/teddy-me'), mode: LaunchMode.externalApplication),
                  child: Text('source', style: body(size: 13, color: b.accent).copyWith(decoration: TextDecoration.underline, decorationColor: b.accent)),
                ),
              ),
            ])),
            const SizedBox(height: 8),
            Btn('Leave this zoo', kind: BtnKind.danger, expand: false, onPressed: hasZoo
                ? () async {
                    final ok = await confirm(context, 'Leave zoo ${m.zoo}? Your animals keep working; this phone just stops showing them until you join a zoo again.', ok: 'Leave');
                    if (!ok || !context.mounted) return;
                    m.leaveZoo();
                    context.go('/');
                  }
                : null),
          ]),
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context, String code) {
    final url = shareUrl(code);
    return showSheet(context, builder: (ctx) => _ShareSheet(code: code, url: url));
  }
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.code, required this.url});
  final String code, url;
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  String _copy = 'Copy link';
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Align(alignment: Alignment.centerLeft, child: H2('Share your zoo', size: 20)),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(Brand.rCard), boxShadow: [BoxShadow(color: b.line, spreadRadius: 1.5), ...b.shadow]),
        child: _QrBox(size: 248, data: widget.url, radius: Brand.rCard),
      ),
      const SizedBox(height: 14),
      Text(widget.code, style: monoStyle(context, size: 24, letterSpacing: 2.4)),
      Sub(widget.url.replaceFirst(RegExp(r'^https?://'), '')),
      const SizedBox(height: 14),
      const SizedBox(width: 300, child: Sub('They point their camera at this, the app opens on a Join screen, one tap adds your zoo. No app yet? The same link opens the web version.', align: TextAlign.center)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: Btn(_copy, kind: BtnKind.secondary, onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.url));
            setState(() => _copy = 'Copied');
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) setState(() => _copy = 'Copy link');
            });
          }),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Btn('Send link', onPressed: () {
            final box = context.findRenderObject() as RenderBox?;
            SharePlus.instance.share(ShareParams(
              title: 'Join my zoo',
              text: 'Join my Teddy zoo (code ${widget.code})',
              uri: Uri.parse(widget.url),
              sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
            ));
          }),
        ),
      ]),
      const SizedBox(height: 10),
      Btn('Done', kind: BtnKind.quiet, onPressed: () => Navigator.pop(context)),
    ]);
  }
}

/// White QR tile (always white so cameras read it in dark mode too).
class _QrBox extends StatelessWidget {
  const _QrBox({required this.size, required this.data, this.radius = Brand.rCtl});
  final double size;
  final String? data;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius), border: Border.all(color: b.line, width: 1.5)),
      child: data == null
          ? Center(child: Text('no zoo yet', textAlign: TextAlign.center, style: body(size: 13, color: b.mute)))
          : QrImageView(
              data: data!,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1C1714)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1C1714)),
            ),
    );
  }
}
