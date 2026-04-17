import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class AppStorage {
  static const String _keyCredential = 'saved_credentials';
  static const String _keyTemplates = 'saved_templates';
  static const String _keyLastNip = 'last_nip';
  static const String _keyRememberMe = 'remember_me';

  // Simple encryption key - in production use flutter_secure_storage
  static final _encKey = encrypt.Key.fromLength(32);
  static final _encIV = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_encKey));

  static String _encrypt(String text) {
    return _encrypter.encrypt(text, iv: _encIV).base64;
  }

  static String _decrypt(String encrypted) {
    return _encrypter.decrypt64(encrypted, iv: _encIV);
  }

  // --- Credentials ---
  static Future<void> saveCredentials({
    required String nip,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCredential, jsonEncode({
      'nip': _encrypt(nip),
      'password': _encrypt(password),
    }));
    await prefs.setString(_keyLastNip, nip);
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
    if (!rememberMe) return null;

    final saved = prefs.getString(_keyCredential);
    if (saved == null) return null;

    try {
      final data = jsonDecode(saved);
      return {
        'nip': _decrypt(data['nip']),
        'password': _decrypt(data['password']),
      };
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getLastNip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastNip);
  }

  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, value);
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCredential);
  }

  // --- Templates ---
  static Future<void> saveTemplate(Map<String, dynamic> template) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getTemplates();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    template['id'] = id;
    template['created_at'] = DateTime.now().toIso8601String();
    templates.add(template);
    await prefs.setString(_keyTemplates, jsonEncode(templates));
  }

  static Future<List<Map<String, dynamic>>> getTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyTemplates);
    if (saved == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(saved);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteTemplate(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getTemplates();
    templates.removeWhere((t) => t['id'] == id);
    await prefs.setString(_keyTemplates, jsonEncode(templates));
  }

  static Future<void> updateTemplate(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final templates = await getTemplates();
    final idx = templates.indexWhere((t) => t['id'] == id);
    if (idx >= 0) {
      data['id'] = id;
      data['updated_at'] = DateTime.now().toIso8601String();
      templates[idx] = data;
      await prefs.setString(_keyTemplates, jsonEncode(templates));
    }
  }

  // --- Clear All ---
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
