
import 'dart:async';
import 'package:flutter/material.dart';

class  StopwatchWidget  extends StatefulWidget {
  final DateTime startTime;
  final int? pausedDurationInSeconds; // Duración guardada si la sesión se está editando

  const  StopwatchWidget ({
    Key? key,
    required this.startTime,
    this.pausedDurationInSeconds,
  }) : super(key: key);

  @override
  _StopwatchWidgetState createState() => _StopwatchWidgetState();
}

class _StopwatchWidgetState extends State<StopwatchWidget> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Si es una sesión en edición (pausada), mostramos la duración guardada.
    if (widget.pausedDurationInSeconds != null) {
      _elapsed = Duration(seconds: widget.pausedDurationInSeconds!);
    } else {
      // Si es una nueva sesión, iniciamos el cronómetro.
      _elapsed = DateTime.now().difference(widget.startTime);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        // Nos aseguramos de que el tiempo no vaya hacia atrás si el usuario cambia la hora del sistema
        final now = DateTime.now();
        final currentElapsed = now.difference(widget.startTime);
        if (mounted && currentElapsed.isNegative == false) {
          setState(() {
            _elapsed = currentElapsed;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // Solo cancelamos el timer si no estaba en modo pausado
    if (widget.pausedDurationInSeconds == null) {
      _timer.cancel();
    }
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        _formatDuration(_elapsed),
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey[400],
          fontFamily: 'monospace', // Para que los números tengan el mismo ancho
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}