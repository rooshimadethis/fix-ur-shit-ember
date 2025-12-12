import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/notification_service.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';

class SteepTimer extends StatefulWidget {
  const SteepTimer({super.key});

  @override
  State<SteepTimer> createState() => _SteepTimerState();
}

class _SteepTimerState extends State<SteepTimer> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _isFinished = false;
  late AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = Provider.of<SettingsService>(context, listen: false);
      setState(() {
        _remainingSeconds = settings.steepTimerDuration;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    HapticFeedback.mediumImpact();
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
    } else {
      if (_remainingSeconds <= 0) {
         final settings = Provider.of<SettingsService>(context, listen: false);
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
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
           timer.cancel();
           setState(() {
             _isRunning = false;
             _isFinished = true;
           });
           HapticFeedback.heavyImpact();
           NotificationService().showTimerFinishedNotification();
           _flashController.repeat(reverse: true);
        }
      });
    }
  }

  void _stopTimer() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _flashController.stop();
    _flashController.reset();
    final settings = Provider.of<SettingsService>(context, listen: false);
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
        setState(() { _isRunning = false; });
    }

    int duration = settings.steepTimerDuration;
    int minutes = duration ~/ 60;
    int seconds = duration % 60;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => _TimePickerDialog(initialMinutes: minutes, initialSeconds: seconds),
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
    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        Color containerColor = Colors.white.withValues(alpha: 0.05); // Default
        if (_isFinished) {
            containerColor = Color.lerp(
                Colors.white.withValues(alpha: 0.05),
                Colors.red.withValues(alpha: 0.5),
                _flashController.value
            )!;
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _isFinished 
                    ? Color.lerp(
                        Colors.white.withValues(alpha: 0.1),
                        Colors.redAccent,
                        _flashController.value)!
                    : Colors.white.withValues(alpha: 0.1)
            ),
          ),
          child: child,
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
                    GestureDetector(
                        onTap: _editTime,
                        child: Container(
                            color: Colors.transparent, 
                            child: Text(
                                _timerString,
                                style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w200,
                                    color: Colors.white,
                                    fontFeatures: [FontFeature.tabularFigures()],
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
                            ),
                            const SizedBox(width: 16),
                             _buildControlButton(
                                icon: Icons.stop,
                                color: Colors.redAccent,
                                onTap: _stopTimer,
                            ),
                        ],
                    )
                ],
            )
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onTap}) {
       return GestureDetector(
           onTap: onTap,
           child: Container(
               width: 44,
               height: 44,
               decoration: BoxDecoration(
                   color: color.withValues(alpha: 0.2),
                   shape: BoxShape.circle,
                   border: Border.all(color: color.withValues(alpha: 0.5)),
               ),
               child: Icon(icon, color: color, size: 24),
           ),
       );
  }
}

class _TimePickerDialog extends StatefulWidget {
    final int initialMinutes;
    final int initialSeconds;

    const _TimePickerDialog({required this.initialMinutes, required this.initialSeconds});

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
        _minuteController = FixedExtentScrollController(initialItem: widget.initialMinutes);
        _secondController = FixedExtentScrollController(initialItem: widget.initialSeconds);
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
                        )
                    ],
                ),
                 padding: const EdgeInsets.all(24.0),
                 child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                         const Text(
                             "Set Timer",
                             style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                                         }
                                     ),
                                     const Padding(
                                         padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 40),
                                         child: Text(":", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                                     ),
                                     _buildPickerColumn(
                                         controller: _secondController, 
                                         count: 60,
                                         label: "sec",
                                         onChanged: (val) {
                                             HapticFeedback.selectionClick();
                                             setState(() => _selectedSecond = val);
                                         }
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
                                     child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                                 ),
                                 const SizedBox(width: 8),
                                 TextButton(
                                     onPressed: () {
                                         HapticFeedback.mediumImpact();
                                         Navigator.pop(context, (_selectedMinute * 60) + _selectedSecond);
                                     },
                                     child: const Text("Save", style: TextStyle(color: AppTheme.emberOrange, fontWeight: FontWeight.bold)),
                                 ),
                             ],
                         )
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
                                        style: const TextStyle(color: Colors.white, fontSize: 24),
                                    ),
                                );
                            }),
                        ),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
            ),
        );
    }
}
