import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/handwriting/models/ink_stroke.dart';

/// Decoded Huawei Notes document bundle.
class SerializedNotebookData {
  final List<InkStroke> strokes;
  final PaperTemplate paperTemplate;
  final PaperColorTheme paperTheme;

  const SerializedNotebookData({
    required this.strokes,
    this.paperTemplate = PaperTemplate.ruled,
    this.paperTheme = PaperColorTheme.paperMatteWarm,
  });
}

/// Serializer responsible for persisting and restoring Huawei M-Pencil stroke data
/// and paper template settings to the local filesystem or clinical session JSON.
class StrokeSerializer {
  static const String _fileName = 'marsa_ink_test.json';
  static const String _webPrefsKey = 'marsa_ink_notebook_json_v2';
  static const int _formatVersion = 2;

  static Future<String> getFilePath() async {
    if (kIsWeb) {
      return 'localStorage://$_webPrefsKey';
    }
    final appDocDir = await getApplicationDocumentsDirectory();
    return p.join(appDocDir.path, _fileName);
  }

  static Future<File> _getFile() async {
    final path = await getFilePath();
    return File(path);
  }

  static Future<bool> hasSavedStrokes() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_webPrefsKey);
        return raw != null && raw.trim().isNotEmpty;
      }
      final file = await _getFile();
      return await file.exists();
    } catch (e) {
      debugPrint('[StrokeSerializer] Error checking file existence: $e');
      return false;
    }
  }

  /// Serializes strokes and paper template metadata to a JSON string.
  static String strokesToJson(
    List<InkStroke> strokes, {
    PaperTemplate paperTemplate = PaperTemplate.ruled,
    PaperColorTheme paperTheme = PaperColorTheme.paperMatteWarm,
  }) {
    final data = {
      'version': _formatVersion,
      'saved_at': DateTime.now().toIso8601String(),
      'paper_template': paperTemplate.name,
      'paper_theme': paperTheme.name,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  /// Deserializes strokes from a JSON string (supports v1 and v2).
  static List<InkStroke> strokesFromJson(String jsonString) {
    return notebookFromJson(jsonString).strokes;
  }

  /// Deserializes full notebook data (strokes + paper template + theme) from JSON.
  static SerializedNotebookData notebookFromJson(String jsonString) {
    try {
      if (jsonString.trim().isEmpty) {
        return const SerializedNotebookData(strokes: []);
      }
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final rawList = decoded['strokes'] as List<dynamic>? ?? [];
      final strokes = rawList
          .map((item) => InkStroke.fromJson(item as Map<String, dynamic>))
          .toList();
      final template = PaperTemplate.fromName(decoded['paper_template'] as String?);
      final theme = PaperColorTheme.fromName(decoded['paper_theme'] as String?);
      return SerializedNotebookData(
        strokes: strokes,
        paperTemplate: template,
        paperTheme: theme,
      );
    } catch (e) {
      debugPrint('[StrokeSerializer] Error parsing strokes from JSON: $e');
      return const SerializedNotebookData(strokes: []);
    }
  }

  static Future<bool> saveStrokes(
    List<InkStroke> strokes, {
    PaperTemplate paperTemplate = PaperTemplate.ruled,
    PaperColorTheme paperTheme = PaperColorTheme.paperMatteWarm,
  }) async {
    try {
      final data = {
        'version': _formatVersion,
        'saved_at': DateTime.now().toIso8601String(),
        'paper_template': paperTemplate.name,
        'paper_theme': paperTheme.name,
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(data);

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return await prefs.setString(_webPrefsKey, jsonString);
      }

      final file = await _getFile();
      await file.writeAsString(jsonString, flush: true);
      return true;
    } catch (e, stack) {
      debugPrint('[StrokeSerializer] Failed to save strokes: $e\n$stack');
      return false;
    }
  }

  static Future<List<InkStroke>?> loadStrokes() async {
    final notebook = await loadNotebook();
    return notebook?.strokes;
  }

  static Future<SerializedNotebookData?> loadNotebook() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(_webPrefsKey);
        if (content == null || content.trim().isEmpty) return null;
        return notebookFromJson(content);
      }

      final file = await _getFile();
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return const SerializedNotebookData(strokes: []);
      }

      return notebookFromJson(content);
    } catch (e, stack) {
      debugPrint('[StrokeSerializer] Failed to load notebook: $e\n$stack');
      return null;
    }
  }

  static Future<String?> readRawJson() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(_webPrefsKey);
      }
      final file = await _getFile();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }
}
