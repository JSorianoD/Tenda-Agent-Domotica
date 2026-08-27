import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../home_assistant/domain/ha_entity.dart';
import '../../home_assistant/state/ha_states_controller.dart';

/// Full-screen view for Weather and environmental sensors.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  String _translateState(String state) {
    final Map<String, String> translations = {
      'sunny': 'Soleado',
      'clear': 'Despejado',
      'clear-night': 'Despejado',
      'cloudy': 'Nublado',
      'partlycloudy': 'Parcialmente Nublado',
      'rainy': 'Lluvioso',
      'pouring': 'Lluvia Fuerte',
      'windy': 'Ventoso',
      'fog': 'Niebla',
    };
    return translations[state] ?? state;
  }

  IconData _getWeatherIcon(String state) {
    switch (state) {
      case 'sunny':
      case 'clear':
        return Icons.wb_sunny;
      case 'clear-night':
        return Icons.nights_stay;
      case 'cloudy':
        return Icons.cloud;
      case 'partlycloudy':
        return Icons.wb_cloudy;
      case 'rainy':
      case 'pouring':
        return Icons.water_drop;
      default:
        return Icons.thermostat;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haStatesAsync = ref.watch(haStatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'CLIMA',
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
          final weatherEntities = haData.weatherEntities;
          final mainWeather = weatherEntities
              .where((e) => e.domain == 'weather')
              .firstOrNull;
          final sensors = weatherEntities
              .where((e) => e.domain != 'weather')
              .toList();

          return CustomScrollView(
            slivers: [
              if (mainWeather != null)
                SliverToBoxAdapter(child: _buildHeroCard(context, mainWeather)),
              if (sensors.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      top: 32,
                      bottom: 16,
                    ),
                    child: Text(
                      'SENSORES DE AMBIENTE',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildSensorTile(sensors[index]),
                    childCount: sensors.length,
                  ),
                ),
              ] else if (mainWeather == null)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No se encontró información del clima.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, HaEntity weather) {
    final temp = weather.attributes['temperature']?.toString() ?? '--';
    final tempUnit = weather.attributes['temperature_unit']?.toString() ?? '°C';
    final humidity = weather.attributes['humidity']?.toString() ?? '--';
    final stateTrans = _translateState(weather.state);

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.tendaGold.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _getWeatherIcon(weather.state),
            size: 80,
            color: AppColors.tendaGold,
          ),
          const SizedBox(height: 24),
          Text(
            stateTrans.toUpperCase(),
            style: GoogleFonts.rajdhani(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$temp$tempUnit',
            style: GoogleFonts.rajdhani(
              fontSize: 72,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.water_drop_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Humedad: $humidity%',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorTile(HaEntity sensor) {
    final val = sensor.state;
    final unit = sensor.attributes['unit_of_measurement'] ?? '';
    final isTemp = sensor.attributes['device_class'] == 'temperature';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isTemp ? Icons.device_thermostat : Icons.water_drop,
              color: AppColors.textSecondary,
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
              '$val $unit',
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.tendaGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
