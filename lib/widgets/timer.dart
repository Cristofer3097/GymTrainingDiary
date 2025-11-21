import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';



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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }




  // Lógica del Timer
  void _startOrPauseTimer() {
    if (_isRunning) {
      // Pausar
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _endTime = null;
      });
    } else {
      // Iniciar
      if (_remainingSeconds == 0) {
        _remainingSeconds = _initialSeconds;
      }

      setState(() {
        _isRunning = true;
        _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) return;

        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            _isRunning = false;
          }
        });
      });
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
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(context, tempDuration.inSeconds);
              },
              child:Text(l10n.save),
            ),
          ],
        );
      },
    ).then((value) async { // Hacemos esta parte async
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
    final Color timerColor = _remainingSeconds == 0 ? Colors.red : (_isRunning ? theme.primaryColor : Colors.grey[400]!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.timer,
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón 1: Reiniciar
            IconButton(
              icon: const Icon(Icons.replay, size: 20),
              color: Colors.grey,
              tooltip: 'Reiniciar',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              onPressed: _resetTimer,
            ),

            // Botón 2: Play/Pause
            IconButton(
              icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 24),
              color: theme.primaryColor,
              tooltip: _isRunning ? 'Pausar' : 'Iniciar',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              onPressed: _startOrPauseTimer,
            ),

            // Botón 3: Configuración
            IconButton(
              icon: const Icon(Icons.timer_outlined, size: 20),
              color: Colors.grey,
              tooltip: 'Configurar',
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              onPressed: _showConfigDialog,
            ),

            Text(
              _formatDuration(Duration(seconds: _remainingSeconds)),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
                color: timerColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}