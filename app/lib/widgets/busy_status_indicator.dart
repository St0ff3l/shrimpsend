import 'package:flutter/material.dart';

import '../ui/platform_performance.dart';

class BusyStatusIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const BusyStatusIndicator({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    if (AppPlatformPerformance.preferStaticBusyIndicators) {
      final dotSize = (size * 0.72).clamp(5.0, size);
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
  }
}
