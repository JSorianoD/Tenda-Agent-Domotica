import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// App entrypoint.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: JarvisApp()));
}

/// Root widget for the Jarvis Home Assistant app.
class JarvisApp extends ConsumerWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Jarvis Home Assistant',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode:
          ThemeMode.dark, // Forzado: la marca pierde fuerza sobre fondo claro
      routerConfig: router,
    );
  }
}
