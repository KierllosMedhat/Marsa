import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ink_point.dart';
import '../models/ink_stroke.dart';

/// Available primary tools in the Huawei Notes toolbar.
enum SelectedTool {
  pen,
  eraser,
  lasso,
  shape,
  laser,
}

/// Huawei Notes eraser modes.
enum EraserMode {
  stroke('ممحاة الخط الكامل', 'يمسح الخط بالكامل عند لمسه'),
  pixel('ممحاة دقيقة (جزئية)', 'يمسح الجزء المحدد فقط تحت الممحاة');

  final String labelAr;
  final String descriptionAr;
  const EraserMode(this.labelAr, this.descriptionAr);
}

/// Per-brush remembered configuration (Huawei Notes remembers each pen's color, width, and opacity).
class BrushConfig {
  final Color color;
  final double width;
  final double opacity;

  const BrushConfig({
    required this.color,
    required this.width,
    this.opacity = 1.0,
  });

  BrushConfig copyWith({
    Color? color,
    double? width,
    double? opacity,
  }) {
    return BrushConfig(
      color: color ?? this.color,
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
    );
  }
}

/// Immutable state holding the Huawei Notes canvas & M-Pencil workspace data.
class CanvasState {
  final List<InkStroke> strokes;
  final InkStroke? currentStroke;
  final List<InkStroke> laserStrokes; // Temporary glowing laser strokes

  // Undo/Redo snapshot stacks (supports undoing strokes, erasures, lasso moves, and page clears)
  final List<List<InkStroke>> undoStack;
  final List<List<InkStroke>> redoStack;

  // Tool & Brush Configuration
  final SelectedTool tool;
  final BrushType activeBrush;
  final Map<BrushType, BrushConfig> brushConfigs;
  final EraserMode eraserMode;
  final double eraserRadius;
  final RecognizedShape activeShapeTool;
  final bool smartShapeHoldEnabled; // Huawei Notes "Hold at end of stroke to form shape"
  final bool currentStrokeSnappedToShape;

  // Lasso Selection State
  final List<Offset> lassoPolygon;
  final Set<String> selectedStrokeIds;

  // Multi-Page & Paper Template State
  final int currentPageIndex;
  final int totalPages;
  final PaperTemplate paperTemplate;
  final PaperColorTheme paperTheme;

  // Viewport Zoom & Pan State
  final double zoomScale;
  final Offset panOffset;

  // Huawei M-Pencil Hardware & Palm Rejection State
  final bool stylusOnlyMode; // When true, finger pans/zooms while only M-Pencil draws
  final bool showDebugOverlay;
  final String lastDeviceKind;
  final double lastPressure;
  final double lastTiltDegrees;
  final double lastVelocity;
  final Offset? activeCursorPosition;
  final String? stylusToastMessage;

  const CanvasState({
    this.strokes = const [],
    this.currentStroke,
    this.laserStrokes = const [],
    this.undoStack = const [],
    this.redoStack = const [],
    this.tool = SelectedTool.pen,
    this.activeBrush = BrushType.fountain,
    this.brushConfigs = const {
      BrushType.fountain: BrushConfig(
        color: Color(0xFF1B4F72),
        width: 3.8,
        opacity: 1.0,
      ),
      BrushType.ballpoint: BrushConfig(
        color: Color(0xFF1E1E1E),
        width: 2.6,
        opacity: 1.0,
      ),
      BrushType.pencil: BrushConfig(
        color: Color(0xFF374151),
        width: 4.5,
        opacity: 0.88,
      ),
      BrushType.highlighter: BrushConfig(
        color: Color(0xFFFACC15),
        width: 16.0,
        opacity: 0.38,
      ),
      BrushType.laser: BrushConfig(
        color: Color(0xFFEF4444),
        width: 4.0,
        opacity: 1.0,
      ),
    },
    this.eraserMode = EraserMode.stroke,
    this.eraserRadius = 18.0,
    this.activeShapeTool = RecognizedShape.rectangle,
    this.smartShapeHoldEnabled = true,
    this.currentStrokeSnappedToShape = false,
    this.lassoPolygon = const [],
    this.selectedStrokeIds = const {},
    this.currentPageIndex = 0,
    this.totalPages = 1,
    this.paperTemplate = PaperTemplate.ruled,
    this.paperTheme = PaperColorTheme.paperMatteWarm,
    this.zoomScale = 1.0,
    this.panOffset = Offset.zero,
    this.stylusOnlyMode = false,
    this.showDebugOverlay = false,
    this.lastDeviceKind = 'M-Pencil Ready',
    this.lastPressure = 0.0,
    this.lastTiltDegrees = 0.0,
    this.lastVelocity = 0.0,
    this.activeCursorPosition,
    this.stylusToastMessage,
  });

