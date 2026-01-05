import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/notification_service.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';
import 'glass_card.dart';

class SteepTimer extends StatefulWidget {
  const SteepTimer({super.key});

  @override
  State<SteepTimer> createState() => _SteepTimerState();
}

class _SteepTimerState extends State<SteepTimer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isFinished = false;
  late AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsService>(context, listen: false);

      // Check for ongoing timer
      if (settings.steepTimerTargetTime != null) {
        final now = DateTime.now();
        final diff = settings.steepTimerTargetTime!.difference(now).inSeconds;

        if (diff > 0) {
          setState(() {
            _remainingSeconds = diff;
            _isRunning = true;
            // Restart local ticker
            _startTicker();
          });
        } else {
          // Timer finished while invalid/background
          setState(() {
            _remainingSeconds = 0;
            _isRunning = false;
            _isFinished = true;
          });
          _flashController.repeat(reverse: true);
          // Clear the target so we don't get stuck
          settings.setSteepTimerTargetTime(null);
        }
      } else {
        setState(() {
          _remainingSeconds = settings.steepTimerDuration;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkTimerState();
    }
  }

  void _checkTimerState() {
    final settings = Provider.of<SettingsService>(context, listen: false);
    if (settings.steepTimerTargetTime != null) {
      final now = DateTime.now();
      final diff = settings.steepTimerTargetTime!.difference(now).inSeconds;

      if (diff > 0) {
        setState(() {
          _remainingSeconds = diff;
          _isRunning = true;
        });
        // Ensure ticker is running
        if (_timer == null || !_timer!.isActive) {
          _startTicker();
        }
      } else {
        _timer?.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
          _isFinished = true;
        });
        _flashController.repeat(reverse: true);
        settings.setSteepTimerTargetTime(null);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    HapticFeedback.mediumImpact();
    final settings = Provider.of<SettingsService>(context, listen: false);

    if (_isRunning) {
      _timer?.cancel();
      settings.setSteepTimerTargetTime(null);
      NotificationService().cancelTimerNotification();
      setState(() {
        _isRunning = false;
      });
    } else {
      if (_remainingSeconds <= 0) {
        _flashController.stop();
        _flashController.reset();
        setState(() {
          _isFinished = false;
          _remainingSeconds = settings.steepTimerDuration;
        });
      }

      setState(() {
        _isRunning = true;
      });

      // Set target time
      final duration = Duration(seconds: _remainingSeconds);
      final targetTime = DateTime.now().add(duration);
      settings.setSteepTimerTargetTime(targetTime);
      NotificationService().scheduleTimerFinishedNotification(duration);

      _startTicker();
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _handleTimerFinished();
      }
    });
  }

  void _handleTimerFinished() {
    final settings = Provider.of<SettingsService>(context, listen: false);
    setState(() {
      _isRunning = false;
      _isFinished = true;
    });
    HapticFeedback.heavyImpact();
    // Notification is handled by schedule, or if app is open we can show another one or just rely on the schedule?
    // The scheduled one shows regardless.
    // We should clear the target time though.
    settings.setSteepTimerTargetTime(null);
    _flashController.repeat(reverse: true);
  }

  void _stopTimer() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    NotificationService().cancelTimerNotification();
    _flashController.stop();
    _flashController.reset();
    final settings = Provider.of<SettingsService>(context, listen: false);
    settings.setSteepTimerTargetTime(null);
    setState(() {
      _isRunning = false;
      _isFinished = false;
      _remainingSeconds = settings.steepTimerDuration;
    });
  }

  Future<void> _editTime() async {
    HapticFeedback.mediumImpact();
    final settings = Provider.of<SettingsService>(context, listen: false);

    if (_isRunning) {
      _timer?.cancel();
      NotificationService().cancelTimerNotification();
      settings.setSteepTimerTargetTime(null);
      setState(() {
        _isRunning = false;
      });
    }

    int duration = settings.steepTimerDuration;
    int minutes = duration ~/ 60;
    int seconds = duration % 60;

    final result = await showDialog<int>(
      context: context,
      builder: (context) =>
          _TimePickerDialog(initialMinutes: minutes, initialSeconds: seconds),
    );

    if (result != null) {
      _flashController.stop();
      _flashController.reset();
      await settings.setSteepTimerDuration(result);
      setState(() {
        _remainingSeconds = result;
        _isFinished = false;
      });
    }
  }

  String get _timerString {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        // Use static color when reduce motion is enabled
        final flashValue = reduceMotion ? 0.5 : _flashController.value;

        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: _isFinished
              ? Color.lerp(
                  Colors.white.withValues(alpha: 0.12),
                  Colors.deepOrange.withValues(alpha: 0.6),
                  flashValue,
                )
              : null,
          borderColor: _isFinished
              ? Color.lerp(
                  Colors.white.withValues(alpha: 0.15),
                  Colors.deepOrange.withValues(alpha: 0.8),
                  flashValue,
                )
              : null,
          child: child!,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Steep Timer",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                label:
                    "Steep timer. ${_isRunning ? 'Running' : 'Stopped'}. Time: $_timerString",
                button: true,
                hint: "Tap to edit timer duration",
                child: GestureDetector(
                  onTap: _editTime,
                  child: Container(
                    color: Colors.transparent,
                    child: Text(
                      _timerString,
                      textScaler: TextScaler.linear(
                        MediaQuery.textScalerOf(
                          context,
                        ).scale(1.0).clamp(1.0, 1.5),
                      ),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildControlButton(
                    icon: _isRunning ? Icons.pause : Icons.play_arrow,
                    color: AppTheme.emberOrange,
                    onTap: _toggleTimer,
                    label: _isRunning
                        ? "Pause steep timer"
                        : "Start steep timer",
                  ),
                  const SizedBox(width: 16),
                  _buildControlButton(
                    icon: Icons.stop,
                    color: Colors.deepOrange,
                    onTap: _stopTimer,
                    label: "Stop and reset steep timer",
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _TimePickerDialog extends StatefulWidget {
  final int initialMinutes;
  final int initialSeconds;

  const _TimePickerDialog({
    required this.initialMinutes,
    required this.initialSeconds,
  });

  @override
  State<_TimePickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<_TimePickerDialog> {
  late int _selectedMinute;
  late int _selectedSecond;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _secondController;

  @override
  void initState() {
    super.initState();
    _selectedMinute = widget.initialMinutes;
    _selectedSecond = widget.initialSeconds;
    _minuteController = FixedExtentScrollController(
      initialItem: widget.initialMinutes,
    );
    _secondController = FixedExtentScrollController(
      initialItem: widget.initialSeconds,
    );
  }

  @override
  void dispose() {
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2C5364),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C5364).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Set Timer",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPickerColumn(
                    controller: _minuteController,
                    count: 60,
                    label: "min",
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMinute = val);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 40,
                    ),
                    child: Text(
                      ":",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildPickerColumn(
                    controller: _secondController,
                    count: 60,
                    label: "sec",
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedSecond = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(
                      context,
                      (_selectedMinute * 60) + _selectedSecond,
                    );
                  },
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      color: AppTheme.emberOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerColumn({
    required FixedExtentScrollController controller,
    required int count,
    required String label,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: controller,
              backgroundColor: Colors.transparent,
              onSelectedItemChanged: onChanged,
              selectionOverlay: Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: AppTheme.emberOrange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
              children: List<Widget>.generate(count, (int index) {
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
