import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/stroke_serializer.dart';
import 'providers/canvas_provider.dart';
import 'widgets/ink_canvas.dart';
import 'widgets/tool_bar.dart';

/// Main screen showcasing the Phase 0.3 handwriting prototype.
///
/// Features a high-performance full-screen ink canvas, real-time stylus pressure
/// telemetry HUD, vertical Arabic RTL toolbar, and local stroke serialization.
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

    final success = await StrokeSerializer.saveStrokes(state.strokes);
    if (!context.mounted) return;

    if (success) {
      final path = await StrokeSerializer.getFilePath();
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF1B4F72),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF48C9B0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تم حفظ ${state.strokes.length} خط بنجاح.\nالمسار: $path',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF922B21),
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('حدث خطأ أثناء حفظ الخطوط إلى التخزين المحلي.'),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleLoad(BuildContext context, WidgetRef ref) async {
    final strokes = await StrokeSerializer.loadStrokes();
    if (!context.mounted) return;

    if (strokes != null) {
      ref.read(canvasProvider.notifier).loadStrokes(strokes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B4F72),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF48C9B0)),
              const SizedBox(width: 8),
              Text('تم استرجاع ${strokes.length} خط بنجاح من الملف المحلي.'),
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

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF1B4F72)),
              SizedBox(width: 8),
              Text('اختبار خط اليد — مرساة'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الهدف من النموذج الأولي:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '• التحقق من استجابة قلم Huawei M-Pencil على لوحي MatePad 11.5 PaperMatte.\n'
                  '• قراءة مستويات حساسية الضغط (4096 مستوى) وزاوية الميل.\n'
                  '• تفعيل آلية رفض راحة اليد (Palm Rejection) لضمان راحة الطبيب أثناء التدوين.\n'
                  '• حفظ واسترجاع الملاحظات محلياً بصيغة JSON.',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار خط اليد — مرساة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'معلومات النموذج الأولي',
            onPressed: () => _showInfoDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full-screen ink canvas (pure white drawing surface)
          const Positioned.fill(
            child: InkCanvas(
              backgroundColor: Colors.white,
            ),
          ),

          // 2. Hardware telemetry debug overlay (top-right, placed adjacent to toolbar)
          if (state.showDebugOverlay)
            Positioned(
              top: 16,
              right: 90,
              child: _DebugOverlay(state: state),
            ),

          // 3. Vertical toolbar on the right side (RTL layout)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Align(
              alignment: Alignment.centerRight,
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

/// Floating HUD widget showing live hardware metrics from the stylus.
class _DebugOverlay extends StatelessWidget {
  final CanvasState state;

  const _DebugOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xDD1B2631), // Semi-transparent deep slate
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF2E86AB).withAlpha(120),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'بيانات القلم والحساس',
                  style: TextStyle(
                    color: Color(0xFF48C9B0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.lastDeviceKind.contains('stylus')
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFF39C12),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          _DebugRow(
            label: 'نوع الجهاز',
            value: state.lastDeviceKind,
          ),
          _DebugRow(
            label: 'قيمة الضغط',
            value: state.lastPressure.toStringAsFixed(3),
            highlight: state.lastPressure > 0,
          ),
          // Visual pressure bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.lastPressure.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  state.lastPressure > 0.05
                      ? const Color(0xFF48C9B0)
                      : const Color(0xFF5D6D7E),
                ),
              ),
            ),
          ),
          _DebugRow(
            label: 'زاوية الميل',
            value: '${state.lastTiltDegrees.toStringAsFixed(1)}°',
          ),
          _DebugRow(
            label: 'نقاط الخط الحالي',
            value: '${state.currentStrokePointsCount}',
          ),
          _DebugRow(
            label: 'إجمالي الخطوط',
            value: '${state.totalStrokes}',
          ),
        ],
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _DebugRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFBDC3C7),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: highlight ? const Color(0xFFF1C40F) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
