import 'package:flutter/material.dart';

class ThinkingIndicatorai extends StatefulWidget {
  const ThinkingIndicatorai({super.key});

  @override
  State<ThinkingIndicatorai> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicatorai> with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _opacity = [0.2, 0.6, 1.0];
  final Duration _duration = const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(
        _opacity.length,
            (index) => AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final value = _opacity[(index + (_controller.value * _opacity.length).floor()) % _opacity.length];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Opacity(
                opacity: value,
                child: const Text(
                  '.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

