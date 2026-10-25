import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ink_stroke.dart';
import '../providers/canvas_provider.dart';

/// Preset clinical & Huawei Notes ink colors.
const List<({Color color, String label})> kHuaweiInkColors = [
  (color: Color(0xFF1E1E1E), label: 'أسود فحمي'),
  (color: Color(0xFF1B4F72), label: 'أزرق مرساة كحلي'),
  (color: Color(0xFF0284C7), label: 'أزرق سماوي'),
  (color: Color(0xFFDC2626), label: 'أحمر إكلينيكي'),
  (color: Color(0xFF15803D), label: 'أخضر زمردي'),
  (color: Color(0xFF7C3AED), label: 'بنفسجي'),
  (color: Color(0xFFD97706), label: 'عنبري ذهبي'),
  (color: Color(0xFF475569), label: 'رمادي رصاصي'),
  (color: Color(0xFFFACC15), label: 'أصفر تظليل'),
  (color: Color(0xFF4ADE80), label: 'أخضر تظليل'),
];

enum _ActivePopover {
  none,
  brushSettings,
  eraserSettings,
  shapeSettings,
  paperSettings,
  mPencilSettings,
}

/// Authentic Huawei Notes Floating Top Toolbar & Popover System.
///
/// Designed for Huawei MatePad 11.5 PaperMatte & Huawei M-Pencil.
class ToolBar extends ConsumerStatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onLoad;

  const ToolBar({
    super.key,
    required this.onSave,
    required this.onLoad,
  });

  @override
  ConsumerState<ToolBar> createState() => _ToolBarState();
}

class _ToolBarState extends ConsumerState<ToolBar> {
  _ActivePopover _openPopover = _ActivePopover.none;

  void _togglePopover(_ActivePopover popover) {
    setState(() {
      _openPopover = (_openPopover == popover) ? _ActivePopover.none : popover;
    });
  }

