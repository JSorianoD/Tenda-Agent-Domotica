import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/state/ha_credentials_provider.dart';
import '../../home_assistant/domain/ha_entity.dart';
import '../../home_assistant/state/ha_states_controller.dart';

/// Full-screen view for Security entities (Cameras, Alarms, Sensors).
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haStatesAsync = ref.watch(haStatesProvider);
    final credentialsAsync = ref.watch(haCredentialsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'SEGURIDAD',
          style: GoogleFonts.rajdhani(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
        ),
      ),
      body: haStatesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.tendaGold),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (haData) {
          final securityEntities = haData.securityEntities;

          if (securityEntities.isEmpty) {
            return const Center(
              child: Text(
                'No se encontraron dispositivos de seguridad.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return credentialsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.tendaGold),
            ),
            error: (err, _) => const Center(
              child: Text(
                'Error obteniendo credenciales',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            data: (credentials) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                itemCount: securityEntities.length,
                itemBuilder: (context, index) {
                  final entity = securityEntities[index];
                  if (entity.domain == 'camera') {
                    return _buildCameraCard(
                      context,
                      entity,
                      credentials?.url,
                      credentials?.token,
                    );
                  }
                  return _buildSensorTile(entity);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCameraCard(
    BuildContext context,
    HaEntity camera,
    String? baseUrl,
    String? token,
  ) {
    final entityPicture = camera.attributes['entity_picture'] as String?;
    final hasImage = entityPicture != null && baseUrl != null && token != null;
    final imageUrl = hasImage ? '$baseUrl$entityPicture' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  color: AppColors.tendaGold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  camera.friendlyName.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error, // Simulating recording/live dot
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          // Camera Feed (Proxy image)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: hasImage
                  ? Image.network(
                      imageUrl,
                      headers: {'Authorization': 'Bearer $token'},
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildCameraFallback();
                      },
                    )
                  : _buildCameraFallback(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraFallback() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.videocam_off_outlined,
          color: AppColors.textMuted,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          'Señal no disponible',
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSensorTile(HaEntity sensor) {
    final isAlarm = sensor.domain == 'alarm_control_panel';
    final state = sensor.state;
    final isActive =
        state == 'on' || state == 'armed_away' || state == 'armed_home';

    IconData getIcon() {
      if (isAlarm) return isActive ? Icons.shield : Icons.shield_outlined;
      final dc = sensor.attributes['device_class'];
      if (dc == 'door') {
        return isActive ? Icons.meeting_room : Icons.door_front_door;
      }
      if (dc == 'window') return Icons.window;
      if (dc == 'motion') return Icons.directions_run;
      return Icons.sensors;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.tendaGold.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            getIcon(),
            color: isActive ? AppColors.tendaGold : AppColors.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              sensor.friendlyName,
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            state.toUpperCase(),
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isActive ? AppColors.tendaGold : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
