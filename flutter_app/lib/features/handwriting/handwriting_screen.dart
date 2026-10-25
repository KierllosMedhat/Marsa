import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/stroke_serializer.dart';
import 'providers/canvas_provider.dart';
import 'widgets/ink_canvas.dart';
import 'widgets/tool_bar.dart';

/// Standalone Huawei Notes & M-Pencil Studio Screen for Huawei MatePad 11.5 PaperMatte.
class HandwritingScreen extends ConsumerWidget {
  const HandwritingScreen({super.key});

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    final state = ref.read(canvasProvider);

    if (state.strokes.isEmpty && state.currentStroke == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('لا توجد خطوط مكتوبة لحفظها حالياً.'),
            ],
          ),
          backgroundColor: Color(0xFF2E86AB),
        ),
      );
      return;
    }

    final success = await StrokeSerializer.saveStrokes(
      state.strokes,
      paperTemplate: state.paperTemplate,
      paperTheme: state.paperTheme,
    );
    if (!context.mounted) return;

    if (success) {
      final path = await StrokeSerializer.getFilePath();
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF1B4F72),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF48C9B0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم حفظ ${state.strokes.length} خط (${state.totalPages} صفحات) بنجاح.\nالمسار: $path',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleLoad(BuildContext context, WidgetRef ref) async {
    final notebook = await StrokeSerializer.loadNotebook();
    if (!context.mounted) return;

    if (notebook != null) {
      ref.read(canvasProvider.notifier).loadStrokes(
            notebook.strokes,
            template: notebook.paperTemplate,
            theme: notebook.paperTheme,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B4F72),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF48C9B0)),
              const SizedBox(width: 8),
              Text('تم استرجاع ${notebook.strokes.length} خط بنجاح.'),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF757575),
          content: Row(
            children: [
              Icon(Icons.folder_off_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('لم يتم العثور على ملف ملاحظات محفوظ مسبقاً.'),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملاحظات مرساة الذكية (Huawei Notes — M-Pencil)'),
      ),
      body: Stack(
        children: [
          // 1. Full-screen Huawei Notes PaperMatte Canvas
          const Positioned.fill(
            child: InkCanvas(),
          ),

          // 2. Hardware telemetry debug overlay (bottom-right)
          if (state.showDebugOverlay)
            Positioned(
              bottom: 16,
              right: 16,
              child: _DebugOverlay(state: state),
            ),

          // 3. Top Floating Huawei Notes Dock
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: ToolBar(
                onSave: () => _handleSave(context, ref),
                onLoad: () => _handleLoad(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugOverlay extends StatelessWidget {
  final CanvasState state;

  const _DebugOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xDD1B2631),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2E86AB).withAlpha(120),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'بيانات قلم Huawei M-Pencil (4096 مستوى)',
            style: TextStyle(
              color: Color(0xFF48C9B0),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white24, height: 12),
          Text(
            'الجهاز: ${state.lastDeviceKind}',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'الضغط: ${(state.lastPressure * 4096).round()} / 4096 (${state.lastPressure.toStringAsFixed(3)})',
            style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
          ),
          Text(
            'زاوية الميل: ${state.lastTiltDegrees.toStringAsFixed(1)}°',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            'الفرشاة: ${state.activeBrush.labelAr} | الصفحة: ${state.currentPageIndex + 1}/${state.totalPages}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