  BrushConfig get currentBrushConfig =>
      brushConfigs[activeBrush] ??
      const BrushConfig(color: Color(0xFF1B4F72), width: 3.8, opacity: 1.0);

  Color get currentColor => currentBrushConfig.color;
  double get baseWidth => currentBrushConfig.width;
  double get currentOpacity => currentBrushConfig.opacity;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  List<InkStroke> get currentPageStrokes =>
      strokes.where((s) => s.pageIndex == currentPageIndex).toList();

  int get totalStrokes => currentPageStrokes.length;
  int get currentStrokePointsCount => currentStroke?.points.length ?? 0;

  Rect? get selectedStrokesBounds {
    if (selectedStrokeIds.isEmpty) return null;
    final selected = currentPageStrokes
        .where((s) => selectedStrokeIds.contains(s.id))
        .toList();
    if (selected.isEmpty) return null;
    Rect bounds = selected.first.boundingBox;
    for (int i = 1; i < selected.length; i++) {
      bounds = bounds.expandToInclude(selected[i].boundingBox);
    }
    return bounds.inflate(8.0);
  }

  CanvasState copyWith({
    List<InkStroke>? strokes,
    InkStroke? currentStroke,
    bool clearCurrentStroke = false,
    List<InkStroke>? laserStrokes,
    List<List<InkStroke>>? undoStack,
    List<List<InkStroke>>? redoStack,
    SelectedTool? tool,
    BrushType? activeBrush,
    Map<BrushType, BrushConfig>? brushConfigs,
    EraserMode? eraserMode,
    double? eraserRadius,
    RecognizedShape? activeShapeTool,
    bool? smartShapeHoldEnabled,
    bool? currentStrokeSnappedToShape,
    List<Offset>? lassoPolygon,
    Set<String>? selectedStrokeIds,
    int? currentPageIndex,
    int? totalPages,
    PaperTemplate? paperTemplate,
    PaperColorTheme? paperTheme,
    double? zoomScale,
    Offset? panOffset,
    bool? stylusOnlyMode,
    bool? showDebugOverlay,
    String? lastDeviceKind,
    double? lastPressure,
    double? lastTiltDegrees,
    double? lastVelocity,
    Offset? activeCursorPosition,
    bool clearCursorPosition = false,
    String? stylusToastMessage,
    bool clearToastMessage = false,
  }) {
    return CanvasState(
      strokes: strokes ?? this.strokes,
      currentStroke:
          clearCurrentStroke ? null : (currentStroke ?? this.currentStroke),
      laserStrokes: laserStrokes ?? this.laserStrokes,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      tool: tool ?? this.tool,
      activeBrush: activeBrush ?? this.activeBrush,
      brushConfigs: brushConfigs ?? this.brushConfigs,
      eraserMode: eraserMode ?? this.eraserMode,
      eraserRadius: eraserRadius ?? this.eraserRadius,
      activeShapeTool: activeShapeTool ?? this.activeShapeTool,
      smartShapeHoldEnabled:
          smartShapeHoldEnabled ?? this.smartShapeHoldEnabled,
      currentStrokeSnappedToShape:
          currentStrokeSnappedToShape ?? this.currentStrokeSnappedToShape,
      lassoPolygon: lassoPolygon ?? this.lassoPolygon,
      selectedStrokeIds: selectedStrokeIds ?? this.selectedStrokeIds,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      totalPages: totalPages ?? this.totalPages,
      paperTemplate: paperTemplate ?? this.paperTemplate,
      paperTheme: paperTheme ?? this.paperTheme,
      zoomScale: zoomScale ?? this.zoomScale,
      panOffset: panOffset ?? this.panOffset,
      stylusOnlyMode: stylusOnlyMode ?? this.stylusOnlyMode,
      showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
      lastDeviceKind: lastDeviceKind ?? this.lastDeviceKind,
      lastPressure: lastPressure ?? this.lastPressure,
      lastTiltDegrees: lastTiltDegrees ?? this.lastTiltDegrees,
      lastVelocity: lastVelocity ?? this.lastVelocity,
      activeCursorPosition: clearCursorPosition
          ? null
          : (activeCursorPosition ?? this.activeCursorPosition),
      stylusToastMessage: clearToastMessage
          ? null
          : (stylusToastMessage ?? this.stylusToastMessage),
    );
  }
}

