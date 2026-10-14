import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/canvas_provider.dart';

/// Preset color options for clinical notes.
const List<({Color color, String label})> kPresetColors = [
  (color: Color(0xFF1E1E1E), label: 'أسود داكن'),
  (color: Color(0xFF1B4F72), label: 'أزرق كحلي'),
  (color: Color(0xFF922B21), label: 'أحمر داكن'),
];

/// Preset stroke width options.
const List<({double width, String label})> kPresetWidths = [
  (width: 2.0, label: 'رفيع (2.0)'),
  (width: 4.5, label: 'متوسط (4.5)'),
  (width: 8.0, label: 'عريض (8.0)'),
];

/// Vertical toolbar positioned on the right side of the tablet canvas.
class ToolBar extends ConsumerWidget {
  final VoidCallback onSave;
  final VoidCallback onLoad;

  const ToolBar({
    super.key,
    required this.onSave,
    required this.onLoad,
  });

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFF922B21)),
              SizedBox(width: 8),
              Text('مسح لوحة الرسم بالكامل؟'),
            ],
          ),
          content: const Text(
            'سيتم حذف جميع الخطوط والملاحظات المكتوبة على هذه الشاشة بشكل نهائي.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF922B21),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد المسح'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      ref.read(canvasProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);

    return Container(
      width: 68,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(-2, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE0D7C9),
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pen tool
            _ToolIconButton(
              icon: Icons.edit_rounded,
              tooltip: 'قلم الكتابة',
              isSelected: state.tool == SelectedTool.pen,
              onPressed: () => notifier.setTool(SelectedTool.pen),
            ),
            const SizedBox(height: 6),

            // Eraser tool
            _ToolIconButton(
              icon: Icons.auto_fix_high_rounded,
              tooltip: 'ممحاة',
              isSelected: state.tool == SelectedTool.eraser,
              onPressed: () => notifier.setTool(SelectedTool.eraser),
            ),

            const _ToolbarDivider(),

            // Preset Colors
            ...kPresetColors.map((item) {
              final isSelected = state.tool == SelectedTool.pen &&
                  state.currentColor.toARGB32() == item.color.toARGB32();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () => notifier.setColor(item.color),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2E86AB) : Colors.white,
                          width: isSelected ? 3.5 : 1.5,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: item.color.withAlpha(100),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const _ToolbarDivider(),

            // Width selectors
            ...kPresetWidths.map((item) {
              final isSelected = (state.baseWidth - item.width).abs() < 0.1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    onTap: () => notifier.setBaseWidth(item.width),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1B4F72).withAlpha(25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF1B4F72), width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Container(
                          width: item.width * 2.2,
                          height: item.width * 2.2,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1B4F72)
                                : const Color(0xFF757575),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),

            const _ToolbarDivider(),

            // Undo
            _ToolIconButton(
              icon: Icons.undo_rounded,
              tooltip: 'تراجع',
              isEnabled: state.canUndo,
              onPressed: () => notifier.undo(),
            ),
            const SizedBox(height: 6),

            // Redo
            _ToolIconButton(
              icon: Icons.redo_rounded,
              tooltip: 'إعادة',
              isEnabled: state.canRedo,
              onPressed: () => notifier.redo(),
            ),

            const _ToolbarDivider(),

            // Save to local file
            _ToolIconButton(
              icon: Icons.save_rounded,
              tooltip: 'حفظ الملاحظة',
              iconColor: const Color(0xFF1B4F72),
              onPressed: onSave,
            ),
            const SizedBox(height: 6),

            // Load from local file
            _ToolIconButton(
              icon: Icons.folder_open_rounded,
              tooltip: 'استرجاع آخر حفظ',
              iconColor: const Color(0xFF2E86AB),
              onPressed: onLoad,
            ),
            const SizedBox(height: 6),

            // Clear canvas
            _ToolIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'مسح اللوحة',
              iconColor: const Color(0xFF922B21),
              onPressed: () => _confirmClear(context, ref),
            ),

            const _ToolbarDivider(),

            // Toggle debug overlay
            _ToolIconButton(
              icon: state.showDebugOverlay
                  ? Icons.analytics_rounded
                  : Icons.analytics_outlined,
              tooltip: state.showDebugOverlay
                  ? 'إخفاء بيانات الحساسات'
                  : 'إظهار بيانات الحساسات',
              isSelected: state.showDebugOverlay,
              onPressed: () => notifier.toggleDebugOverlay(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isSelected;
  final bool isEnabled;
  final Color? iconColor;

  const _ToolIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isSelected = false,
    this.isEnabled = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = !isEnabled
        ? const Color(0xFFBDBDBD)
        : (isSelected
            ? Colors.white
            : (iconColor ?? const Color(0xFF2C3E50)));

    final effectiveBackground = isSelected
        ? const Color(0xFF1B4F72)
        : Colors.transparent;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: effectiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      height: 1,
      color: const Color(0xFFE8E0D5),
    );
  }
}
