import 'dart:math' as math;
import 'dart:ui';

/// Represents a single high-precision sampled point within a Huawei M-Pencil stroke.
///
/// Captures canvas coordinates, 4096-level stylus pressure (normalized to 0.0–1.0),
/// tilt altitude & azimuth components in degrees, stylus orientation, and timestamp.
class InkPoint {
  final double x;
  final double y;
  final double pressure; // 0.0 to 1.0 (4096 discrete levels on Huawei M-Pencil)
  final double tiltX; // degrees (-90 to 90)
  final double tiltY; // degrees (-90 to 90)
  final double orientation; // radians (-pi to pi)
  final int timestamp; // milliseconds from epoch

  const InkPoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.orientation = 0.0,
    required this.timestamp,
  });

  Offset get offset => Offset(x, y);

  /// Total tilt angle in degrees (0° = perpendicular to screen, ~60° = tilted shading).
  double get tiltDegrees => math.sqrt(tiltX * tiltX + tiltY * tiltY).clamp(0.0, 90.0);

  /// Euclidean distance to another [InkPoint] in logical pixels.
  double distanceTo(InkPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Instantaneous velocity in pixels per millisecond from [previous].
  double velocityFrom(InkPoint previous) {
    final dt = (timestamp - previous.timestamp).abs();
    if (dt == 0) return 0.0;
    return distanceTo(previous) / dt;
  }

  /// Returns a translated copy of this point.
  InkPoint translated(double dx, double dy) {
    return InkPoint(
      x: x + dx,
      y: y + dy,
      pressure: pressure,
      tiltX: tiltX,
      tiltY: tiltY,
      orientation: orientation,
      timestamp: timestamp,
    );
  }

  /// Linearly interpolates between two [InkPoint] samples.
  static InkPoint lerp(InkPoint a, InkPoint b, double t) {
    return InkPoint(
      x: a.x + (b.x - a.x) * t,
      y: a.y + (b.y - a.y) * t,
      pressure: a.pressure + (b.pressure - a.pressure) * t,
      tiltX: a.tiltX + (b.tiltX - a.tiltX) * t,
      tiltY: a.tiltY + (b.tiltY - a.tiltY) * t,
      orientation: a.orientation + (b.orientation - a.orientation) * t,
      timestamp: (a.timestamp + (b.timestamp - a.timestamp) * t).round(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': double.parse(x.toStringAsFixed(2)),
      'y': double.parse(y.toStringAsFixed(2)),
      'pressure': double.parse(pressure.toStringAsFixed(4)),
      'tilt_x': double.parse(tiltX.toStringAsFixed(2)),
      'tilt_y': double.parse(tiltY.toStringAsFixed(2)),
      'orientation': double.parse(orientation.toStringAsFixed(3)),
      'timestamp': timestamp,
    };
  }

  factory InkPoint.fromJson(Map<String, dynamic> json) {
    return InkPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.5,
      tiltX: (json['tilt_x'] as num?)?.toDouble() ??
          (json['tiltX'] as num?)?.toDouble() ??
          0.0,
      tiltY: (json['tilt_y'] as num?)?.toDouble() ??
          (json['tiltY'] as num?)?.toDouble() ??
          0.0,
      orientation: (json['orientation'] as num?)?.toDouble() ?? 0.0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'InkPoint(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, '
        'pressure: ${pressure.toStringAsFixed(3)}, tilt: ${tiltDegrees.toStringAsFixed(1)}°)';
  }
}
