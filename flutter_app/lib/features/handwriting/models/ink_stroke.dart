import 'dart:math' as math;
import 'dart:ui';
import 'ink_point.dart';

/// Huawei Notes brush types tailored for Huawei M-Pencil (4096 pressure levels + tilt).
enum BrushType {
  ballpoint('قلم حبر جاف', 'Ballpoint Pen'),
  fountain('قلم حبر سائل', 'Fountain Pen'),
  pencil('قلم رصاص', 'Pencil (Tilt Shading)'),
  highlighter('قلم تظليل', 'Highlighter'),
  laser('مؤشر ليزر', 'Laser Pointer');

  final String labelAr;
  final String labelEn;
  const BrushType(this.labelAr, this.labelEn);

  static BrushType fromName(String? name) {
    for (final b in BrushType.values) {
      if (b.name == name) return b;
    }
    return BrushType.fountain;
  }
}

/// Geometric shapes recognized by Huawei Notes "Hold-to-Shape" (الأشكال الذكية).
enum RecognizedShape {
  none('حر'),
  line('خط مستقيم'),
  arrow('سهم'),
  rectangle('مستطيل'),
  circle('دائرة / قطع ناقص'),
  triangle('مثلث');

  final String labelAr;
  const RecognizedShape(this.labelAr);

  static RecognizedShape fromName(String? name) {
    for (final s in RecognizedShape.values) {
      if (s.name == name) return s;
    }
    return RecognizedShape.none;
  }
}

/// Huawei Notes paper templates optimized for MatePad 11.5 PaperMatte display.
enum PaperTemplate {
  ruled('ورق مسطر عربي'),
  clinicalCornell('نموذج جلسة نفسية (Cornell)'),
  prescriptionRx('نموذج روشتة طبية (Rx)'),
  grid('ورق مربعات هندسية'),
  dotted('ورق منقط (Dotted)'),
  blank('ورقة بيضاء حرة');

  final String labelAr;
  const PaperTemplate(this.labelAr);

  static PaperTemplate fromName(String? name) {
    for (final t in PaperTemplate.values) {
      if (t.name == name) return t;
    }
    return PaperTemplate.ruled;
  }
}

/// Paper color themes for Huawei MatePad PaperMatte eye comfort.
enum PaperColorTheme {
  paperMatteWarm('ورق دافئ مريح للعين (PaperMatte)', Color(0xFFF8F5EC), Color(0xFFD9D1C1)),
  pureWhite('أبيض ناصع', Color(0xFFFFFFFF), Color(0xFFDCE3EA)),
  sepiaCalm('بيج كلاسيكي هادئ', Color(0xFFF3EAD8), Color(0xFFD2C4AA)),
  mintClinical('أخضر طبي هادئ', Color(0xFFF2F7F4), Color(0xFFC8DDD0)),
  darkSlate('الوضع الليلي الداكن', Color(0xFF1A202C), Color(0xFF334155));

  final String labelAr;
  final Color backgroundColor;
  final Color lineColor;
  const PaperColorTheme(this.labelAr, this.backgroundColor, this.lineColor);

  bool get isDark => this == PaperColorTheme.darkSlate;

  static PaperColorTheme fromName(String? name) {
    for (final c in PaperColorTheme.values) {
      if (c.name == name) return c;
    }
    return PaperColorTheme.paperMatteWarm;
  }
}

/// Represents a complete or in-progress stroke on the Huawei Notes canvas.
class InkStroke {
  final String id;
  final List<InkPoint> points;
  final Color color;
  final double baseWidth;
  final double opacity;
  final BrushType brushType;
  final RecognizedShape shapeType;
  final bool isEraser;
  final int pageIndex;
  final int createdAtMs;

