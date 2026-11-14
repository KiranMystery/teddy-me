import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model/animal.dart';
import 'model/zoo_model.dart';
import 'screens/add_animal_screen.dart';
import 'screens/animal_screen.dart';
import 'screens/join_screen.dart';
import 'screens/links_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/zoo_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(TeddyZooApp(model: ZooModel(prefs)));
}

class TeddyZooApp extends StatefulWidget {
  const TeddyZooApp({super.key, required this.model});
  final ZooModel model;
  @override
  State<TeddyZooApp> createState() => _TeddyZooAppState();
}

class _TeddyZooAppState extends State<TeddyZooApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ZooScreen()),
      GoRoute(path: '/add', builder: (_, _) => const AddAnimalScreen()),
      GoRoute(path: '/animal/:id', builder: (_, s) => AnimalScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/links/:id', builder: (_, s) => LinksScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/join/:code', builder: (_, s) => JoinScreen(code: s.pathParameters['code']!)),
      // deep links: https://iome.uk/zoo/<code>, teddyzoo://zoo/<code>, …/zoo.html?join=<code>
      GoRoute(path: '/zoo/:code', redirect: (_, s) => '/join/${s.pathParameters['code']}'),
      GoRoute(path: '/zoo.html', redirect: (_, s) => _joinRedirect(s)),
      GoRoute(path: '/zoo', redirect: (_, s) => _joinRedirect(s)),
      // teddyzoo://zoo/<code>: iOS and Android hand Flutter only the path, so the host is gone
      GoRoute(path: '/:code', redirect: (_, s) => validCode(s.pathParameters['code']) ? '/join/${s.pathParameters['code']}' : '/'),
    ],
    redirect: (_, s) {
      final j = s.uri.queryParameters['join'];
      if (j != null && validCode(j.trim())) return '/join/${Uri.encodeComponent(j.trim())}';
      return null;
    },
    errorBuilder: (_, _) => const ZooScreen(),
  );

  static String _joinRedirect(GoRouterState s) {
    final j = s.uri.queryParameters['join'];
    return j != null && validCode(j.trim()) ? '/join/${Uri.encodeComponent(j.trim())}' : '/';
  }

  @override
  void initState() {
    super.initState();
    // connect to the saved zoo unless we're opening on a join link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = _router.routeInformationProvider.value.uri.toString();
      if (!loc.contains('join')) widget.model.connect(widget.model.zoo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.model,
      child: Consumer<ZooModel>(
        builder: (context, m, _) {
          final light = buildTheme(Brightness.light);
          final dark = buildTheme(Brightness.dark);
          final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
          final isDark = switch (m.themeMode) { ThemeMode.dark => true, ThemeMode.light => false, _ => platformDark };
          final paper = (isDark ? Brand.dark : Brand.light).paper;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: paper),
            child: MaterialApp.router(
              title: 'Teddy zoo',
              debugShowCheckedModeBanner: false,
              theme: light,
              darkTheme: dark,
              themeMode: m.themeMode,
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
