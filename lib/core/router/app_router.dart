import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/ha_connection_screen.dart';
import '../../features/auth/services/ha_connection_service.dart';
import '../../features/devices/presentation/devices_screen.dart';
import '../../features/jarvis_core/presentation/home_screen.dart';

// ── Auth notifier ──────────────────────────────────────────────────────────
// GoRouter.redirect no soporta funciones async directamente (retorna Future<String?>
// que no es asignable a String?). En su lugar, usamos un ChangeNotifier que
// lleva el estado loggedIn de forma síncrona y lo actualiza desde async.

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._service) {
    _init();
  }

  final HaConnectionService _service;
  bool _loggedIn = false;
  bool _initialized = false;

  bool get loggedIn => _loggedIn;
  bool get initialized => _initialized;

  Future<void> _init() async {
    _loggedIn = await _service.isLoggedIn();
    _initialized = true;
    notifyListeners();
  }

  /// Llama a este método después de un login exitoso o logout
  /// para forzar la reevaluación de la ruta por GoRouter.
  Future<void> refresh() async {
    _loggedIn = await _service.isLoggedIn();
    notifyListeners();
  }
}

final _authNotifierProvider = Provider<_AuthNotifier>((ref) {
  final service = ref.watch(haConnectionServiceProvider);
  final notifier = _AuthNotifier(service);
  ref.onDispose(notifier.dispose);
  return notifier;
});

// ── Router ─────────────────────────────────────────────────────────────────

/// Application router with global redirect for authentication.
/// Usa [_AuthNotifier] como refreshListenable para que GoRouter
/// reevalúe las rutas cuando el estado de autenticación cambia.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    // GoRouter vuelve a evaluar el redirect cada vez que authNotifier notifica.
    refreshListenable: authNotifier,
    redirect: (context, state) {
      // Mientras se inicializa (lectura async de SecureStorage), no redirigir.
      if (!authNotifier.initialized) return null;

      final loggedIn = authNotifier.loggedIn;
      final isLoginRoute = state.uri.toString() == '/login';

      if (!loggedIn && !isLoginRoute) return '/login';
      if (loggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const HaConnectionScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
    ],
  );
});
