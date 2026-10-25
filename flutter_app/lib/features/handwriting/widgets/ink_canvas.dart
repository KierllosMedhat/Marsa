import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ink_point.dart';
import '../models/ink_stroke.dart';
import '../providers/canvas_provider.dart';

/// High-precision Huawei Notes canvas widget engineered for
/// Huawei MatePad 11.5 PaperMatte & Huawei M-Pencil (4096 pressure levels + tilt + double-tap).
class InkCanvas extends ConsumerStatefulWidget {
  final Color? backgroundColor;
  final VoidCallback? onStrokeCompleted;

  const InkCanvas({
    super.key,
    this.backgroundColor,
    this.onStrokeCompleted,
  });

  @override
  ConsumerState<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends ConsumerState<InkCanvas> {
  // Active stylus & palm rejection state
  bool _isStylusActive = false;
  int? _activeStylusPointerId;
  bool _isForceEraserActive = false;
  bool _isDraggingSelection = false;
  Offset? _lastDragCanvasPos;

  // Hold-to-Shape timer (Huawei Notes "Instant Shape" when holding M-Pencil still)
  Timer? _holdToShapeTimer;
  Offset? _lastHoldCheckPos;

  // Multi-touch gesture tracking (2-finger tap Undo, 3-finger tap Redo, 2-finger pinch zoom/pan)
  final Map<int, Offset> _activeTouchPoints = {};
  final Map<int, Offset> _initialTouchPoints = {};
  int _maxSimultaneousTouches = 0;
  DateTime? _multiTouchStartTime;
  double? _initialPinchDistance;
  double _initialZoomScale = 1.0;
  Offset? _lastFocalPoint;

  // Toast auto-hide timer
  Timer? _toastClearTimer;

  @override
  void dispose() {
    _holdToShapeTimer?.cancel();
    _toastClearTimer?.cancel();
    super.dispose();
  }

  /// Transforms screen local position into zoomed/panned canvas coordinates.
  Offset _toCanvasPoint(Offset localPos, CanvasState state) {
    return (localPos - state.panOffset) / state.zoomScale;
  }

  void _scheduleHoldToShape(InkPoint point) {
    _holdToShapeTimer?.cancel();
    _lastHoldCheckPos = point.offset;
    _holdToShapeTimer = Timer(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      ref.read(canvasProvider.notifier).trySnapCurrentStrokeToShape();
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    final state = ref.read(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);

    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    final isInvertedOrButtonEraser =
        event.kind == PointerDeviceKind.invertedStylus ||
            (isStylus &&
                ((event.buttons & kPrimaryStylusButton) != 0 ||
                    (event.buttons & kSecondaryStylusButton) != 0));

    // 1. If a stylus stroke is active, reject all finger/palm touches immediately
    if (_isStylusActive && !isStylus) {
      return;
    }

    // 2. Handle Finger / Multi-touch input
    if (!isStylus) {
      _activeTouchPoints[event.pointer] = event.localPosition;
      _initialTouchPoints[event.pointer] = event.localPosition;
      if (_activeTouchPoints.length > _maxSimultaneousTouches) {
        _maxSimultaneousTouches = _activeTouchPoints.length;
      }
      if (_activeTouchPoints.length == 1) {
        _multiTouchStartTime = DateTime.now();
      }

      // If 2 or more fingers are down, cancel any accidental single-finger stroke and switch to gesture mode
      if (_activeTouchPoints.length >= 2) {
        _holdToShapeTimer?.cancel();
        if (_activeStylusPointerId != null && !_isStylusActive) {
          notifier.cancelInProgressStroke();
          _activeStylusPointerId = null;
        }
        final pts = _activeTouchPoints.values.toList();
        _initialPinchDistance = (pts[0] - pts[1]).distance;
        _initialZoomScale = state.zoomScale;
        _lastFocalPoint = (pts[0] + pts[1]) / 2.0;
        return;
      }

      // If Stylus-Only mode is enabled, 1 finger pans the canvas instead of drawing
      if (state.stylusOnlyMode) {
        _lastFocalPoint = event.localPosition;
        return;
      }
    }

    // 3. Stylus or allowed single-finger drawing/interaction
    if (isStylus) {
      _isStylusActive = true;
    }
    _activeStylusPointerId = event.pointer;
    _isForceEraserActive = isInvertedOrButtonEraser;

    final canvasPos = _toCanvasPoint(event.localPosition, state);

    // Check if user tapped inside an active Lasso selection bounding box to move it
    final selectionBounds = state.selectedStrokesBounds;
    if (!_isForceEraserActive &&
        selectionBounds != null &&
        selectionBounds.contains(canvasPos)) {
      _isDraggingSelection = true;
      _lastDragCanvasPos = canvasPos;
      notifier.startMovingSelection();
      return;
    }

    final tiltDegrees = event.tilt * 180.0 / math.pi;
    final tiltX = (event.tilt * math.cos(event.orientation)) * 180.0 / math.pi;
    final tiltY = (event.tilt * math.sin(event.orientation)) * 180.0 / math.pi;

    // Normalize pressure: if device reports 0 on touch, use 0.5 default
    final rawPressure = event.pressure;
    final normalizedPressure =
        (rawPressure <= 0.001 && !isStylus) ? 0.55 : rawPressure.clamp(0.05, 1.0);

    final inkPoint = InkPoint(
      x: canvasPos.dx,
      y: canvasPos.dy,
      pressure: normalizedPressure,
      tiltX: tiltX,
      tiltY: tiltY,
      orientation: event.orientation,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    notifier.startStroke(
      inkPoint,
      deviceKind: isStylus ? 'Huawei M-Pencil (${event.kind.name})' : event.kind.name,
      tiltDegrees: tiltDegrees,
      forceEraser: _isForceEraserActive,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final state = ref.read(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);

    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    if (_isStylusActive && !isStylus) {
      return;
    }

    // Handle multi-touch pinch-to-zoom & pan or Stylus-Only 1-finger pan
    if (!isStylus && _activeTouchPoints.containsKey(event.pointer)) {
      _activeTouchPoints[event.pointer] = event.localPosition;

      if (_activeTouchPoints.length >= 2) {
        final pts = _activeTouchPoints.values.toList();
        final currentDist = (pts[0] - pts[1]).distance;
        final currentFocal = (pts[0] + pts[1]) / 2.0;

        double nextZoom = state.zoomScale;
        if (_initialPinchDistance != null && _initialPinchDistance! > 20) {
          nextZoom = (_initialZoomScale * (currentDist / _initialPinchDistance!))
              .clamp(0.6, 3.5);
        }

        Offset nextPan = state.panOffset;
        if (_lastFocalPoint != null) {
          nextPan += (currentFocal - _lastFocalPoint!);
        }
        _lastFocalPoint = currentFocal;
        notifier.updateViewport(zoomScale: nextZoom, panOffset: nextPan);
        return;
      }

      if (state.stylusOnlyMode && _activeTouchPoints.length == 1) {
        if (_lastFocalPoint != null) {
          final delta = event.localPosition - _lastFocalPoint!;
          notifier.updateViewport(panOffset: state.panOffset + delta);
        }
        _lastFocalPoint = event.localPosition;
        return;
      }
    }

    if (event.pointer != _activeStylusPointerId) return;

    final canvasPos = _toCanvasPoint(event.localPosition, state);

    // Handle dragging Lasso selection
    if (_isDraggingSelection && _lastDragCanvasPos != null) {
      final delta = canvasPos - _lastDragCanvasPos!;
      _lastDragCanvasPos = canvasPos;
      notifier.moveSelectedStrokes(delta.dx, delta.dy);
      return;
    }

    final tiltDegrees = event.tilt * 180.0 / math.pi;
    final tiltX = (event.tilt * math.cos(event.orientation)) * 180.0 / math.pi;
    final tiltY = (event.tilt * math.sin(event.orientation)) * 180.0 / math.pi;

    final rawPressure = event.pressure;
    final normalizedPressure =
        (rawPressure <= 0.001 && !isStylus) ? 0.55 : rawPressure.clamp(0.05, 1.0);

    final inkPoint = InkPoint(
      x: canvasPos.dx,
      y: canvasPos.dy,
      pressure: normalizedPressure,
      tiltX: tiltX,
      tiltY: tiltY,
      orientation: event.orientation,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    // Check if pointer moved enough to reset the Hold-to-Shape timer
    if (_lastHoldCheckPos == null ||
        (canvasPos - _lastHoldCheckPos!).distance > 4.5) {
      if (!state.currentStrokeSnappedToShape) {
        _scheduleHoldToShape(inkPoint);
      }
    }

    notifier.addPoint(
      inkPoint,
      tiltDegrees: tiltDegrees,
      forceEraser: _isForceEraserActive,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    final notifier = ref.read(canvasProvider.notifier);

    // Handle multi-touch two-finger tap Undo / three-finger tap Redo
    if (_activeTouchPoints.containsKey(event.pointer)) {
      _activeTouchPoints.remove(event.pointer);
      if (_activeTouchPoints.isEmpty) {
        final elapsedMs = _multiTouchStartTime != null
            ? DateTime.now().difference(_multiTouchStartTime!).inMilliseconds
            : 999;

        double maxMoved = 0.0;
        _initialTouchPoints.forEach((id, startPos) {
          if (id == event.pointer) {
            final d = (event.localPosition - startPos).distance;
            if (d > maxMoved) maxMoved = d;
          }
        });

        if (elapsedMs < 280 && maxMoved < 22.0) {
          if (_maxSimultaneousTouches == 2) {
            notifier.undo();
          } else if (_maxSimultaneousTouches == 3) {
            notifier.redo();
          }
        }
        _initialTouchPoints.clear();
        _maxSimultaneousTouches = 0;
        _initialPinchDistance = null;
        _lastFocalPoint = null;
      }
    }

    if (event.pointer != _activeStylusPointerId) return;

    _holdToShapeTimer?.cancel();

    if (_isDraggingSelection) {
      _isDraggingSelection = false;
      _lastDragCanvasPos = null;
      notifier.endMovingSelection();
      _isStylusActive = false;
      _activeStylusPointerId = null;
      widget.onStrokeCompleted?.call();
      return;
    }

    _isStylusActive = false;
    _activeStylusPointerId = null;

    notifier.endStroke(forceEraser: _isForceEraserActive);
    _isForceEraserActive = false;
    widget.onStrokeCompleted?.call();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activeTouchPoints.remove(event.pointer);
    if (event.pointer == _activeStylusPointerId) {
      _holdToShapeTimer?.cancel();
      _isDraggingSelection = false;
      _isStylusActive = false;
      _activeStylusPointerId = null;
      _isForceEraserActive = false;
      ref.read(canvasProvider.notifier).endStroke();
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    final state = ref.read(canvasProvider);
    final tiltDegrees = event.tilt * 180.0 / math.pi;
    final canvasPos = _toCanvasPoint(event.localPosition, state);

    // Check if M-Pencil barrel button is clicked while hovering
    if ((event.buttons & kPrimaryStylusButton) != 0 ||
        (event.buttons & kSecondaryStylusButton) != 0) {
      // Handled by native or hover button
    }

    ref.read(canvasProvider.notifier).updateDebugMetrics(
          deviceKind: 'Huawei M-Pencil (Hover)',
          pressure: event.pressure,
          tiltDegrees: tiltDegrees,
          cursorPosition: canvasPos,
        );
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);

    // Auto-dismiss M-Pencil gesture toast banner after 2.2 seconds
    if (canvasState.stylusToastMessage != null) {
      _toastClearTimer?.cancel();
      _toastClearTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) {
          ref.read(canvasProvider.notifier).clearToastMessage();
        }
      });
    }

    final effectiveBgColor =
        widget.backgroundColor ?? canvasState.paperTheme.backgroundColor;

    return Stack(
      children: [
        // 1. Main Interactive PaperMatte Surface
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            onPointerHover: _onPointerHover,
            child: ClipRect(
              child: Container(
                color: effectiveBgColor,
                width: double.infinity,
                height: double.infinity,
                child: CustomPaint(
                  painter: _PaperBackgroundPainter(
                    template: canvasState.paperTemplate,
                    theme: canvasState.paperTheme,
                    zoomScale: canvasState.zoomScale,
                    panOffset: canvasState.panOffset,
                    pageNumber: canvasState.currentPageIndex + 1,
                    totalPages: canvasState.totalPages,
                  ),
                  foregroundPainter: _HuaweiInkPainter(
                    strokes: canvasState.currentPageStrokes,
                    currentStroke: canvasState.currentStroke,
                    laserStrokes: canvasState.laserStrokes,
                    lassoPolygon: canvasState.lassoPolygon,
                    selectedStrokeIds: canvasState.selectedStrokeIds,
                    selectedBounds: canvasState.selectedStrokesBounds,
                    activeTool: canvasState.tool,
                    eraserRadius: canvasState.eraserRadius,
                    activeCursorPosition: canvasState.activeCursorPosition,
                    zoomScale: canvasState.zoomScale,
                    panOffset: canvasState.panOffset,
                  ),
                  isComplex: true,
                  willChange: true,
                ),
              ),
            ),
          ),
        ),

        // 2. Floating Lasso Selection Action Bar (when strokes are selected)
        if (canvasState.selectedStrokeIds.isNotEmpty &&
            canvasState.selectedStrokesBounds != null)
          _buildLassoFloatingMenu(context, canvasState),

        // 3. Huawei M-Pencil Gesture Toast Notification (Double-Tap / Smart Shape)
        if (canvasState.stylusToastMessage != null)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xEE1E293B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withAlpha(140),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_fix_high_rounded,
                        color: Color(0xFF38BDF8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        canvasState.stylusToastMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 4. Zoom Scale Badge (bottom-left) when zoomed in/out
        if ((canvasState.zoomScale - 1.0).abs() > 0.04 ||
            canvasState.panOffset.distance > 12)
          Positioned(
            bottom: 16,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ref.read(canvasProvider.notifier).resetViewport(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xDD1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in_map, color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        '${(canvasState.zoomScale * 100).round()}% (إعادة ضبط)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLassoFloatingMenu(BuildContext context, CanvasState state) {
    final notifier = ref.read(canvasProvider.notifier);
    final bounds = state.selectedStrokesBounds!;
    final screenTopCenter = Offset(
      bounds.center.dx * state.zoomScale + state.panOffset.dx,
      bounds.top * state.zoomScale + state.panOffset.dy,
    );

    final topPos = math.max(80.0, screenTopCenter.dy - 58.0);
    final leftPos = (screenTopCenter.dx - 130.0).clamp(16.0, 600.0);

    return Positioned(
      top: topPos,
      left: leftPos,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1E293B),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recolor quick dots
              for (final c in const [
                Color(0xFF1E1E1E),
                Color(0xFF1B4F72),
                Color(0xFFDC2626),
                Color(0xFF15803D),
              ])
                InkWell(
                  onTap: () => notifier.recolorSelectedStrokes(c),
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white24,
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                tooltip: 'نسخ التحديد',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: notifier.duplicateSelectedStrokes,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFF87171),
                  size: 20,
                ),
                tooltip: 'حذف التحديد',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: notifier.deleteSelectedStrokes,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                tooltip: 'إلغاء التحديد',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                onPressed: notifier.clearSelection,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders Huawei Notes paper templates (Ruled, Clinical Cornell, Prescription Rx, Grid, Dotted).
class _PaperBackgroundPainter extends CustomPainter {
  final PaperTemplate template;
  final PaperColorTheme theme;
  final double zoomScale;
  final Offset panOffset;
  final int pageNumber;
  final int totalPages;

  _PaperBackgroundPainter({
    required this.template,
    required this.theme,
    required this.zoomScale,
    required this.panOffset,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    final linePaint = Paint()
      ..color = theme.lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final accentMarginPaint = Paint()
      ..color = theme.isDark
          ? const Color(0xFFEF4444).withAlpha(90)
          : const Color(0xFFD97706).withAlpha(110)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;

    switch (template) {
      case PaperTemplate.blank:
        break;

      case PaperTemplate.ruled:
        const double topHeader = 84.0;
        const double spacing = 36.0;
        // Double header line
        canvas.drawLine(
          Offset(24, topHeader),
          Offset(width - 24, topHeader),
          accentMarginPaint,
        );
        canvas.drawLine(
          Offset(24, topHeader + 4),
          Offset(width - 24, topHeader + 4),
          accentMarginPaint,
        );
        // Horizontal ruled lines
        for (double y = topHeader + spacing; y < height - 24; y += spacing) {
          canvas.drawLine(Offset(24, y), Offset(width - 24, y), linePaint);
        }
        // RTL right margin line
        final marginX = width - 72.0;
        if (marginX > 100) {
          canvas.drawLine(
            Offset(marginX, topHeader),
            Offset(marginX, height - 24),
            accentMarginPaint,
          );
        }
        break;

      case PaperTemplate.grid:
        const double step = 30.0;
        for (double x = step; x < width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, height), linePaint);
        }
        for (double y = step; y < height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(width, y), linePaint);
        }
        break;

      case PaperTemplate.dotted:
        const double step = 28.0;
        final dotPaint = Paint()
          ..color = theme.lineColor.withAlpha(220)
          ..style = PaintingStyle.fill;
        for (double x = step; x < width - 16; x += step) {
          for (double y = 76; y < height - 16; y += step) {
            canvas.drawCircle(Offset(x, y), 1.4, dotPaint);
          }
        }
        break;

      case PaperTemplate.clinicalCornell:
        _paintClinicalCornellTemplate(canvas, size, linePaint, accentMarginPaint);
        break;

      case PaperTemplate.prescriptionRx:
        _paintPrescriptionRxTemplate(canvas, size, linePaint, accentMarginPaint);
        break;
    }

    // Subtle page number watermark at bottom-left
    _drawLabel(
      canvas,
      'صفحة $pageNumber من $totalPages — عيادة مرساة (PaperMatte)',
      Offset(28, height - 26),
      fontSize: 11,
      color: theme.isDark ? Colors.white38 : Colors.black38,
    );

    canvas.restore();
  }

  void _paintClinicalCornellTemplate(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint accentPaint,
  ) {
    final w = size.width;
    final h = size.height;
    const topBarY = 92.0;
    final bottomBoxY = h - 135.0;
    final rightColumnX = w * 0.68;

    // Outer frame
    final frameRect = Rect.fromLTRB(24, 68, w - 24, h - 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(8)),
      accentPaint,
    );

    // Header divider
    canvas.drawLine(Offset(24, topBarY + 24), Offset(w - 24, topBarY + 24), accentPaint);

    // Vertical Cornell divider (Right 32% for MSE & Cues, Left 68% for Session Notes)
    if (bottomBoxY > topBarY + 40) {
      canvas.drawLine(
        Offset(rightColumnX, topBarY + 24),
        Offset(rightColumnX, bottomBoxY),
        accentPaint,
      );
      // Horizontal lines in main notes section
      for (double y = topBarY + 60; y < bottomBoxY; y += 34) {
        canvas.drawLine(Offset(28, y), Offset(rightColumnX - 6, y), linePaint);
      }
      // Bottom summary divider
      canvas.drawLine(Offset(24, bottomBoxY), Offset(w - 24, bottomBoxY), accentPaint);
    }

    final labelColor = theme.isDark ? Colors.white60 : const Color(0xFF1B4F72);
    _drawLabel(
      canvas,
      'نموذج تدوين الجلسة النفسية (Cornell Clinical Note) — د. مارينا نبيه نمر',
      Offset(w - 420, 76),
      fontSize: 12.5,
      color: labelColor,
      bold: true,
    );
    _drawLabel(
      canvas,
      'الأعراض والملاحظات السلوكية / MSE',
      Offset(rightColumnX + 16, topBarY + 30),
      fontSize: 11.5,
      color: labelColor,
      bold: true,
    );
    _drawLabel(
      canvas,
      'تحليل الجلسة والملاحظات الحرة (M-Pencil)',
      Offset(rightColumnX - 240, topBarY + 30),
      fontSize: 11.5,
      color: labelColor,
      bold: true,
    );
    if (bottomBoxY > topBarY + 40) {
      _drawLabel(
        canvas,
        'الخلاصة والخطة العلاجية والواجب المنزلي (Treatment Plan & Next Steps):',
        Offset(w - 420, bottomBoxY + 8),
        fontSize: 11.5,
        color: labelColor,
        bold: true,
      );
    }
  }

  void _paintPrescriptionRxTemplate(
    Canvas canvas,
    Size size,
    Paint linePaint,
    Paint accentPaint,
  ) {
    final w = size.width;
    final h = size.height;
    final headerColor = theme.isDark ? const Color(0xFF93C5FD) : const Color(0xFF1B4F72);
    final goldColor = const Color(0xFFB58728);

    final borderPaint = Paint()
      ..color = goldColor.withAlpha(160)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(28, 68, w - 28, h - 32),
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // Clinic Header
    _drawLabel(
      canvas,
      'عيادة مرساة للطب النفسي وعلاج الإدمان — د. مارينا نبيه نمر',
      Offset(w - 410, 82),
      fontSize: 14,
      color: headerColor,
      bold: true,
    );
    _drawLabel(
      canvas,
      'MARSA PSYCHIATRIC CLINIC — Dr. Marina Nabih Nemer',
      const Offset(48, 84),
      fontSize: 12,
      color: goldColor,
      bold: true,
    );

    canvas.drawLine(Offset(40, 114), Offset(w - 40, 114), borderPaint);

    // Large Rx Symbol
    _drawLabel(
      canvas,
      '℞ / الدواء والجرعة:',
      Offset(w - 190, 128),
      fontSize: 20,
      color: headerColor,
      bold: true,
    );

    // Ruled lines for prescription items
    for (double y = 175; y < h - 95; y += 38) {
      canvas.drawLine(Offset(48, y), Offset(w - 48, y), linePaint);
    }

    // Footer Signature Area
    canvas.drawLine(Offset(40, h - 82), Offset(w - 40, h - 82), borderPaint);
    _drawLabel(
      canvas,
      'توقيع الطبيب المعالج: ________________________',
      Offset(52, h - 66),
      fontSize: 12,
      color: headerColor,
      bold: true,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 12,
    Color color = Colors.black54,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PaperBackgroundPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.theme != theme ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.pageNumber != pageNumber ||
        oldDelegate.totalPages != totalPages;
  }
}

/// High-precision Huawei M-Pencil Stroke & Ribbon Painter.
///
/// Implements:
/// - Quadratic Bézier spline smoothing
/// - 4096-level pressure + velocity tapering for Fountain Pen
/// - M-Pencil tilt shading (`tiltDegrees`) for Pencil
/// - Single-pass translucent chisel-tip Highlighter
/// - Laser Pointer neon glow
/// - Lasso selection polygon & bounding box
/// - Live Eraser cursor ring
class _HuaweiInkPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final InkStroke? currentStroke;
  final List<InkStroke> laserStrokes;
  final List<Offset> lassoPolygon;
  final Set<String> selectedStrokeIds;
  final Rect? selectedBounds;
  final SelectedTool activeTool;
  final double eraserRadius;
  final Offset? activeCursorPosition;
  final double zoomScale;
  final Offset panOffset;

  _HuaweiInkPainter({
    required this.strokes,
    required this.currentStroke,
    required this.laserStrokes,
    required this.lassoPolygon,
    required this.selectedStrokeIds,
    required this.selectedBounds,
    required this.activeTool,
    required this.eraserRadius,
    required this.activeCursorPosition,
    required this.zoomScale,
    required this.panOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(zoomScale);

    // 1. Draw committed strokes on current page
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, isSelected: selectedStrokeIds.contains(stroke.id));
    }

    // 2. Draw active in-progress stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }

    // 3. Draw temporary glowing Laser Pointer strokes
    for (final laser in laserStrokes) {
      _drawLaserStroke(canvas, laser);
    }

    // 4. Draw active Lasso selection loop
    if (lassoPolygon.length >= 2) {
      _drawLassoLoop(canvas, lassoPolygon);
    }

    // 5. Draw bounding box around selected strokes
    if (selectedBounds != null && selectedStrokeIds.isNotEmpty) {
      _drawSelectionBox(canvas, selectedBounds!);
    }

    // 6. Draw live Eraser or M-Pencil hover cursor ring
    if (activeCursorPosition != null) {
      if (activeTool == SelectedTool.eraser) {
        final ringPaint = Paint()
          ..color = const Color(0xFF1E293B).withAlpha(180)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
        final fillPaint = Paint()
          ..color = const Color(0xFF38BDF8).withAlpha(35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(activeCursorPosition!, eraserRadius, fillPaint);
        canvas.drawCircle(activeCursorPosition!, eraserRadius, ringPaint);
      } else {
        final hoverDot = Paint()
          ..color = const Color(0xFF2E86AB).withAlpha(120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(activeCursorPosition!, 4.0, hoverDot);
      }
    }

    canvas.restore();
  }

  void _drawStroke(Canvas canvas, InkStroke stroke, {bool isSelected = false}) {
    if (stroke.points.isEmpty) return;

    if (stroke.brushType == BrushType.laser) {
      _drawLaserStroke(canvas, stroke);
      return;
    }

    // Highlight glow if selected by Lasso tool
    if (isSelected) {
      final selPath = _buildSmoothPath(stroke.points);
      final glowPaint = Paint()
        ..color = const Color(0xFF38BDF8).withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.baseWidth + 8.0;
      canvas.drawPath(selPath, glowPaint);
    }

    // Geometric Shapes (Line, Arrow, Rectangle, Circle, Triangle)
    if (stroke.shapeType != RecognizedShape.none && stroke.points.length >= 2) {
      _drawGeometricShape(canvas, stroke);
      return;
    }

    // Highlighter: render as a single continuous smooth path so overlapping segments never darken
    if (stroke.brushType == BrushType.highlighter) {
      final path = _buildSmoothPath(stroke.points);
      final paint = Paint()
        ..isAntiAlias = true
        ..color = stroke.color.withValues(alpha: stroke.opacity.clamp(0.18, 0.5))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.baseWidth;
      canvas.drawPath(path, paint);
      return;
    }

    final points = stroke.points;

    // Single dot tap
    if (points.length == 1) {
      final p = points.first;
      final w = _computePointWidth(stroke, p, 0.0);
      final dotPaint = Paint()
        ..isAntiAlias = true
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..style = PaintingStyle.fill;
      if (stroke.brushType == BrushType.pencil && p.tiltDegrees > 20) {
        dotPaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      }
      canvas.drawCircle(p.offset, w / 2.0, dotPaint);
      return;
    }

    // Variable-width quadratic Bézier spline subdivision for Fountain, Ballpoint, and Pencil
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];

      final mid1 = Offset((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0);
      final mid2 = Offset((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0);

      final velocity = p2.velocityFrom(p1);
      final avgPressure = (p1.pressure + p2.pressure) / 2.0;
      final avgTilt = (p1.tiltDegrees + p2.tiltDegrees) / 2.0;

      // Tail tapering on final 3 points of Fountain Pen strokes
      double tailTaper = 1.0;
      if (stroke.brushType == BrushType.fountain && i >= points.length - 4) {
        final remaining = points.length - 1 - i;
        tailTaper = (0.45 + 0.18 * remaining).clamp(0.45, 1.0);
      }

      final samplePt = InkPoint(
        x: p1.x,
        y: p1.y,
        pressure: avgPressure,
        tiltX: avgTilt,
        tiltY: 0,
        orientation: p1.orientation,
        timestamp: p1.timestamp,
      );

      final width = _computePointWidth(stroke, samplePt, velocity) * tailTaper;

      // Pencil opacity & shading responds to pressure + M-Pencil tilt
      double alpha = stroke.opacity;
      if (stroke.brushType == BrushType.pencil) {
        alpha = (stroke.opacity * (0.45 + 0.55 * avgPressure)).clamp(0.2, 1.0);
        if (avgTilt > 22.0) {
          final blurSigma = ((avgTilt - 22.0) / 45.0 * 2.4).clamp(0.5, 2.5);
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
        } else {
          paint.maskFilter = null;
        }
      } else {
        paint.maskFilter = null;
      }

      paint.color = stroke.color.withValues(alpha: alpha);
      paint.strokeWidth = width;

      final segPath = Path()
        ..moveTo(i == 0 ? p1.x : mid1.dx, i == 0 ? p1.y : mid1.dy)
        ..quadraticBezierTo(
          p1.x,
          p1.y,
          i == points.length - 2 ? p2.x : mid2.dx,
          i == points.length - 2 ? p2.y : mid2.dy,
        );

      canvas.drawPath(segPath, paint);
    }
  }

  /// Calculates dynamic stroke width from 4096-level pressure, tilt angle, and stroke velocity.
  double _computePointWidth(InkStroke stroke, InkPoint point, double velocity) {
    final p = point.pressure.clamp(0.05, 1.0);
    final base = stroke.baseWidth;

    switch (stroke.brushType) {
      case BrushType.ballpoint:
        // Ballpoint: steady, crisp width with subtle pressure response
        return base * (0.72 + 0.38 * p);

      case BrushType.fountain:
        // Fountain Pen: rich calligraphic response to pressure + inverse velocity
        final pressureCurve = math.pow(p, 1.15).toDouble();
        final velocityFactor = (1.0 - (velocity / 3.8).clamp(0.0, 0.38));
        return base * (0.32 + 1.15 * pressureCurve) * velocityFactor;

      case BrushType.pencil:
        // Pencil: responds to M-Pencil tilt angle (shading when tilted > 20°)
        final tilt = point.tiltDegrees;
        final tiltMultiplier =
            tilt > 20.0 ? (1.0 + ((tilt - 20.0) / 50.0) * 1.85) : 1.0;
        return base * (0.55 + 0.55 * p) * tiltMultiplier;

      case BrushType.highlighter:
        return base;

      case BrushType.laser:
        return base;
    }
  }

  Path _buildSmoothPath(List<InkPoint> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.x, points.first.y);
    if (points.length == 1) return path;
    if (points.length == 2) {
      path.lineTo(points.last.x, points.last.y);
      return path;
    }
    for (int i = 1; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final midX = (p1.x + p2.x) / 2.0;
      final midY = (p1.y + p2.y) / 2.0;
      path.quadraticBezierTo(p1.x, p1.y, midX, midY);
    }
    path.lineTo(points.last.x, points.last.y);
    return path;
  }

  void _drawGeometricShape(Canvas canvas, InkStroke stroke) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = stroke.color.withValues(alpha: stroke.opacity)
      ..strokeWidth = stroke.baseWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(stroke.points.first.x, stroke.points.first.y);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].x, stroke.points[i].y);
    }
    canvas.drawPath(path, paint);

    // Draw arrowhead if shapeType == arrow
    if (stroke.shapeType == RecognizedShape.arrow && stroke.points.length >= 2) {
      final start = stroke.points.first.offset;
      final end = stroke.points.last.offset;
      final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
      final headLen = stroke.baseWidth * 3.5 + 8.0;
      final p1 = Offset(
        end.dx - headLen * math.cos(angle - math.pi / 6),
        end.dy - headLen * math.sin(angle - math.pi / 6),
      );
      final p2 = Offset(
        end.dx - headLen * math.cos(angle + math.pi / 6),
        end.dy - headLen * math.sin(angle + math.pi / 6),
      );
      final arrowPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(p2.dx, p2.dy);
      canvas.drawPath(arrowPath, paint);
    }
  }

  void _drawLaserStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.isEmpty) return;
    final path = _buildSmoothPath(stroke.points);
    final outerGlow = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFEF4444).withAlpha(140)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.baseWidth * 2.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final innerCore = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFFF1F2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.baseWidth * 0.7;

    canvas.drawPath(path, outerGlow);
    canvas.drawPath(path, innerCore);
  }

  void _drawLassoLoop(Canvas canvas, List<Offset> polygon) {
    final fillPaint = Paint()
      ..color = const Color(0xFF38BDF8).withAlpha(28)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (int i = 1; i < polygon.length; i++) {
      path.lineTo(polygon[i].dx, polygon[i].dy);
    }
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  void _drawSelectionBox(Canvas canvas, Rect bounds) {
    final boxPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final fillPaint = Paint()
      ..color = const Color(0xFF38BDF8).withAlpha(18)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(6)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(6)),
      boxPaint,
    );

    // Corner resize/drag handles
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (final corner in [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ]) {
      canvas.drawCircle(corner, 5.0, handlePaint);
      canvas.drawCircle(corner, 5.0, boxPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HuaweiInkPainter oldDelegate) => true;
}