  void _closePopover() {
    if (_openPopover != _ActivePopover.none) {
      setState(() => _openPopover = _ActivePopover.none);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    _closePopover();
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
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('مسح الصفحة الحالية بالكامل؟'),
            ],
          ),
          content: const Text(
            'سيتم مسح جميع الخطوط في هذه الصفحة (يمكنك التراجع عن المسح بزر التراجع Undo).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('مسح الصفحة'),
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
  Widget build(BuildContext context) {
    final state = ref.watch(canvasProvider);
    final notifier = ref.read(canvasProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Main Floating Huawei Notes Dock
        Container(
          constraints: const BoxConstraints(maxWidth: 980),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD6D0C4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(24),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Undo / Redo
                _DockIconButton(
                  icon: Icons.undo_rounded,
                  tooltip: 'تراجع (أو لمس إصبعين)',
                  isEnabled: state.canUndo,
                  onTap: notifier.undo,
                ),
                _DockIconButton(
                  icon: Icons.redo_rounded,
                  tooltip: 'إعادة (أو لمس 3 أصابع)',
                  isEnabled: state.canRedo,
                  onTap: notifier.redo,
                ),

                const _VerticalDockDivider(),

                // 4 Signature Huawei Notes Brushes
                for (final brush in const [
                  BrushType.fountain,
                  BrushType.ballpoint,
                  BrushType.pencil,
                  BrushType.highlighter,
                ])
                  _HuaweiBrushButton(
                    brush: brush,
                    color: (state.brushConfigs[brush]?.color) ??
                        const Color(0xFF1B4F72),
                    isSelected:
                        state.tool == SelectedTool.pen && state.activeBrush == brush,
                    onTap: () {
                      if (state.tool == SelectedTool.pen &&
                          state.activeBrush == brush) {
                        _togglePopover(_ActivePopover.brushSettings);
                      } else {
                        notifier.setBrush(brush);
                        setState(() => _openPopover = _ActivePopover.brushSettings);
                      }
                    },
                  ),

                const _VerticalDockDivider(),

                // Quick Color Swatches + Brush Settings Trigger
                for (final item in kHuaweiInkColors.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        notifier.setColor(item.color);
                        _closePopover();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: state.currentColor.toARGB32() ==
                                    item.color.toARGB32()
                                ? const Color(0xFF0284C7)
                                : Colors.white,
                            width: state.currentColor.toARGB32() ==
                                    item.color.toARGB32()
                                ? 2.8
                                : 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Brush Palette & Width Sliders Button
                _DockIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'خصائص القلم والسمك والشفافية',
                  isSelected: _openPopover == _ActivePopover.brushSettings,
                  onTap: () => _togglePopover(_ActivePopover.brushSettings),
                ),

                const _VerticalDockDivider(),

                // Eraser Tool (Tap to activate, tap again for Stroke vs Pixel mode)
                _DockIconButton(
                  icon: Icons.cleaning_services_rounded,
                  tooltip: 'ممحاة ذكية (${state.eraserMode.labelAr})',
                  isSelected: state.tool == SelectedTool.eraser,
                  badgeText: state.eraserMode == EraserMode.pixel ? 'دقيقة' : null,
                  onTap: () {
                    if (state.tool == SelectedTool.eraser) {
                      _togglePopover(_ActivePopover.eraserSettings);
                    } else {
                      notifier.setTool(SelectedTool.eraser);
                      setState(() => _openPopover = _ActivePopover.eraserSettings);
                    }
                  },
                ),

                // Lasso Freehand Selection Tool
                _DockIconButton(
                  icon: Icons.gesture_rounded,
                  tooltip: 'أداة التحديد الحر والتحريك (Lasso)',
                  isSelected: state.tool == SelectedTool.lasso,
                  onTap: () {
                    _closePopover();
                    notifier.setTool(SelectedTool.lasso);
                  },
                ),

                // Smart Shapes Tool & Hold-to-Shape
                _DockIconButton(
                  icon: Icons.category_rounded,
                  tooltip: 'الأشكال الهندسية الذكية',
                  isSelected: state.tool == SelectedTool.shape ||
                      _openPopover == _ActivePopover.shapeSettings,
                  onTap: () => _togglePopover(_ActivePopover.shapeSettings),
                ),

                // Laser Pointer
                _DockIconButton(
                  icon: Icons.flare_rounded,
                  tooltip: 'مؤشر الليزر للشرح المؤقت',
                  iconColor: const Color(0xFFDC2626),
                  isSelected: state.tool == SelectedTool.laser,
                  onTap: () {
                    _closePopover();
                    notifier.setTool(SelectedTool.laser);
                  },
                ),

                const _VerticalDockDivider(),

                // Paper Templates & PaperMatte Theme
                _DockIconButton(
                  icon: Icons.description_outlined,
                  tooltip: 'قوالب الورق وراحة العين (PaperMatte)',
                  isSelected: _openPopover == _ActivePopover.paperSettings,
                  onTap: () => _togglePopover(_ActivePopover.paperSettings),
                ),

                // Multi-page navigator pill
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: state.currentPageIndex > 0
                            ? notifier.previousPage
                            : null,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: state.currentPageIndex > 0
                              ? const Color(0xFF1E293B)
                              : Colors.grey.shade400,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '${state.currentPageIndex + 1}/${state.totalPages}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: state.currentPageIndex < state.totalPages - 1
                            ? notifier.nextPage
                            : notifier.addPage,
                        child: Tooltip(
                          message: state.currentPageIndex < state.totalPages - 1
                              ? 'الصفحة التالية'
                              : 'إضافة صفحة جديدة',
                          child: Icon(
                            state.currentPageIndex < state.totalPages - 1
                                ? Icons.chevron_left
                                : Icons.add_rounded,
                            size: 18,
                            color: const Color(0xFF1B4F72),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const _VerticalDockDivider(),

                // Huawei M-Pencil Hardware & Palm Rejection Settings
                _DockIconButton(
                  icon: state.stylusOnlyMode
                      ? Icons.back_hand_outlined
                      : Icons.edit_attributes_rounded,
                  tooltip: 'إعدادات قلم Huawei M-Pencil ورفض راحة اليد',
                  isSelected: _openPopover == _ActivePopover.mPencilSettings ||
                      state.stylusOnlyMode,
                  onTap: () => _togglePopover(_ActivePopover.mPencilSettings),
                ),

                // Save to Session / Storage
                _DockIconButton(
                  icon: Icons.save_rounded,
                  tooltip: 'حفظ الملاحظة اليدوية',
                  iconColor: const Color(0xFF1B4F72),
                  onTap: () {
                    _closePopover();
                    widget.onSave();
                  },
                ),

                // Load Saved
                _DockIconButton(
                  icon: Icons.folder_open_rounded,
                  tooltip: 'استرجاع الملاحظات المحفوظة',
                  iconColor: const Color(0xFF0284C7),
                  onTap: () {
                    _closePopover();
                    widget.onLoad();
                  },
                ),
              ],
            ),
          ),
        ),

        // 2. Popover Card Below Dock
        if (_openPopover != _ActivePopover.none)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildActivePopoverCard(context, state, notifier),
          ),
      ],
    );
  }

  Widget _buildActivePopoverCard(
    BuildContext context,
    CanvasState state,
    CanvasNotifier notifier,
  ) {
    return Container(
      width: 390,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6D0C4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: switch (_openPopover) {
        _ActivePopover.brushSettings =>
          _buildBrushPopover(state, notifier),
        _ActivePopover.eraserSettings =>
          _buildEraserPopover(context, state, notifier),
        _ActivePopover.shapeSettings =>
          _buildShapePopover(state, notifier),
        _ActivePopover.paperSettings =>
          _buildPaperPopover(state, notifier),
        _ActivePopover.mPencilSettings =>
          _buildMPencilPopover(state, notifier),
        _ActivePopover.none => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildBrushPopover(CanvasState state, CanvasNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'خصائص ${state.activeBrush.labelAr} (${state.activeBrush.labelEn})',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Color(0xFF1B4F72),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _closePopover,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Live Sinusoidal Stroke Preview
        Container(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            color: state.paperTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: CustomPaint(
            painter: _BrushPreviewPainter(
              color: state.currentColor,
              width: state.baseWidth,
              opacity: state.currentOpacity,
              brushType: state.activeBrush,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Stroke Width Slider
        Row(
          children: [
            const SizedBox(
              width: 55,
              child: Text('السمك:', style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: Slider(
                value: state.baseWidth.clamp(1.0, 24.0),
                min: 1.0,
                max: 24.0,
                activeColor: const Color(0xFF1B4F72),
                onChanged: notifier.setBaseWidth,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${state.baseWidth.toStringAsFixed(1)}px',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        // Opacity Slider
        Row(
          children: [
            const SizedBox(
              width: 55,
              child: Text('الشفافية:', style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: Slider(
                value: state.currentOpacity.clamp(0.15, 1.0),
                min: 0.15,
                max: 1.0,
                activeColor: const Color(0xFF0284C7),
                onChanged: notifier.setOpacity,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${(state.currentOpacity * 100).round()}%',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Full 10-color palette
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kHuaweiInkColors.map((item) {
            final isSel =
                state.currentColor.toARGB32() == item.color.toARGB32();
            return Tooltip(
              message: item.label,
              child: InkWell(
                onTap: () => notifier.setColor(item.color),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? const Color(0xFF0284C7) : Colors.grey.shade300,
                      width: isSel ? 3.0 : 1.2,
                    ),
                  ),
                  child: isSel
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEraserPopover(
    BuildContext context,
    CanvasState state,
    CanvasNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'إعدادات الممحاة الذكية (Huawei Notes)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Color(0xFF1B4F72),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _closePopover,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Stroke vs Pixel Eraser Radio Cards
        for (final mode in EraserMode.values)
          RadioListTile<EraserMode>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: mode,
            groupValue: state.eraserMode,
            activeColor: const Color(0xFF1B4F72),
            title: Text(
              mode.labelAr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            subtitle: Text(mode.descriptionAr, style: const TextStyle(fontSize: 11)),
            onChanged: (val) {
              if (val != null) notifier.setEraserMode(val);
            },
          ),

        // Eraser Radius Slider
        Row(
          children: [
            const Text('حجم الممحاة:', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: state.eraserRadius.clamp(6.0, 48.0),
                min: 6.0,
                max: 48.0,
                activeColor: const Color(0xFF1B4F72),
                onChanged: notifier.setEraserRadius,
              ),
            ),
            Text(
              '${state.eraserRadius.round()}px',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
            label: const Text(
              'مسح الصفحة الحالية بالكامل',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
            ),
            onPressed: () => _confirmClear(context),
          ),
        ),
      ],
    );
  }

  Widget _buildShapePopover(CanvasState state, CanvasNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الأشكال الذكية (Huawei Instant Shape)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Color(0xFF1B4F72),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _closePopover,
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'التثبيت في نهاية الخط لتحويله لشكل هندسي',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'ارسم خطاً أو مربعاً أو دائرة وثبّت رأس القلم لجزء من الثانية',
            style: TextStyle(fontSize: 11),
          ),
          value: state.smartShapeHoldEnabled,
          activeColor: const Color(0xFF1B4F72),
          onChanged: (_) => notifier.toggleSmartShapeHold(),
        ),
        const Divider(height: 12),
        const Text(
          'أو اختر أداة رسم شكل هندسي مباشر:',
          style: TextStyle(fontSize: 11.5, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final shape in const [
              RecognizedShape.line,
              RecognizedShape.arrow,
              RecognizedShape.rectangle,
              RecognizedShape.circle,
              RecognizedShape.triangle,
            ])
              ChoiceChip(
                label: Text(shape.labelAr, style: const TextStyle(fontSize: 12)),
                selected: state.tool == SelectedTool.shape &&
                    state.activeShapeTool == shape,
                onSelected: (_) {
                  notifier.setActiveShapeTool(shape);
                  _closePopover();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaperPopover(CanvasState state, CanvasNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'قوالب أوراق العيادة وراحة العين (PaperMatte)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Color(0xFF1B4F72),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _closePopover,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'تخطيط الورقة:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PaperTemplate.values.map((tpl) {
            return ChoiceChip(
              label: Text(tpl.labelAr, style: const TextStyle(fontSize: 11.5)),
              selected: state.paperTemplate == tpl,
              onSelected: (_) => notifier.setPaperTemplate(tpl),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        const Text(
          'لون الورقة (PaperMatte Display):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: PaperColorTheme.values.map((themeItem) {
            final isSel = state.paperTheme == themeItem;
            return Tooltip(
              message: themeItem.labelAr,
              child: InkWell(
                onTap: () => notifier.setPaperTheme(themeItem),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 42,
                  height: 32,
                  decoration: BoxDecoration(
                    color: themeItem.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF0284C7)
                          : Colors.grey.shade400,
                      width: isSel ? 2.8 : 1.2,
                    ),
                  ),
                  child: isSel
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: themeItem.isDark ? Colors.white : Colors.black87,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMPencilPopover(CanvasState state, CanvasNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_rounded, size: 18, color: Color(0xFF1B4F72)),
                SizedBox(width: 6),
                Text(
                  'إعدادات Huawei M-Pencil و MatePad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFF1B4F72),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _closePopover,
            ),
          ],
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'الكتابة بالقلم فقط (Strict Palm Rejection)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'عند التفعيل: القلم يكتب، واللمس بالإصبع يحرك الصفحة ويكبرها فقط',
            style: TextStyle(fontSize: 11),
          ),
          value: state.stylusOnlyMode,
          activeColor: const Color(0xFF1B4F72),
          onChanged: (_) => notifier.toggleStylusOnlyMode(),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'إظهار لوحة قياس الضغط (4096 مستوى) وزاوية الميل',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          value: state.showDebugOverlay,
          activeColor: const Color(0xFF1B4F72),
          onChanged: (_) => notifier.toggleDebugOverlay(),
        ),
        const Divider(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.touch_app_rounded, size: 16),
                label: const Text(
                  'اختبار النقر المزدوج (قلم ⇄ ممحاة)',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () {
                  notifier.triggerStylusDoubleTap();
                  _closePopover();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom vector Huawei Notes Brush button with animated elevation and ink color band.
class _HuaweiBrushButton extends StatelessWidget {
  final BrushType brush;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _HuaweiBrushButton({
    required this.brush,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _iconForBrush {
    switch (brush) {
      case BrushType.fountain:
        return Icons.history_edu_rounded;
      case BrushType.ballpoint:
        return Icons.edit_rounded;
      case BrushType.pencil:
        return Icons.create_rounded;
      case BrushType.highlighter:
        return Icons.border_color_rounded;
      case BrushType.laser:
        return Icons.flare_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${brush.labelAr} (اضغط مرتين للخصائص)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1B4F72).withAlpha(22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF1B4F72) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForBrush,
                size: 20,
                color: isSelected ? const Color(0xFF1B4F72) : const Color(0xFF334155),
              ),
              const SizedBox(height: 3),
              // Color indicator band on the pen barrel
              Container(
                width: 18,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isEnabled;
  final Color? iconColor;
  final String? badgeText;

  const _DockIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isSelected = false,
    this.isEnabled = true,
    this.iconColor,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final fg = !isEnabled
        ? Colors.grey.shade400
        : (isSelected ? Colors.white : (iconColor ?? const Color(0xFF1E293B)));
    final bg = isSelected ? const Color(0xFF1B4F72) : Colors.transparent;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 20, color: fg),
                  if (badgeText != null)
                    Positioned(
                      bottom: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            fontSize: 7,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalDockDivider extends StatelessWidget {
  const _VerticalDockDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE2E8F0),
    );
  }
}

/// Renders a live sinusoidal calligraphic preview of the selected Huawei brush.
class _BrushPreviewPainter extends CustomPainter {
  final Color color;
  final double width;
  final double opacity;
  final BrushType brushType;

  _BrushPreviewPainter({
    required this.color,
    required this.width,
    required this.opacity,
    required this.brushType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = color.withValues(
        alpha: brushType == BrushType.highlighter
            ? opacity.clamp(0.2, 0.5)
            : opacity,
      )
      ..strokeCap =
          brushType == BrushType.highlighter ? StrokeCap.square : StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (brushType == BrushType.pencil) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    }

    const int steps = 40;
    final padX = 24.0;
    final usableW = size.width - padX * 2;
    final midY = size.height / 2.0;

    for (int i = 0; i < steps - 1; i++) {
      final t1 = i / steps;
      final t2 = (i + 1) / steps;
      final x1 = padX + usableW * t1;
      final x2 = padX + usableW * t2;
      final y1 = midY + math.sin(t1 * math.pi * 2) * 8.0;
      final y2 = midY + math.sin(t2 * math.pi * 2) * 8.0;

      // Simulate pressure swell in the middle of the sinusoidal wave
      final pressureSim = math.sin(t1 * math.pi);
      paint.strokeWidth = brushType == BrushType.fountain
          ? width * (0.4 + 0.9 * pressureSim)
          : width;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrushPreviewPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.width != width ||
        oldDelegate.opacity != opacity ||
        oldDelegate.brushType != brushType;
  }
}
