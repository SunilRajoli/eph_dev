// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static String get baseHost {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:3000";
    } else {
      return "http://localhost:3000";
    }
  }

  static String get baseUrl => "$baseHost/api/v1";

  static Future<Map<String, dynamic>> register(
      String name, String email, String password, {String? role}) async {
    final url = Uri.parse("$baseUrl/auth/register");

    final body = {
      "name": name,
      "email": email,
      "password": password,
    };
    if (role != null) body['role'] = role;

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    return _parseResponse(res);
  }

  // POST /auth/login with optional role
  static Future<Map<String,dynamic>> login(String email, String password, {String? role}) async {
    final url = Uri.parse("$baseUrl/auth/login");
    final body = {'email': email, 'password': password};
    if (role != null) body['role'] = role;
    final res = await http.post(url, headers: {"Content-Type":"application/json"}, body: jsonEncode(body));
    return _parseResponse(res);
  }

// Admin magic link
  static Future<Map<String,dynamic>> sendAdminMagicLink(String email) async {
    final url = Uri.parse("$baseUrl/auth/admin-magic-link"); // implement server-side
    final res = await http.post(url, headers: {"Content-Type":"application/json"}, body: jsonEncode({'email': email}));
    return _parseResponse(res);
  }

// Generic register accepting a payload (used above)
  static Future<Map<String,dynamic>> registerFromPayload(Map<String,dynamic> payload) async {
    final url = Uri.parse("$baseUrl/auth/register");
    final res = await http.post(url, headers: {"Content-Type":"application/json"}, body: jsonEncode(payload));
    return _parseResponse(res);
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final url = Uri.parse("$baseUrl/auth/forgot-password");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    return _parseResponse(res);
  }

  static Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    final url = Uri.parse("$baseUrl/auth/reset-password");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "token": token,
        "newPassword": newPassword
      }),
    );

    return _parseResponse(res);
  }

  // Profile requires Authorization header
  static Future<Map<String, dynamic>> getProfile(String token) async {
    final url = Uri.parse("$baseUrl/auth/profile");
    final res = await http.get(url, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token"
    });

    return _parseResponse(res);
  }

  // static Future<Map<String, dynamic>> uploadProfileImage(String token, File image) async {
  //   final uri = Uri.parse("$baseUrl/auth/profile/photo"); // ensure backend supports this
  //   final request = http.MultipartRequest('POST', uri);
  //   request.headers['Authorization'] = 'Bearer $token';
  //   request.files.add(await http.MultipartFile.fromPath('profile_pic', image.path));
  //   try {
  //     final streamed = await request.send();
  //     final res = await http.Response.fromStream(streamed);
  //     return _parseResponse(res);
  //   } catch (e) {
  //     return {
  //       'success': false,
  //       'message': 'Image upload failed: ${e.toString()}'
  //     };
  //   }
  // }

  static Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> payload) async {
    final url = Uri.parse("$baseUrl/auth/profile");
    final res = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload),
    );
    return _parseResponse(res);
  }

  // perks
  static Future<Map<String,dynamic>> getPerks({int page = 1, int limit = 50, String? search}) async {
    final query = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    final uri = Uri.parse("$baseUrl/perks").replace(queryParameters: query);
    final res = await http.get(uri, headers: {"Content-Type":"application/json"});
    return _parseResponse(res);
  }

  static Future<Map<String,dynamic>> redeemPerk(String perkId) async {
    final token = await AuthService.getToken();
    final url = Uri.parse("$baseUrl/perks/$perkId/redeem");
    final res = await http.post(url, headers: {
      "Content-Type":"application/json",
      if (token != null) "Authorization": "Bearer $token"
    });
    return _parseResponse(res);
  }


  static Future<Map<String, dynamic>> getCompetitions({
    String? filter,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (filter != null && filter.isNotEmpty) query['filter'] = filter;
    if (search != null && search.isNotEmpty) query['search'] = search;

    final uri = Uri.parse("$baseUrl/competitions").replace(queryParameters: query);

    final res = await http.get(
      uri,
      headers: {"Content-Type": "application/json"},
    );

    return _parseResponse(res);
  }

  // GET /competitions/:id
  static Future<Map<String, dynamic>> getCompetitionDetails(String competitionId) async {
    final uri = Uri.parse("$baseUrl/competitions/$competitionId");
    final res = await http.get(uri, headers: {"Content-Type": "application/json"});
    return _parseResponse(res);
  }

// POST /competitions/:id/register
// payload should include: type (individual|team), team_name, members (list of emails or user ids depending on API), abstract, etc.
// This endpoint requires Authorization header (so we include token if present)
  static Future<Map<String, dynamic>> registerForCompetition(String competitionId, Map<String, dynamic> payload) async {
    final uri = Uri.parse("$baseUrl/competitions/$competitionId/register");
    // try to include token if available
    String? token;
    try {
      token = await AuthService.getToken();
    } catch (_) {
      token = null;
    }

    final headers = {"Content-Type": "application/json"};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final res = await http.post(uri, headers: headers, body: jsonEncode(payload));
    return _parseResponse(res);
  }

  static Map<String, dynamic> _parseResponse(http.Response res) {
    final status = res.statusCode;
    try {
      final decoded = jsonDecode(res.body);
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      return {
        "success": status >= 200 && status < 300,
        "message": res.body,
      };
    }
  }
}
