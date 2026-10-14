import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ink_point.dart';
import '../models/ink_stroke.dart';

/// Available canvas tools.
enum SelectedTool {
  pen,
  eraser,
}

/// Immutable state holding the active drawing canvas data.
class CanvasState {
  final List<InkStroke> strokes;
  final InkStroke? currentStroke;
  final List<InkStroke> undoneStrokes;
  final SelectedTool tool;
  final Color currentColor;
  final double baseWidth;
  final bool showDebugOverlay;

  // Real-time debug metrics captured from hardware
  final String lastDeviceKind;
  final double lastPressure;
  final double lastTiltDegrees;

  const CanvasState({
    this.strokes = const [],
    this.currentStroke,
    this.undoneStrokes = const [],
    this.tool = SelectedTool.pen,
    this.currentColor = const Color(0xFF1B4F72), // Default clinic deep navy
    this.baseWidth = 4.0, // Default medium width
    this.showDebugOverlay = true,
    this.lastDeviceKind = 'none',
    this.lastPressure = 0.0,
    this.lastTiltDegrees = 0.0,
  });

  bool get canUndo => strokes.isNotEmpty;
  bool get canRedo => undoneStrokes.isNotEmpty;
  int get totalStrokes => strokes.length;
  int get currentStrokePointsCount => currentStroke?.points.length ?? 0;

  CanvasState copyWith({
    List<InkStroke>? strokes,
    InkStroke? currentStroke,
    bool clearCurrentStroke = false,
    List<InkStroke>? undoneStrokes,
    SelectedTool? tool,
    Color? currentColor,
    double? baseWidth,
    bool? showDebugOverlay,
    String? lastDeviceKind,
    double? lastPressure,
    double? lastTiltDegrees,
  }) {
    return CanvasState(
      strokes: strokes ?? this.strokes,
      currentStroke:
          clearCurrentStroke ? null : (currentStroke ?? this.currentStroke),
      undoneStrokes: undoneStrokes ?? this.undoneStrokes,
      tool: tool ?? this.tool,
      currentColor: currentColor ?? this.currentColor,
      baseWidth: baseWidth ?? this.baseWidth,
      showDebugOverlay: showDebugOverlay ?? this.showDebugOverlay,
      lastDeviceKind: lastDeviceKind ?? this.lastDeviceKind,
      lastPressure: lastPressure ?? this.lastPressure,
      lastTiltDegrees: lastTiltDegrees ?? this.lastTiltDegrees,
    );
  }
}

/// StateNotifier managing canvas drawing state, tool configuration,
/// undo/redo history, and stylus sensor debugging.
class CanvasNotifier extends StateNotifier<CanvasState> {
  CanvasNotifier() : super(const CanvasState());

  static int _idCounter = 0;

  String _generateStrokeId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _idCounter++;
    return 'stroke_${now}_$_idCounter';
  }

  /// Begins a new stroke when a pointer is pressed down.
  void startStroke(
    InkPoint point, {
    required String deviceKind,
    double tiltDegrees = 0.0,
  }) {
    final newStroke = InkStroke(
      id: _generateStrokeId(),
      points: [point],
      color: state.currentColor,
      baseWidth: state.baseWidth,
      isEraser: state.tool == SelectedTool.eraser,
    );

    state = state.copyWith(
      currentStroke: newStroke,
      lastDeviceKind: deviceKind,
      lastPressure: point.pressure,
      lastTiltDegrees: tiltDegrees,
    );
  }

  /// Adds a sampled point to the current stroke as the pointer moves.
  void addPoint(InkPoint point, {double tiltDegrees = 0.0}) {
    final active = state.currentStroke;
    if (active == null) return;

    final updatedPoints = List<InkPoint>.from(active.points)..add(point);
    final updatedStroke = active.copyWith(points: updatedPoints);

    state = state.copyWith(
      currentStroke: updatedStroke,
      lastPressure: point.pressure,
      lastTiltDegrees: tiltDegrees,
    );
  }

  /// Finalizes the current stroke on pointer release or cancellation.
  void endStroke() {
    final active = state.currentStroke;
    if (active == null) return;

    if (active.points.isNotEmpty) {
      final updatedStrokes = List<InkStroke>.from(state.strokes)..add(active);
      state = state.copyWith(
        strokes: updatedStrokes,
        clearCurrentStroke: true,
        undoneStrokes: const [], // New stroke invalidates redo stack
      );
    } else {
      state = state.copyWith(clearCurrentStroke: true);
    }
  }

  /// Undoes the last committed stroke.
  void undo() {
    if (state.strokes.isEmpty) return;

    final updatedStrokes = List<InkStroke>.from(state.strokes);
    final lastStroke = updatedStrokes.removeLast();
    final updatedUndone = List<InkStroke>.from(state.undoneStrokes)
      ..add(lastStroke);

    state = state.copyWith(
      strokes: updatedStrokes,
      undoneStrokes: updatedUndone,
    );
  }

  /// Redoes the most recently undone stroke.
  void redo() {
    if (state.undoneStrokes.isEmpty) return;

    final updatedUndone = List<InkStroke>.from(state.undoneStrokes);
    final restoredStroke = updatedUndone.removeLast();
    final updatedStrokes = List<InkStroke>.from(state.strokes)
      ..add(restoredStroke);

    state = state.copyWith(
      strokes: updatedStrokes,
      undoneStrokes: updatedUndone,
    );
  }

  /// Clears the entire canvas and redo history.
  void clear() {
    state = state.copyWith(
      strokes: const [],
      clearCurrentStroke: true,
      undoneStrokes: const [],
      lastPressure: 0.0,
      lastTiltDegrees: 0.0,
    );
  }

  /// Loads previously serialized strokes.
  void loadStrokes(List<InkStroke> loaded) {
    state = state.copyWith(
      strokes: List<InkStroke>.from(loaded),
      clearCurrentStroke: true,
      undoneStrokes: const [],
    );
  }

  /// Selects the active drawing tool (pen or eraser).
  void setTool(SelectedTool tool) {
    state = state.copyWith(tool: tool);
  }

  /// Sets the stroke color for the pen.
  void setColor(Color color) {
    state = state.copyWith(
      currentColor: color,
      tool: SelectedTool.pen, // Switching color automatically selects pen
    );
  }

  /// Sets the base stroke width.
  void setBaseWidth(double width) {
    state = state.copyWith(baseWidth: width);
  }

  /// Toggles the floating debug info HUD.
  void toggleDebugOverlay() {
    state = state.copyWith(showDebugOverlay: !state.showDebugOverlay);
  }

  /// Updates debug telemetry directly if pointer hovers or touches.
  void updateDebugMetrics({
    required String deviceKind,
    required double pressure,
    required double tiltDegrees,
  }) {
    state = state.copyWith(
      lastDeviceKind: deviceKind,
      lastPressure: pressure,
      lastTiltDegrees: tiltDegrees,
    );
  }
}

/// Riverpod provider for the canvas state and controller.
final canvasProvider =
    StateNotifierProvider<CanvasNotifier, CanvasState>((ref) {
  return CanvasNotifier();
});
