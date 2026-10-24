/// Represents a single sampled point within an ink stroke.
/// 
/// Captures coordinates, stylus pressure (normalized to 0.0-1.0),
/// tilt values in degrees, and precision timestamp.
class InkPoint {
  final double x;
  final double y;
  final double pressure; // 0.0 to 1.0 (will be 0.0 on devices without pressure)
  final double tiltX; // degrees, 0.0 if unsupported
  final double tiltY;
  final int timestamp; // milliseconds from epoch

  const InkPoint({
    required this.x,
    required this.y,
    this.pressure = 0.0,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'pressure': pressure,
      'tilt_x': tiltX,
      'tilt_y': tiltY,
      'timestamp': timestamp,
    };
  }

  factory InkPoint.fromJson(Map<String, dynamic> json) {
    return InkPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.0,
      tiltX: (json['tilt_x'] as num?)?.toDouble() ??
          (json['tiltX'] as num?)?.toDouble() ??
          0.0,
      tiltY: (json['tilt_y'] as num?)?.toDouble() ??
          (json['tiltY'] as num?)?.toDouble() ??
          0.0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'InkPoint(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, '
        'pressure: ${pressure.toStringAsFixed(3)}, tilt: (${tiltX.toStringAsFixed(1)}°, ${tiltY.toStringAsFixed(1)}°))';
  }
}
