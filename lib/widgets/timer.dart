import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:vibration/vibration.dart'; //
import 'package:permission_handler/permission_handler.dart';



class CountdownTimerWidget extends StatefulWidget {
  const CountdownTimerWidget({Key? key}) : super(key: key);

  @override
  _CountdownTimerWidgetState createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> with WidgetsBindingObserver {
  // Configuración por defecto: 90 segundos (1:30)
  int _initialSeconds = 120;
  int _remainingSeconds = 120;
  bool _isRunning = false;
  Timer? _timer;
  DateTime? _endTime;

  // Notificaciones

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedTime();
  }

  Future<void> _loadSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _initialSeconds = prefs.getInt('timer_default_seconds') ?? 120;
        if (!_isRunning) {
          _remainingSeconds = _initialSeconds;
        }
      });
    }
  }

  //Determina Color
  Color _getTimerColor() {
    if (!_isRunning && _remainingSeconds == _initialSeconds) {
      return Theme.of(context).primaryColor;
    }

    // Calcula el porcentaje restante
    double ratio = _initialSeconds > 0 ? _remainingSeconds / _initialSeconds : 0;

    if (ratio > 0.50) {
      return Colors.green;
    }else if (ratio > 0.50) {
      return Colors.lime;
    }else if (ratio > 0.25) {
      return Colors.amber;
    } else if (ratio > 0.10) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
      super.dispose();
    }


  Future<void> _startOrPauseTimer() async {
    // Comprobamos si el dispositivo puede vibrar antes de iniciar
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == false) {
      debugPrint("Este dispositivo no soporta vibración");
    }

    setState(() {
      if (_isRunning) {
        _timer?.cancel();
        _isRunning = false;
      } else {
        if (_remainingSeconds <= 0) {
          _remainingSeconds = _initialSeconds;
        }
        _isRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_remainingSeconds > 0) {
              _remainingSeconds--;
            } else {
              _timer?.cancel();
              _isRunning = false;
              _triggerVibration(); // <-- Llamamos a la vibración al terminar
            }
          });
        });
      }
    });
  }

  // Vibración
  void _triggerVibration() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // Vibra en un patrón: espera 0ms, vibra 500ms, espera 200ms, vibra 500ms
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 1000]);
    }
  }

    void _resetTimer() {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _remainingSeconds = _initialSeconds;
        _endTime = null;
      });
    }


    // Diálogo de configuración
    void _showConfigDialog() {
      Duration tempDuration = Duration(seconds: _initialSeconds);
      final l10n = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(l10n.timer_config,
                style: TextStyle(color: Colors.white)),
            content: SizedBox(
              height: 200,
              width: double.maxFinite,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                ),
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.ms,
                  initialTimerDuration: tempDuration,
                  onTimerDurationChanged: (Duration newDuration) {
                    if (newDuration.inSeconds > 0) {
                      tempDuration = newDuration;
                    }
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel,
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme
                      .of(context)
                      .primaryColor,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.pop(context, tempDuration.inSeconds);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ).then((value) async {
        if (value != null && value is int) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('timer_default_seconds', value);

          setState(() {
            _initialSeconds = value;
            if (!_isRunning) {
              _remainingSeconds = value;
            }
          });
        }
      });
    }

    String _formatDuration(Duration d) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      if (d.inHours > 0) {
        String hours = twoDigits(d.inHours);
        String minutes = twoDigits(d.inMinutes.remainder(60));
        String seconds = twoDigits(d.inSeconds.remainder(60));
        return "$hours:$minutes:$seconds";
      } else {
        String minutes = twoDigits(d.inMinutes.remainder(60));
        String seconds = twoDigits(d.inSeconds.remainder(60));
        return "$minutes:$seconds";
      }
    }


    @override
    Widget build(BuildContext context) {
      final theme = Theme.of(context);
      final l10n = AppLocalizations.of(context)!;
      final timerColor = _getTimerColor();
      final double progress = _initialSeconds > 0 ? _remainingSeconds / _initialSeconds : 0.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
            child: Text(
              l10n.timer,
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.replay, size: 20),
                color: Colors.grey,
                onPressed: _resetTimer,
              ),
              IconButton(
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 24),
                color: theme.primaryColor,
                onPressed: _startOrPauseTimer,
              ),
              IconButton(
                icon: const Icon(Icons.timer_outlined, size: 20),
                color: Colors.grey,
                onPressed: _showConfigDialog,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: timerColor,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    _formatDuration(Duration(seconds: _remainingSeconds)),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: timerColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    }
