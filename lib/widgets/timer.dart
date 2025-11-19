import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

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
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Inicializar notificaciones
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // Manejar ciclo de vida de la app (Fondo vs Primer plano)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // La app se fue a segundo plano
      if (_isRunning) {
        _scheduleNotification();
      }
    } else if (state == AppLifecycleState.resumed) {
      // La app volvió
      _cancelNotification();
      if (_isRunning && _endTime != null) {
        final now = DateTime.now();
        if (now.isAfter(_endTime!)) {
          // El tiempo se acabó mientras estaba fuera
          setState(() {
            _remainingSeconds = 0;
            _isRunning = false;
          });
        } else {
          // Recalcular tiempo restante
          setState(() {
            _remainingSeconds = _endTime!.difference(now).inSeconds;
          });
        }
      }
    }
  }

  void _scheduleNotification() async {
    if (_remainingSeconds <= 0) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Temporizador',
      channelDescription: 'Notificaciones del temporizador de descanso',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);


  }

  void _cancelNotification() {
    _notificationsPlugin.cancelAll();
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
            _onTimerFinished();
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

  Future<void> _onTimerFinished() async {
    // Vibrar 2 segundos si la app está activa
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 2000);
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timer_finished',
      'Tiempo Terminado',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Solo mostramos notificación si NO estamos en primer plano visualmente (difícil de detectar exacto sin contexto)
    // O simplemente la mostramos siempre como aviso:
    await _notificationsPlugin.show(
      0,
      '¡Tiempo terminado!',
      'Tu descanso ha finalizado.',
      details,
    );
  }

  // Diálogo de configuración
  void _showConfigDialog() {
    int tempSeconds = _initialSeconds;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Configurar Temporizador"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Selecciona duración (segundos/minutos):"),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [30, 60, 90, 120, 150, 180, 210, 240, 300].map((seconds) {
                  return ChoiceChip(
                    label: Text(_formatDuration(Duration(seconds: seconds))),
                    selected: tempSeconds == seconds,
                    onSelected: (selected) {
                      if (selected) {
                        Navigator.pop(context, seconds);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ],
        );
      },
    ).then((value) {
      if (value != null && value is int) {
        setState(() {
          _initialSeconds = value;
          _remainingSeconds = value;
          _isRunning = false;
          _timer?.cancel();
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color timerColor = _remainingSeconds == 0 ? Colors.red : (_isRunning ? theme.primaryColor : Colors.grey[400]!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Temporizador",
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