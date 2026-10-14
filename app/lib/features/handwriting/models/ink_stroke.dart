import 'dart:ui';
import 'ink_point.dart';

/// Represents a complete or in-progress stroke on the canvas.
///
/// Holds the sequence of [InkPoint] samples, the stroke color,
/// the base width prior to pressure scaling, and whether the stroke acts as an eraser.
class InkStroke {
  final String id;
  final List<InkPoint> points;
  final Color color;
  final double baseWidth;
  final bool isEraser;

  const InkStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.baseWidth,
    this.isEraser = false,
  });

  /// Creates a copy with optionally updated fields.
  InkStroke copyWith({
    String? id,
    List<InkPoint>? points,
    Color? color,
    double? baseWidth,
    bool? isEraser,
  }) {
    return InkStroke(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      baseWidth: baseWidth ?? this.baseWidth,
      isEraser: isEraser ?? this.isEraser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': colorToHex(color),
      'base_width': baseWidth,
      'is_eraser': isEraser,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }

  factory InkStroke.fromJson(Map<String, dynamic> json) {
    return InkStroke(
      id: json['id'] as String? ?? '',
      color: hexToColor(json['color'] as String? ?? '#000000'),
      baseWidth: (json['base_width'] as num?)?.toDouble() ??
          (json['baseWidth'] as num?)?.toDouble() ??
          3.0,
      isEraser: json['is_eraser'] as bool? ??
          json['isEraser'] as bool? ??
          false,
      points: (json['points'] as List<dynamic>? ?? [])
          .map((item) => InkPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts a [Color] into a hex string `#RRGGBB` or `#AARRGGBB`.
  static String colorToHex(Color color) {
    // Note: using 8-digit hex if alpha is not 255, else 6-digit hex
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    if ((color.a * 255).round() == 255) {
      return '#$r$g$b'.toUpperCase();
    }
    return '#$a$r$g$b'.toUpperCase();
  }

  /// Parses a hex color string like `#RRGGBB` or `#AARRGGBB`.
  static Color hexToColor(String hex) {
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    final intVal = int.tryParse(cleaned, radix: 16) ?? 0xFF000000;
    return Color(intVal);
  }
}
