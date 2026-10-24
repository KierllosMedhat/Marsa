import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../features/handwriting/models/ink_stroke.dart';

/// Serializer responsible for persisting and restoring ink stroke data
/// to the local filesystem in JSON format.
class StrokeSerializer {
  static const String _fileName = 'marsa_ink_test.json';
  static const int _formatVersion = 1;

  /// Resolves the absolute path to the local ink test storage file.
  static Future<String> getFilePath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, _fileName);
  }

  static Future<File> _getFile() async {
    final path = await getFilePath();
    return File(path);
  }

  /// Checks if a saved strokes file exists.
  static Future<bool> hasSavedStrokes() async {
    try {
      final file = await _getFile();
      return await file.exists();
    } catch (e) {
      debugPrint('[StrokeSerializer] Error checking file existence: $e');
      return false;
    }
  }

  /// Serializes strokes to a JSON string.
  static String strokesToJson(List<InkStroke> strokes) {
    final data = {
      'version': _formatVersion,
      'saved_at': DateTime.now().toIso8601String(),
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  /// Deserializes strokes from a JSON string.
  static List<InkStroke> strokesFromJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final rawList = decoded['strokes'] as List<dynamic>? ?? [];
      return rawList
          .map((item) => InkStroke.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[StrokeSerializer] Error parsing strokes from JSON: $e');
      return [];
    }
  }

  /// Saves the list of [InkStroke]s to `{appDocDir}/marsa_ink_test.json`.
  static Future<bool> saveStrokes(List<InkStroke> strokes) async {
    try {
      final file = await _getFile();
      final data = {
        'version': _formatVersion,
        'saved_at': DateTime.now().toIso8601String(),
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(data);

      await file.writeAsString(jsonString, flush: true);
      debugPrint(
        '[StrokeSerializer] Successfully saved ${strokes.length} strokes to ${file.path}',
      );
      return true;
    } catch (e, stack) {
      debugPrint('[StrokeSerializer] Failed to save strokes: $e\n$stack');
      return false;
    }
  }

  /// Loads the list of [InkStroke]s from the local file.
  /// Returns `null` if the file doesn't exist or is corrupted.
  static Future<List<InkStroke>?> loadStrokes() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        debugPrint('[StrokeSerializer] No saved file found at ${file.path}');
        return null;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return <InkStroke>[];
      }

      final Map<String, dynamic> decoded = jsonDecode(content);
      final rawList = decoded['strokes'] as List<dynamic>? ?? [];

      final strokes = rawList
          .map((item) => InkStroke.fromJson(item as Map<String, dynamic>))
          .toList();

      debugPrint(
        '[StrokeSerializer] Successfully loaded ${strokes.length} strokes from ${file.path}',
      );
      return strokes;
    } catch (e, stack) {
      debugPrint('[StrokeSerializer] Failed to load strokes: $e\n$stack');
      return null;
    }
  }

  /// Reads raw JSON content for debugging or exporting.
  static Future<String?> readRawJson() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('[StrokeSerializer] Failed to read raw JSON: $e');
      return null;
    }
  }
}
