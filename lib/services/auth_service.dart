// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Use a single instance of FlutterSecureStorage
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Keys
  static const String _keyToken = 'eph_jwt_token';
  static const String _keyUser = 'eph_user_json';

  // Save token
  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
  }

  // Get token
  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _keyToken);
  }

  // Remove token
  static Future<void> clearToken() async {
    await _secureStorage.delete(key: _keyToken);
    await _secureStorage.delete(key: _keyUser);
  }

  // Save user object as JSON string (optional)
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final jsonStr = jsonEncode(user);
    await _secureStorage.write(key: _keyUser, value: jsonStr);
  }

  // Get user
  static Future<Map<String, dynamic>?> getUser() async {
    final s = await _secureStorage.read(key: _keyUser);
    if (s == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(s));
    } catch (e) {
      return null;
    }
  }
}
