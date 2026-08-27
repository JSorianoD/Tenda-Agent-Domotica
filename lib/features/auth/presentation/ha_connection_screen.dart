import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../services/ha_connection_service.dart';

/// Pantalla para conectar la aplicación con Home Assistant mediante
/// URL de la instancia y un Long-Lived Access Token.
class HaConnectionScreen extends ConsumerStatefulWidget {
  const HaConnectionScreen({super.key});

  @override
  ConsumerState<HaConnectionScreen> createState() => _HaConnectionScreenState();
}

class _HaConnectionScreenState extends ConsumerState<HaConnectionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _tokenVisible = false;
  bool _isLoading = false;

  // Entrance fade
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _loadExistingCredentials();
  }

  Future<void> _loadExistingCredentials() async {
    final authService = ref.read(haConnectionServiceProvider);
    final creds = await authService.getCredentials();
    if (creds != null) {
      _urlController.text = creds.url;
      _tokenController.text = creds.token;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(haConnectionServiceProvider);
      await authService.login(
        _urlController.text.trim(),
        _tokenController.text.trim(),
      );

      if (mounted) {
        // Redirigir al home tras la conexión exitosa
        context.go('/');
      }
    } on ConnectionException catch (e) {
      _showError(e.message);
    } on InvalidCredentialsException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Ocurrió un error inesperado');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTendaTheme(),
      child: Scaffold(
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 64,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),
                          _buildLogo(constraints.maxWidth),
                          const Spacer(flex: 1),

                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildUrlField(),
                                const SizedBox(height: 28),
                                _buildTokenField(),
                                const SizedBox(height: 40),
                                _buildSubmitButton(),
                              ],
                            ),
                          ),

                          const Spacer(flex: 3),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Sub-builders ────────────────────────────────────────────────────────

  Widget _buildLogo(double screenWidth) {
    final logoWidth = screenWidth.clamp(200.0, 440.0) * 0.48;

    return Column(
      children: [
        Image.asset(
          'assets/images/tenda_logo_full.png',
          width: logoWidth,
          fit: BoxFit.contain,
        ),
        SizedBox(height: logoWidth * 0.18),
        Text(
          'Configuración Home Assistant',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.tendaGold,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildUrlField() {
    return TextFormField(
      controller: _urlController,
      keyboardType: TextInputType.url,
      style: GoogleFonts.rajdhani(
        color: AppColors.tendaWhite,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: const InputDecoration(
        labelText: 'URL de Home Assistant',
        hintText: 'http://homeassistant.local:8123',
      ),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Ingresa la URL de la instancia';
        if (!v.startsWith('http')) return 'Debe empezar con http:// o https://';
        return null;
      },
    );
  }

  Widget _buildTokenField() {
    return TextFormField(
      controller: _tokenController,
      obscureText: !_tokenVisible,
      style: GoogleFonts.rajdhani(
        color: AppColors.tendaWhite,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: 'Token de acceso (Long-Lived)',
        suffixIcon: IconButton(
          icon: Icon(
            _tokenVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.tendaWhite,
            size: 18,
          ),
          onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
        ),
      ),
      validator: (value) {
        if ((value ?? '').trim().isEmpty) return 'Ingresa el token de acceso';
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.tendaDeepBlack,
                  strokeWidth: 2,
                ),
              )
            : const Text('PROBAR CONEXIÓN'),
      ),
    );
  }
}
