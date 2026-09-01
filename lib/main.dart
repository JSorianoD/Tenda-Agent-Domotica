import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/ai_history/services/ai_history_service.dart';

/// App entrypoint.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AiHistoryService.init();
  runApp(const ProviderScope(child: JarvisApp()));
}

/// Root widget for the Jarvis Home Assistant app.
class JarvisApp extends ConsumerWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Jarvis Home Assistant',
      debugShowCheckedModeBanner: false,
      theme: buildTendaLightTheme(),
      darkTheme: buildTendaTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