/// Controller for Huawei Notes experience on Huawei MatePad + M-Pencil.
class CanvasNotifier extends StateNotifier<CanvasState> {
  static const MethodChannel _stylusChannel =
      MethodChannel('com.marsa.clinic/stylus');

  SelectedTool _previousPenTool = SelectedTool.pen;
  bool _hasPushedUndoForCurrentErase = false;
  bool _hasPushedUndoForCurrentMove = false;
  static int _idCounter = 0;

  CanvasNotifier() : super(const CanvasState()) {
    _initNativeStylusBridge();
  }

  void _initNativeStylusBridge() {
    try {
      _stylusChannel.setMethodCallHandler((call) async {
        if (call.method == 'onStylusDoubleTap') {
          triggerStylusDoubleTap();
        }
      });
    } catch (_) {}

    // Also listen for F19 / F20 hardware key events (used by Huawei M-Pencil on HarmonyOS
    // and forwarded into the Live Cloud OTA container by MainActivity.kt)
    try {
      HardwareKeyboard.instance.addHandler((KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.f19 ||
                event.logicalKey == LogicalKeyboardKey.f20)) {
          triggerStylusDoubleTap();
          return true;
        }
        return false;
      });
    } catch (_) {}
  }

  String _generateStrokeId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _idCounter++;
    return 'stroke_${now}_$_idCounter';
  }

  void _pushUndoSnapshot() {
    final snapshot = List<InkStroke>.from(state.strokes);
    final updatedUndo = List<List<InkStroke>>.from(state.undoStack)
      ..add(snapshot);
    if (updatedUndo.length > 40) {
      updatedUndo.removeAt(0);
    }
    state = state.copyWith(
      undoStack: updatedUndo,
      redoStack: const [],
    );
  }

  /// Huawei M-Pencil Double-Tap Barrel Gesture:
  /// Switches instantaneously between the active Pen and Eraser (with haptic feedback).
  void triggerStylusDoubleTap() {
    HapticFeedback.selectionClick();
    if (state.tool == SelectedTool.eraser) {
      final target = _previousPenTool == SelectedTool.eraser
          ? SelectedTool.pen
          : _previousPenTool;
      state = state.copyWith(
        tool: target,
        stylusToastMessage:
            'نقر مزدوج M-Pencil: التبديل إلى ${state.activeBrush.labelAr}',
      );
    } else {
      _previousPenTool = state.tool;
      state = state.copyWith(
        tool: SelectedTool.eraser,
        selectedStrokeIds: const {},
        lassoPolygon: const [],
        stylusToastMessage:
            'نقر مزدوج M-Pencil: التبديل إلى ${state.eraserMode.labelAr}',
      );
    }
  }

  void clearToastMessage() {
    if (state.stylusToastMessage != null) {
      state = state.copyWith(clearToastMessage: true);
    }
  }

  /// Starts an interaction (Pen stroke, Laser stroke, Eraser sweep, or Lasso selection).
  void startStroke(
    InkPoint point, {
    required String deviceKind,
    double tiltDegrees = 0.0,
    bool forceEraser = false,
  }) {
    final effectiveTool = forceEraser ? SelectedTool.eraser : state.tool;

    if (effectiveTool == SelectedTool.eraser) {
      _hasPushedUndoForCurrentErase = false;
      _applyEraserAt(point.offset);
      state = state.copyWith(
        lastDeviceKind: deviceKind,
        lastPressure: point.pressure,
        lastTiltDegrees: tiltDegrees,
        activeCursorPosition: point.offset,
      );
      return;
    }

    if (effectiveTool == SelectedTool.lasso) {
      state = state.copyWith(
        lassoPolygon: [point.offset],
        selectedStrokeIds: const {},
        lastDeviceKind: deviceKind,
        activeCursorPosition: point.offset,
      );
      return;
    }

    final isLaser = effectiveTool == SelectedTool.laser;
    final brushType = isLaser ? BrushType.laser : state.activeBrush;
    final config = state.brushConfigs[brushType] ?? state.currentBrushConfig;

    final newStroke = InkStroke(
      id: _generateStrokeId(),
      points: [point],
      color: config.color,
      baseWidth: config.width,
      opacity: brushType == BrushType.highlighter
          ? config.opacity.clamp(0.2, 0.55)
          : config.opacity,
      brushType: brushType,
      shapeType: effectiveTool == SelectedTool.shape
          ? state.activeShapeTool
          : RecognizedShape.none,
      isEraser: false,
      pageIndex: state.currentPageIndex,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    state = state.copyWith(
      currentStroke: newStroke,
      currentStrokeSnappedToShape: false,
      selectedStrokeIds: const {},
      lassoPolygon: const [],
      lastDeviceKind: deviceKind,
      lastPressure: point.pressure,
      lastTiltDegrees: tiltDegrees,
      lastVelocity: 0.0,
      activeCursorPosition: point.offset,
    );
  }

  /// Streams a new point into the active stroke, eraser, or lasso.
  void addPoint(
    InkPoint point, {
    double tiltDegrees = 0.0,
    bool forceEraser = false,
  }) {
    final effectiveTool = forceEraser ? SelectedTool.eraser : state.tool;

    if (effectiveTool == SelectedTool.eraser) {
      _applyEraserAt(point.offset);
      state = state.copyWith(
        lastPressure: point.pressure,
        lastTiltDegrees: tiltDegrees,
        activeCursorPosition: point.offset,
      );
      return;
    }

    if (effectiveTool == SelectedTool.lasso) {
      final updatedLasso = List<Offset>.from(state.lassoPolygon)
        ..add(point.offset);
      state = state.copyWith(
        lassoPolygon: updatedLasso,
        activeCursorPosition: point.offset,
      );
      return;
    }

    final active = state.currentStroke;
    if (active == null) return;

    // If the stroke already snapped to a geometric shape via Hold-to-Shape,
    // allow resizing the shape endpoint dynamically while still holding!
    if (state.currentStrokeSnappedToShape && active.points.isNotEmpty) {
      final rawDraft = active.copyWith(
        points: [active.points.first, point],
      );
      final reshaped = rawDraft.tryConvertToGeometricShape(
        forcedShape: active.shapeType,
      );
      if (reshaped != null) {
        state = state.copyWith(
          currentStroke: reshaped,
          lastPressure: point.pressure,
          lastTiltDegrees: tiltDegrees,
          activeCursorPosition: point.offset,
        );
      }
      return;
    }

    final prevPoint = active.points.isNotEmpty ? active.points.last : point;
    final velocity = point.velocityFrom(prevPoint);

    // If using the dedicated Shape Tool, preview the geometric shape live
    if (effectiveTool == SelectedTool.shape) {
      final draft = active.copyWith(points: [active.points.first, point]);
      final shaped = draft.tryConvertToGeometricShape(
        forcedShape: state.activeShapeTool,
      );
      state = state.copyWith(
        currentStroke: shaped ?? draft,
        lastPressure: point.pressure,
        lastTiltDegrees: tiltDegrees,
        lastVelocity: velocity,
        activeCursorPosition: point.offset,
      );
      return;
    }

    final updatedPoints = List<InkPoint>.from(active.points)..add(point);
    final updatedStroke = active.copyWith(points: updatedPoints);

    state = state.copyWith(
      currentStroke: updatedStroke,
      lastPressure: point.pressure,
      lastTiltDegrees: tiltDegrees,
      lastVelocity: velocity,
      activeCursorPosition: point.offset,
    );
  }

  /// Huawei Notes "Hold-to-Shape" (التثبيت لتكوين شكل هندسي متقن):
  /// Called when the user holds the M-Pencil stationary at the end of a stroke.
  bool trySnapCurrentStrokeToShape() {
    if (!state.smartShapeHoldEnabled) return false;
    if (state.tool != SelectedTool.pen) return false;
    if (state.currentStrokeSnappedToShape) return false;

    final active = state.currentStroke;
    if (active == null || active.points.length < 6) return false;

    final snapped = active.tryConvertToGeometricShape();
    if (snapped != null && snapped.shapeType != RecognizedShape.none) {
      HapticFeedback.mediumImpact();
      state = state.copyWith(
        currentStroke: snapped,
        currentStrokeSnappedToShape: true,
        stylusToastMessage:
            'تم التعرف على الشكل تلقائياً: ${snapped.shapeType.labelAr}',
      );
      return true;
    }
    return false;
  }

  /// Finalizes the active stroke, eraser sweep, or lasso selection.
  void endStroke({bool forceEraser = false}) {
    final effectiveTool = forceEraser ? SelectedTool.eraser : state.tool;

    if (effectiveTool == SelectedTool.eraser) {
      _hasPushedUndoForCurrentErase = false;
      state = state.copyWith(clearCursorPosition: true);
      return;
    }

    if (effectiveTool == SelectedTool.lasso) {
      final poly = state.lassoPolygon;
      final Set<String> matchedIds = {};
      if (poly.length >= 3) {
        for (final s in state.currentPageStrokes) {
          if (s.isInsidePolygon(poly)) {
            matchedIds.add(s.id);
          }
        }
      }
      if (matchedIds.isNotEmpty) {
        HapticFeedback.selectionClick();
      }
      state = state.copyWith(
        lassoPolygon: const [],
        selectedStrokeIds: matchedIds,
        clearCursorPosition: true,
      );
      return;
    }

    final active = state.currentStroke;
    if (active == null) return;

    // Laser pointer strokes fade out automatically after 1.6 seconds
    if (active.brushType == BrushType.laser) {
      final updatedLaser = List<InkStroke>.from(state.laserStrokes)..add(active);
      state = state.copyWith(
        laserStrokes: updatedLaser,
        clearCurrentStroke: true,
        clearCursorPosition: true,
      );
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        state = state.copyWith(
          laserStrokes: state.laserStrokes
              .where((s) => s.id != active.id)
              .toList(),
        );
      });
      return;
    }

    if (active.points.isNotEmpty) {
      _pushUndoSnapshot();
      final updatedStrokes = List<InkStroke>.from(state.strokes)..add(active);
      state = state.copyWith(
        strokes: updatedStrokes,
        clearCurrentStroke: true,
        currentStrokeSnappedToShape: false,
        clearCursorPosition: true,
      );
    } else {
      state = state.copyWith(
        clearCurrentStroke: true,
        currentStrokeSnappedToShape: false,
        clearCursorPosition: true,
      );
    }
  }

  /// Cancels an in-progress stroke without committing it (e.g., when switching to 2-finger pinch/tap).
  void cancelInProgressStroke() {
    if (state.currentStroke != null) {
      state = state.copyWith(
        clearCurrentStroke: true,
        currentStrokeSnappedToShape: false,
      );
    }
  }

  /// Applies either Stroke Eraser or Pixel Eraser at [center] on the current page.
  void _applyEraserAt(Offset center) {
    final radius = state.eraserRadius;
    final pageIdx = state.currentPageIndex;

    if (state.eraserMode == EraserMode.stroke) {
      final hitAny = state.strokes.any(
        (s) => s.pageIndex == pageIdx && s.hitsCircle(center, radius),
      );
      if (!hitAny) return;

      if (!_hasPushedUndoForCurrentErase) {
        _pushUndoSnapshot();
        _hasPushedUndoForCurrentErase = true;
      }

      final surviving = state.strokes
          .where(
            (s) => s.pageIndex != pageIdx || !s.hitsCircle(center, radius),
          )
          .toList();
      state = state.copyWith(strokes: surviving);
    } else {
      // Pixel / Partial Eraser: splits touched strokes cleanly
      bool modified = false;
      final List<InkStroke> nextStrokes = [];
      for (final s in state.strokes) {
        if (s.pageIndex != pageIdx) {
          nextStrokes.add(s);
          continue;
        }
        if (s.hitsCircle(center, radius)) {
          modified = true;
          final pieces = s.splitByEraserCircle(center, radius);
          nextStrokes.addAll(pieces);
        } else {
          nextStrokes.add(s);
        }
      }
      if (modified) {
        if (!_hasPushedUndoForCurrentErase) {
          _pushUndoSnapshot();
          _hasPushedUndoForCurrentErase = true;
        }
        state = state.copyWith(strokes: nextStrokes);
      }
    }
  }

  // ===========================================================================
  // Lasso Selection Manipulation Actions
  // ===========================================================================

  void startMovingSelection() {
    _hasPushedUndoForCurrentMove = false;
  }

  void moveSelectedStrokes(double dx, double dy) {
    if (state.selectedStrokeIds.isEmpty) return;
    if (!_hasPushedUndoForCurrentMove) {
      _pushUndoSnapshot();
      _hasPushedUndoForCurrentMove = true;
    }
    final updated = state.strokes.map((s) {
      if (state.selectedStrokeIds.contains(s.id)) {
        return s.translated(dx, dy);
      }
      return s;
    }).toList();
    state = state.copyWith(strokes: updated);
  }

  void endMovingSelection() {
    _hasPushedUndoForCurrentMove = false;
  }

  void deleteSelectedStrokes() {
    if (state.selectedStrokeIds.isEmpty) return;
    _pushUndoSnapshot();
    final surviving = state.strokes
        .where((s) => !state.selectedStrokeIds.contains(s.id))
        .toList();
    state = state.copyWith(
      strokes: surviving,
      selectedStrokeIds: const {},
    );
  }

  void duplicateSelectedStrokes() {
    if (state.selectedStrokeIds.isEmpty) return;
    _pushUndoSnapshot();
    final List<InkStroke> copies = [];
    final Set<String> newSelectedIds = {};
    for (final s in state.currentPageStrokes) {
      if (state.selectedStrokeIds.contains(s.id)) {
        final copyId = _generateStrokeId();
        newSelectedIds.add(copyId);
        copies.add(
          s.translated(24.0, 24.0).copyWith(id: copyId),
        );
      }
    }
    state = state.copyWith(
      strokes: [...state.strokes, ...copies],
      selectedStrokeIds: newSelectedIds,
    );
  }

  void recolorSelectedStrokes(Color newColor) {
    if (state.selectedStrokeIds.isEmpty) return;
    _pushUndoSnapshot();
    final updated = state.strokes.map((s) {
      if (state.selectedStrokeIds.contains(s.id)) {
        return s.copyWith(color: newColor);
      }
      return s;
    }).toList();
    state = state.copyWith(strokes: updated);
  }

  void clearSelection() {
    if (state.selectedStrokeIds.isNotEmpty || state.lassoPolygon.isNotEmpty) {
      state = state.copyWith(
        selectedStrokeIds: const {},
        lassoPolygon: const [],
      );
    }
  }

  // ===========================================================================
  // Undo / Redo / Clear
  // ===========================================================================

  void undo() {
    if (state.undoStack.isEmpty) return;
    HapticFeedback.lightImpact();

    final updatedUndo = List<List<InkStroke>>.from(state.undoStack);
    final previousSnapshot = updatedUndo.removeLast();
    final updatedRedo = List<List<InkStroke>>.from(state.redoStack)
      ..add(List<InkStroke>.from(state.strokes));

    state = state.copyWith(
      strokes: previousSnapshot,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      selectedStrokeIds: const {},
    );
  }

  void redo() {
    if (state.redoStack.isEmpty) return;
    HapticFeedback.lightImpact();

    final updatedRedo = List<List<InkStroke>>.from(state.redoStack);
    final nextSnapshot = updatedRedo.removeLast();
    final updatedUndo = List<List<InkStroke>>.from(state.undoStack)
      ..add(List<InkStroke>.from(state.strokes));

    state = state.copyWith(
      strokes: nextSnapshot,
      undoStack: updatedUndo,
      redoStack: updatedRedo,
      selectedStrokeIds: const {},
    );
  }

  /// Clears all strokes on the current page (and records an Undo snapshot).
  void clear() {
    if (state.currentPageStrokes.isEmpty) return;
    _pushUndoSnapshot();
    final otherPagesStrokes = state.strokes
        .where((s) => s.pageIndex != state.currentPageIndex)
        .toList();
    state = state.copyWith(
      strokes: otherPagesStrokes,
      clearCurrentStroke: true,
      selectedStrokeIds: const {},
      lassoPolygon: const [],
      lastPressure: 0.0,
      lastTiltDegrees: 0.0,
    );
  }

  /// Loads previously serialized strokes (and calculates total pages).
  void loadStrokes(
    List<InkStroke> loaded, {
    PaperTemplate? template,
    PaperColorTheme? theme,
  }) {
    int maxPage = 0;
    for (final s in loaded) {
      if (s.pageIndex > maxPage) maxPage = s.pageIndex;
    }
    state = state.copyWith(
      strokes: List<InkStroke>.from(loaded),
      clearCurrentStroke: true,
      undoStack: const [],
      redoStack: const [],
      selectedStrokeIds: const {},
      currentPageIndex: 0,
      totalPages: maxPage + 1,
      paperTemplate: template ?? state.paperTemplate,
      paperTheme: theme ?? state.paperTheme,
    );
  }

  // ===========================================================================
  // Tool, Brush, Template, Page & Viewport Setters
  // ===========================================================================

  void setTool(SelectedTool tool) {
    if (tool == SelectedTool.pen) {
      _previousPenTool = SelectedTool.pen;
    }
    state = state.copyWith(
      tool: tool,
      selectedStrokeIds: tool == SelectedTool.lasso ? state.selectedStrokeIds : const {},
      lassoPolygon: const [],
    );
  }

  void setBrush(BrushType brush) {
    _previousPenTool = SelectedTool.pen;
    state = state.copyWith(
      tool: brush == BrushType.laser ? SelectedTool.laser : SelectedTool.pen,
      activeBrush: brush,
      selectedStrokeIds: const {},
    );
  }

  void setColor(Color color) {
    final currentConfig = state.currentBrushConfig;
    final updatedConfigs = Map<BrushType, BrushConfig>.from(state.brushConfigs);
    updatedConfigs[state.activeBrush] = currentConfig.copyWith(color: color);

    state = state.copyWith(
      brushConfigs: updatedConfigs,
      tool: state.tool == SelectedTool.eraser ? SelectedTool.pen : state.tool,
    );
  }

  void setBaseWidth(double width) {
    final currentConfig = state.currentBrushConfig;
    final updatedConfigs = Map<BrushType, BrushConfig>.from(state.brushConfigs);
    updatedConfigs[state.activeBrush] =
        currentConfig.copyWith(width: width.clamp(1.0, 28.0));
    state = state.copyWith(brushConfigs: updatedConfigs);
  }

  void setOpacity(double opacity) {
    final currentConfig = state.currentBrushConfig;
    final updatedConfigs = Map<BrushType, BrushConfig>.from(state.brushConfigs);
    updatedConfigs[state.activeBrush] =
        currentConfig.copyWith(opacity: opacity.clamp(0.15, 1.0));
    state = state.copyWith(brushConfigs: updatedConfigs);
  }

  void setEraserMode(EraserMode mode) {
    state = state.copyWith(
      tool: SelectedTool.eraser,
      eraserMode: mode,
    );
  }

  void setEraserRadius(double radius) {
    state = state.copyWith(eraserRadius: radius.clamp(6.0, 48.0));
  }

  void setActiveShapeTool(RecognizedShape shape) {
    state = state.copyWith(
      tool: SelectedTool.shape,
      activeShapeTool: shape,
    );
  }

  void toggleSmartShapeHold() {
    state = state.copyWith(
      smartShapeHoldEnabled: !state.smartShapeHoldEnabled,
    );
  }

  void setPaperTemplate(PaperTemplate template) {
    state = state.copyWith(paperTemplate: template);
  }

  void setPaperTheme(PaperColorTheme theme) {
    state = state.copyWith(paperTheme: theme);
  }

  void addPage() {
    final newPageIndex = state.totalPages;
    state = state.copyWith(
      totalPages: state.totalPages + 1,
      currentPageIndex: newPageIndex,
      selectedStrokeIds: const {},
      zoomScale: 1.0,
      panOffset: Offset.zero,
    );
  }

  void nextPage() {
    if (state.currentPageIndex < state.totalPages - 1) {
      state = state.copyWith(
        currentPageIndex: state.currentPageIndex + 1,
        selectedStrokeIds: const {},
      );
    }
  }

  void previousPage() {
    if (state.currentPageIndex > 0) {
      state = state.copyWith(
        currentPageIndex: state.currentPageIndex - 1,
        selectedStrokeIds: const {},
      );
    }
  }

  void updateViewport({double? zoomScale, Offset? panOffset}) {
    state = state.copyWith(
      zoomScale: (zoomScale ?? state.zoomScale).clamp(0.5, 3.5),
      panOffset: panOffset ?? state.panOffset,
    );
  }

  void resetViewport() {
    state = state.copyWith(
      zoomScale: 1.0,
      panOffset: Offset.zero,
    );
  }

  void toggleStylusOnlyMode() {
    state = state.copyWith(
      stylusOnlyMode: !state.stylusOnlyMode,
      stylusToastMessage: !state.stylusOnlyMode
          ? 'وضع القلم فقط (رفض راحة اليد الكامل): مفعل'
          : 'الكتابة بالقلم واللمس معاً: مفعل',
    );
  }

  void toggleDebugOverlay() {
    state = state.copyWith(showDebugOverlay: !state.showDebugOverlay);
  }

  void updateDebugMetrics({
    required String deviceKind,
    required double pressure,
    required double tiltDegrees,
    Offset? cursorPosition,
  }) {
    state = state.copyWith(
      lastDeviceKind: deviceKind,
      lastPressure: pressure,
      lastTiltDegrees: tiltDegrees,
      activeCursorPosition: cursorPosition,
    );
  }
}

final canvasProvider =
    StateNotifierProvider<CanvasNotifier, CanvasState>((ref) {
  return CanvasNotifier();
});