  const InkStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.baseWidth,
    this.opacity = 1.0,
    this.brushType = BrushType.fountain,
    this.shapeType = RecognizedShape.none,
    this.isEraser = false,
    this.pageIndex = 0,
    this.createdAtMs = 0,
  });

  InkStroke copyWith({
    String? id,
    List<InkPoint>? points,
    Color? color,
    double? baseWidth,
    double? opacity,
    BrushType? brushType,
    RecognizedShape? shapeType,
    bool? isEraser,
    int? pageIndex,
    int? createdAtMs,
  }) {
    return InkStroke(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      baseWidth: baseWidth ?? this.baseWidth,
      opacity: opacity ?? this.opacity,
      brushType: brushType ?? this.brushType,
      shapeType: shapeType ?? this.shapeType,
      isEraser: isEraser ?? this.isEraser,
      pageIndex: pageIndex ?? this.pageIndex,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  /// Axis-aligned bounding box of all points in this stroke.
  Rect get boundingBox {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    final pad = baseWidth * 1.2 + 4.0;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  /// Returns a translated copy of this stroke (used when moving Lasso selection).
  InkStroke translated(double dx, double dy) {
    return copyWith(
      points: points.map((p) => p.translated(dx, dy)).toList(),
    );
  }

  /// Checks if any segment of this stroke intersects a circle (used by Stroke Eraser).
  bool hitsCircle(Offset center, double radius) {
    if (points.isEmpty) return false;
    final effectiveRadius = radius + baseWidth * 0.5;
    if (!boundingBox.inflate(effectiveRadius).contains(center)) {
      return false;
    }
    if (points.length == 1) {
      return (points.first.offset - center).distance <= effectiveRadius;
    }
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i].offset;
      final b = points[i + 1].offset;
      if (_distanceToSegment(center, a, b) <= effectiveRadius) {
        return true;
      }
    }
    return false;
  }

  /// Splits this stroke by removing points inside [center]/[radius] (used by Pixel Eraser).
  /// Returns the surviving sub-strokes (0, 1, or more pieces).
  List<InkStroke> splitByEraserCircle(Offset center, double radius) {
    if (points.isEmpty) return const [];
    final effectiveRadius = radius + baseWidth * 0.4;
    if (!boundingBox.inflate(effectiveRadius).contains(center)) {
      return [this];
    }

    final List<List<InkPoint>> segments = [];
    List<InkPoint> currentSegment = [];

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final inside = (pt.offset - center).distance <= effectiveRadius;
      if (!inside) {
        currentSegment.add(pt);
      } else {
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
          currentSegment = [];
        }
      }
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    if (segments.length == 1 && segments.first.length == points.length) {
      return [this];
    }

    int pieceIdx = 0;
    return segments
        .where((seg) => seg.isNotEmpty)
        .map((seg) {
          pieceIdx++;
          return copyWith(
            id: '${id}_p$pieceIdx',
            points: seg,
            shapeType: RecognizedShape.none,
          );
        })
        .toList();
  }

  /// Checks if the majority of this stroke lies inside a Lasso selection polygon.
  bool isInsidePolygon(List<Offset> polygon) {
    if (points.isEmpty || polygon.length < 3) return false;
    int insideCount = 0;
    final step = math.max(1, points.length ~/ 12);
    int tested = 0;
    for (int i = 0; i < points.length; i += step) {
      tested++;
      if (_pointInPolygon(points[i].offset, polygon)) {
        insideCount++;
      }
    }
    return tested > 0 && (insideCount / tested) >= 0.5;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq == 0.0) return ap.distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * ab.dx, a.dy + t * ab.dy);
    return (p - proj).distance;
  }

  static bool _pointInPolygon(Offset point, List<Offset> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      final intersect = ((yi > point.dy) != (yj > point.dy)) &&
          (point.dx < (xj - xi) * (point.dy - yi) / ((yj - yi) == 0 ? 0.00001 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Huawei Notes "Hold-to-Shape" (الأشكال الذكية) geometric classifier.
  /// Converts a hand-drawn stroke into a clean Line, Rectangle, Circle/Ellipse, or Triangle.
  InkStroke? tryConvertToGeometricShape({RecognizedShape? forcedShape}) {
    if (points.length < 5) return null;

    final start = points.first;
    final end = points.last;
    double pathLength = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      pathLength += points[i].distanceTo(points[i + 1]);
    }
    if (pathLength < 35.0) return null;

    final directDist = start.distanceTo(end);
    final bounds = boundingBox.deflate(baseWidth * 1.2 + 4.0);
    final avgPressure = points.fold<double>(0.0, (s, p) => s + p.pressure) / points.length;
    final nowTs = end.timestamp;

    InkPoint makePt(double x, double y) => InkPoint(
          x: x,
          y: y,
          pressure: avgPressure,
          timestamp: nowTs,
        );

    // 1. If forced shape is requested from the Shape Tool:
    if (forcedShape != null && forcedShape != RecognizedShape.none) {
      return _buildGeometricStroke(forcedShape, start, end, bounds, makePt);
    }

    // 2. Straight Line detection: direct distance is >= 86% of total path length
    if (directDist / pathLength >= 0.86) {
      return copyWith(
        shapeType: RecognizedShape.line,
        points: [start, end],
      );
    }

    // 3. Closed shape check (start and end points are relatively close)
    final isClosed = directDist < math.max(bounds.width, bounds.height) * 0.42;
    if (!isClosed || bounds.width < 24 || bounds.height < 24) {
      return null;
    }

    // Analyze corner count & circularity
    final center = bounds.center;
    final rx = bounds.width / 2.0;
    final ry = bounds.height / 2.0;
    double radialErrorSum = 0.0;
    for (final p in points) {
      final nx = (p.x - center.dx) / (rx == 0 ? 1 : rx);
      final ny = (p.y - center.dy) / (ry == 0 ? 1 : ry);
      final r = math.sqrt(nx * nx + ny * ny);
      radialErrorSum += (r - 1.0).abs();
    }
    final meanEllipseError = radialErrorSum / points.length;

    if (meanEllipseError < 0.21) {
      // Smooth Circle / Ellipse
      return _buildGeometricStroke(RecognizedShape.circle, start, end, bounds, makePt);
    } else {
      // Rectangle / Box
      return _buildGeometricStroke(RecognizedShape.rectangle, start, end, bounds, makePt);
    }
  }

  InkStroke _buildGeometricStroke(
    RecognizedShape shape,
    InkPoint start,
    InkPoint end,
    Rect bounds,
    InkPoint Function(double x, double y) makePt,
  ) {
    switch (shape) {
      case RecognizedShape.line:
      case RecognizedShape.arrow:
        return copyWith(
          shapeType: shape,
          points: [start, end],
        );
      case RecognizedShape.rectangle:
        final l = math.min(start.x, end.x) < bounds.left ? math.min(start.x, end.x) : bounds.left;
        final r = math.max(start.x, end.x) > bounds.right ? math.max(start.x, end.x) : bounds.right;
        final t = math.min(start.y, end.y) < bounds.top ? math.min(start.y, end.y) : bounds.top;
        final b = math.max(start.y, end.y) > bounds.bottom ? math.max(start.y, end.y) : bounds.bottom;
        return copyWith(
          shapeType: RecognizedShape.rectangle,
          points: [
            makePt(l, t),
            makePt(r, t),
            makePt(r, b),
            makePt(l, b),
            makePt(l, t),
          ],
        );
      case RecognizedShape.circle:
        final List<InkPoint> circlePts = [];
        final cx = bounds.center.dx;
        final cy = bounds.center.dy;
        final rx = math.max(16.0, bounds.width / 2.0);
        final ry = math.max(16.0, bounds.height / 2.0);
        const steps = 48;
        for (int i = 0; i <= steps; i++) {
          final theta = (i / steps) * 2 * math.pi;
          circlePts.add(makePt(cx + rx * math.cos(theta), cy + ry * math.sin(theta)));
        }
        return copyWith(
          shapeType: RecognizedShape.circle,
          points: circlePts,
        );
      case RecognizedShape.triangle:
        final topMid = makePt(bounds.center.dx, bounds.top);
        final botRight = makePt(bounds.right, bounds.bottom);
        final botLeft = makePt(bounds.left, bounds.bottom);
        return copyWith(
          shapeType: RecognizedShape.triangle,
          points: [topMid, botRight, botLeft, topMid],
        );
      case RecognizedShape.none:
        return this;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': colorToHex(color),
      'base_width': baseWidth,
      'opacity': opacity,
      'brush_type': brushType.name,
      'shape_type': shapeType.name,
      'is_eraser': isEraser,
      'page_index': pageIndex,
      'created_at_ms': createdAtMs,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }

  factory InkStroke.fromJson(Map<String, dynamic> json) {
    return InkStroke(
      id: json['id'] as String? ?? '',
      color: hexToColor(json['color'] as String? ?? '#000000'),
      baseWidth: (json['base_width'] as num?)?.toDouble() ??
          (json['baseWidth'] as num?)?.toDouble() ??
          3.5,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      brushType: BrushType.fromName(json['brush_type'] as String?),
      shapeType: RecognizedShape.fromName(json['shape_type'] as String?),
      isEraser: json['is_eraser'] as bool? ??
          json['isEraser'] as bool? ??
          false,
      pageIndex: (json['page_index'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
      points: (json['points'] as List<dynamic>? ?? [])
          .map((item) => InkPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static String colorToHex(Color color) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    if ((color.a * 255).round() == 255) {
      return '#$r$g$b'.toUpperCase();
    }
    return '#$a$r$g$b'.toUpperCase();
  }

  static Color hexToColor(String hex) {
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    final intVal = int.tryParse(cleaned, radix: 16) ?? 0xFF000000;
    return Color(intVal);
  }
}
