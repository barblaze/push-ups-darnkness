import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'session.dart';

abstract class GameStorage {
  Future<PersistedData> load();

  Future<void> save(PersistedData data);
}

class PrefsGameStorage implements GameStorage {
  static const _key = 'pq_data_v1';

  @override
  Future<PersistedData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return PersistedData.empty;
    try {
      return PersistedData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PersistedData.empty;
    }
  }

  @override
  Future<void> save(PersistedData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }
}
