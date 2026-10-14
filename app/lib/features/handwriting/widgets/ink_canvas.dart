import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ink_point.dart';
import '../models/ink_stroke.dart';
import '../providers/canvas_provider.dart';

/// The core handwriting canvas widget.
///
/// Captures raw hardware events via [Listener], performs software palm-rejection
/// heuristics for stylus interactions, logs stylus pressure values for hardware
/// validation, and renders smoothed strokes with variable widths.
class InkCanvas extends ConsumerStatefulWidget {
  final Color backgroundColor;

  const InkCanvas({
    super.key,
    this.backgroundColor = Colors.white,
  });

  @override
  ConsumerState<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends ConsumerState<InkCanvas> {
  // Palm-rejection and active pointer tracking
  bool _isStylusActive = false;
  int? _activePointerId;
  int _pointSampleCount = 0;

  void _onPointerDown(PointerDownEvent event) {
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    // Palm rejection heuristic:
    // If a stylus stroke is already in progress, discard touch events.
    if (_isStylusActive && !isStylus) {
      debugPrint(
        '[InkCanvas PalmRejection] Discarded touch event (${event.pointer}) while stylus is active',
      );
      return;
    }

    if (isStylus) {
      _isStylusActive = true;
      _activePointerId = event.pointer;
    } else {
      _activePointerId = event.pointer;
    }

    _pointSampleCount = 0;

    // Convert tilt (radians) to degrees and project cartesian components
    final tiltDegrees = event.tilt * 180.0 / math.pi;
    final tiltX = (event.tilt * math.cos(event.orientation)) * 180.0 / math.pi;
    final tiltY = (event.tilt * math.sin(event.orientation)) * 180.0 / math.pi;

    debugPrint(
      '[Stylus-Down] kind=${event.kind.name} | pressure=${event.pressure.toStringAsFixed(4)} '
      '| tilt=${tiltDegrees.toStringAsFixed(1)}° | pos=${event.localPosition}',
    );

    final inkPoint = InkPoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure,
      tiltX: tiltX,
      tiltY: tiltY,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    ref.read(canvasProvider.notifier).startStroke(
          inkPoint,
          deviceKind: event.kind.name,
          tiltDegrees: tiltDegrees,
        );
  }

  void _onPointerMove(PointerMoveEvent event) {
    // If stylus is active and this is a touch event (e.g. user resting palm), reject
    if (_isStylusActive &&
        event.kind != PointerDeviceKind.stylus &&
        event.kind != PointerDeviceKind.invertedStylus) {
      return;
    }

    // Only process moves from the active pointer that initiated the stroke
    if (event.pointer != _activePointerId) return;

    _pointSampleCount++;

    final tiltDegrees = event.tilt * 180.0 / math.pi;
    final tiltX = (event.tilt * math.cos(event.orientation)) * 180.0 / math.pi;
    final tiltY = (event.tilt * math.sin(event.orientation)) * 180.0 / math.pi;

    // Explicit periodic console logging for physical hardware verification
    if (_pointSampleCount % 10 == 0 || event.pressure > 0.05) {
      debugPrint(
        '[Stylus-Move] sample=$_pointSampleCount | kind=${event.kind.name} '
        '| pressure=${event.pressure.toStringAsFixed(4)} | tilt=${tiltDegrees.toStringAsFixed(1)}°',
      );
    }

    final inkPoint = InkPoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure,
      tiltX: tiltX,
      tiltY: tiltY,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    ref.read(canvasProvider.notifier).addPoint(
          inkPoint,
          tiltDegrees: tiltDegrees,
        );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;

    final tiltDegrees = event.tilt * 180.0 / math.pi;
    debugPrint(
      '[Stylus-Up] kind=${event.kind.name} | final pressure=${event.pressure.toStringAsFixed(4)} '
      '| tilt=${tiltDegrees.toStringAsFixed(1)}° | total samples=$_pointSampleCount',
    );

    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      _isStylusActive = false;
    }
    _activePointerId = null;

    ref.read(canvasProvider.notifier).endStroke();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointerId) {
      debugPrint('[Stylus-Cancel] pointer=${event.pointer}');
      _isStylusActive = false;
      _activePointerId = null;
      ref.read(canvasProvider.notifier).endStroke();
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    // When hovering with M-Pencil above screen, update debug metrics
    final tiltDegrees = event.tilt * 180.0 / math.pi;
    ref.read(canvasProvider.notifier).updateDebugMetrics(
          deviceKind: '${event.kind.name} (hover)',
          pressure: event.pressure,
          tiltDegrees: tiltDegrees,
        );
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerHover: _onPointerHover,
      child: Container(
        color: widget.backgroundColor,
        width: double.infinity,
        height: double.infinity,
        child: CustomPaint(
          painter: _StrokePainter(
            strokes: canvasState.strokes,
            currentStroke: canvasState.currentStroke,
            canvasBackgroundColor: widget.backgroundColor,
          ),
          isComplex: true,
          willChange: true,
        ),
      ),
    );
  }
}

/// CustomPainter that renders smoothed ink strokes with pressure-adjusted widths.
class _StrokePainter extends CustomPainter {
  final List<InkStroke> strokes;
  final InkStroke? currentStroke;
  final Color canvasBackgroundColor;

  _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.canvasBackgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint committed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 2. Paint active in-progress stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isEraser) {
      paint.color = canvasBackgroundColor;
    } else {
      paint.color = stroke.color;
    }

    final points = stroke.points;

    // Single point / dot tap
    if (points.length == 1) {
      final p = points.first;
      final dotWidth = _calculateWidth(stroke.baseWidth, p.pressure, stroke.isEraser);
      final dotPaint = Paint()
        ..isAntiAlias = true
        ..color = paint.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), dotWidth / 2.0, dotPaint);
      return;
    }

    // Draw connected segments with pressure interpolation
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      // Average pressure between endpoints for a smooth transition
      final avgPressure = (p1.pressure + p2.pressure) / 2.0;
      final segmentWidth =
          _calculateWidth(stroke.baseWidth, avgPressure, stroke.isEraser);

      paint.strokeWidth = segmentWidth;
      canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
    }
  }

  /// Stroke width formula:
  /// baseWidth * (0.3 + 0.7 * pressure) — minimum 30% width even at zero pressure
  /// Eraser strokes are scaled wider for practical erasing ergonomics.
  double _calculateWidth(double baseWidth, double pressure, bool isEraser) {
    final clampedPressure = pressure.clamp(0.0, 1.0);
    final scale = 0.3 + 0.7 * clampedPressure;
    final width = baseWidth * scale;

    if (isEraser) {
      // Make eraser significantly wider (3.5x base)
      return (baseWidth * 3.5) * (0.5 + 0.5 * clampedPressure);
    }
    return width;
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return true; // Always repaint as new sampled points stream in
  }
}
