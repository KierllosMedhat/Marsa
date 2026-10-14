import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marsa_app/main.dart';
import 'package:marsa_app/features/handwriting/models/ink_point.dart';
import 'package:marsa_app/features/handwriting/models/ink_stroke.dart';
import 'package:marsa_app/features/handwriting/widgets/ink_canvas.dart';
import 'package:marsa_app/features/handwriting/widgets/tool_bar.dart';

void main() {
  group('Handwriting Models Serialization Tests', () {
    test('InkPoint toJson and fromJson preserve precision and data', () {
      final point = InkPoint(
        x: 120.5,
        y: 340.75,
        pressure: 0.842,
        tiltX: 12.5,
        tiltY: -8.3,
        timestamp: 1697280000000,
      );

      final json = point.toJson();
      expect(json['x'], 120.5);
      expect(json['y'], 340.75);
      expect(json['pressure'], 0.842);
      expect(json['tilt_x'], 12.5);
      expect(json['tilt_y'], -8.3);
      expect(json['timestamp'], 1697280000000);

      final restored = InkPoint.fromJson(json);
      expect(restored.x, point.x);
      expect(restored.y, point.y);
      expect(restored.pressure, point.pressure);
      expect(restored.tiltX, point.tiltX);
      expect(restored.tiltY, point.tiltY);
      expect(restored.timestamp, point.timestamp);
    });

    test('InkStroke toJson and fromJson encode color hex properly', () {
      final stroke = InkStroke(
        id: 'stroke_test_1',
        points: [
          const InkPoint(x: 10, y: 20, pressure: 0.5, timestamp: 100),
          const InkPoint(x: 30, y: 40, pressure: 0.9, timestamp: 200),
        ],
        color: const Color(0xFF1B4F72),
        baseWidth: 4.5,
        isEraser: false,
      );

      final json = stroke.toJson();
      expect(json['id'], 'stroke_test_1');
      expect(json['color'], '#1B4F72');
      expect(json['base_width'], 4.5);
      expect(json['is_eraser'], false);
      expect((json['points'] as List).length, 2);

      final restored = InkStroke.fromJson(json);
      expect(restored.id, stroke.id);
      expect(restored.color.toARGB32(), stroke.color.toARGB32());
      expect(restored.baseWidth, stroke.baseWidth);
      expect(restored.isEraser, stroke.isEraser);
      expect(restored.points.length, 2);
    });
  });

  group('Handwriting Widget Smoke Tests', () {
    testWidgets('MarsaApp renders HandwritingScreen, Toolbar and Canvas',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MarsaApp(),
        ),
      );

      // Verify app bar title
      expect(find.text('اختبار خط اليد — مرساة'), findsOneWidget);

      // Verify ink canvas and tool bar presence
      expect(find.byType(InkCanvas), findsOneWidget);
      expect(find.byType(ToolBar), findsOneWidget);

      // Verify debug overlay presence
      expect(find.text('بيانات القلم والحساس'), findsOneWidget);
      expect(find.text('نوع الجهاز'), findsOneWidget);
      expect(find.text('قيمة الضغط'), findsOneWidget);
    });
  });
}
