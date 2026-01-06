import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "SETTINGS",
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Settings Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Temperature Unit",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Temperature Unit Options
                        _buildUnitOption(
                          context,
                          settingsService,
                          TemperatureUnit.fahrenheit,
                          "Fahrenheit (°F)",
                          "120°F to 145°F",
                        ),
                        const SizedBox(height: 12),
                        _buildUnitOption(
                          context,
                          settingsService,
                          TemperatureUnit.celsius,
                          "Celsius (°C)",
                          "49°C to 63°C",
                        ),

                        const SizedBox(height: 32),
                        const Text(
                          "Interface",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSwitchOption(
                          context,
                          "Show Steep Timer",
                          "Display a timer at the bottom of the home screen",
                          settingsService.showSteepTimer,
                          (val) {
                            HapticFeedback.mediumImpact();
                            settingsService.setShowSteepTimer(val);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchOption(
                          context,
                          "Green Light Notification",
                          "Pulse the mug's LED green for 60s when the drink reaches the target temperature",
                          settingsService.enableGreenLoop,
                          (val) {
                            HapticFeedback.mediumImpact();
                            settingsService.setEnableGreenLoop(val);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSwitchOption(
                          context,
                          "Liquid Visualization",
                          "Show animated liquid waves in the background",
                          settingsService.showLiquidAnimation,
                          (val) {
                            HapticFeedback.mediumImpact();
                            settingsService.setShowLiquidAnimation(val);
                          },
                        ),

                        const SizedBox(height: 12),
                        _buildSliderOption(
                          context,
                          "Preset Chips",
                          "Number of preset chips to display on home screen",
                          settingsService.presetCount,
                          1,
                          4,
                          (val) {
                            settingsService.setPresetCount(val);
                          },
                          onReset: () {
                            _showResetPresetsDialog(context, settingsService);
                          },
                        ),

                        if (kDebugMode) ...[
                          const SizedBox(height: 32),
                          const Text(
                            "Developer",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSwitchOption(
                            context,
                            "Show Debug Controls",
                            "Display mock controls on home screen",
                            settingsService.showDebugControls,
                            (val) {
                              HapticFeedback.mediumImpact();
                              settingsService.setShowDebugControls(val);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderOption(
    BuildContext context,
    String title,
    String subtitle,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    VoidCallback? onReset,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.emberOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.emberOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  "$value",
                  style: const TextStyle(
                    color: AppTheme.emberOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.emberOrange,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: AppTheme.emberOrange.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (val) {
                if (val.toInt() != value) {
                  HapticFeedback.selectionClick();
                  onChanged(val.toInt());
                }
              },
            ),
          ),
          if (onReset != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(
                  Icons.restore_rounded,
                  size: 16,
                  color: AppTheme.emberOrange,
                ),
                label: const Text(
                  "Reset to Defaults",
                  style: TextStyle(
                    color: AppTheme.emberOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchOption(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return AppTheme.emberOrange;
              }
              return null;
            }),
            activeTrackColor: AppTheme.emberOrange.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption(
    BuildContext context,
    SettingsService service,
    TemperatureUnit unit,
    String title,
    String subtitle,
  ) {
    final isSelected = service.temperatureUnit == unit;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        service.setTemperatureUnit(unit);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.emberOrange.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.emberOrange
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.emberOrange : Colors.white38,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.white60 : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPresetsDialog(BuildContext context, SettingsService service) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        title: const Text(
          "Reset Presets?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This will restore all temperature presets to their original names, icons, and values. This cannot be undone.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              service.resetPresets();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Presets reset to defaults'),
                  duration: Duration(seconds: 2),
                  backgroundColor: AppTheme.emberOrange,
                ),
              );
            },
            child: const Text(
              "Reset",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
