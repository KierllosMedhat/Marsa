import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncState {
  synced,
  syncing,
  offlineSaved,
  conflict,
}

final localStoreProvider = Provider<LocalStore>((ref) {
  return LocalStore();
});

class LocalStore {
  static const String _keyToken = 'marsa_access_token';
  static const String _keyRefreshToken = 'marsa_refresh_token';
  static const String _keyStaffUser = 'marsa_staff_user';
  static const String _keyDraftNotes = 'marsa_draft_notes_';
  static const String _keyOfflineQueue = 'marsa_offline_queue';

  Future<void> saveAuth({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> staffUser,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyStaffUser, jsonEncode(staffUser));
  }

  Future<Map<String, dynamic>?> getSavedStaffUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyStaffUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyStaffUser);
  }

  Future<void> saveDraftNote(String sessionId, Map<String, dynamic> noteData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyDraftNotes$sessionId', jsonEncode(noteData));
    await addToSyncQueue({
      'type': 'draft_note',
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getDraftNote(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyDraftNotes$sessionId');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> addToSyncQueue(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyOfflineQueue) ?? [];
    list.add(jsonEncode(item));
    await prefs.setStringList(_keyOfflineQueue, list);
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyOfflineQueue) ?? [];
    return list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> clearSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOfflineQueue);
  }
}
