
import 'dart:async';
import 'package:flutter/material.dart';

class StopwatchWidget extends StatelessWidget {
  final Duration elapsed;

  const StopwatchWidget({
    Key? key,
    required this.elapsed,
  }) : super(key: key);

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
        _formatDuration(elapsed), // Simplemente formatea la duración recibida
        style: TextStyle(
          fontSize: 18,
          color: Colors.grey[400],
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}