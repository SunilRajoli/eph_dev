// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // OAuth Methods

  // Get Google OAuth URL
  static Future<Map<String, dynamic>> getGoogleAuthUrl({String? redirectUri, String? state}) async {
    final url = Uri.parse("$baseUrl/auth/google");
    final query = <String, String>{};
    if (redirectUri != null) query['redirect_uri'] = redirectUri;
    if (state != null) query['state'] = state;

    final uri = url.replace(queryParameters: query);
    final res = await http.get(uri, headers: {"Content-Type": "application/json"});
    return _parseResponse(res);
  }

  // Get GitHub OAuth URL
  static Future<Map<String, dynamic>> getGitHubAuthUrl({String? redirectUri, String? state}) async {
    final url = Uri.parse("$baseUrl/auth/github");
    final query = <String, String>{};
    if (redirectUri != null) query['redirect_uri'] = redirectUri;
    if (state != null) query['state'] = state;

    final uri = url.replace(queryParameters: query);
    final res = await http.get(uri, headers: {"Content-Type": "application/json"});
    return _parseResponse(res);
  }

  // Exchange OAuth code for token (for mobile flows)
  static Future<Map<String, dynamic>> exchangeOAuthCode({
    required String code,
    required String provider, // 'google' or 'github'
    String? redirectUri,
  }) async {
    final url = Uri.parse("$baseUrl/auth/oauth/exchange");
    final body = {
      'code': code,
      'provider': provider,
    };
    if (redirectUri != null) body['redirect_uri'] = redirectUri;

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    return _parseResponse(res);
  }

  // Launch OAuth in browser (helper method)
  static Future<bool> launchOAuthUrl(String authUrl) async {
    final uri = Uri.parse(authUrl);
    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
    } catch (e) {
      print('Error launching OAuth URL: $e');
      return false;
    }
  }

  // Complete OAuth flow (helper method that combines URL generation and launching)
  static Future<Map<String, dynamic>> initiateOAuth(String provider, {String? state}) async {
    try {
      Map<String, dynamic> response;

      if (provider == 'google') {
        response = await getGoogleAuthUrl(state: state ?? 'mobile');
      } else if (provider == 'github') {
        response = await getGitHubAuthUrl(state: state ?? 'mobile');
      } else {
        return {'success': false, 'message': 'Unsupported OAuth provider: $provider'};
      }

      if (response['success'] == true && response['data'] != null) {
        final authUrl = response['data']['authUrl'];
        if (authUrl != null) {
          final launched = await launchOAuthUrl(authUrl);
          if (launched) {
            return {'success': true, 'message': 'OAuth flow initiated', 'authUrl': authUrl};
          } else {
            return {'success': false, 'message': 'Failed to launch OAuth URL'};
          }
        }
      }

      return response;
    } catch (e) {
      return {'success': false, 'message': 'OAuth initiation failed: ${e.toString()}'};
    }
  }

  // Admin magic link
  static Future<Map<String,dynamic>> sendAdminMagicLink(String email) async {
    final url = Uri.parse("$baseUrl/auth/admin-magic-link");
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

  static Future<Map<String, dynamic>> uploadSubmission({
    required File video,
    String? competitionId,
    String? title,
    String? summary,
    String? repoUrl,
    String? driveUrl,
    List<File>? attachments,
    File? zip,
    String? token,
  }) async {
    final uri = Uri.parse("$baseUrl/videos");

    final req = http.MultipartRequest('POST', uri);

    // Authorization
    token ??= await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    // fields
    if (competitionId != null) req.fields['competition_id'] = competitionId;
    if (title != null) req.fields['title'] = title;
    if (summary != null) req.fields['summary'] = summary;
    if (repoUrl != null) req.fields['repo_url'] = repoUrl;
    if (driveUrl != null) req.fields['drive_url'] = driveUrl;

    // tags if any - send as comma separated
    // req.fields['tags'] = tags?.join(',') ?? '';

    // video file
    final videoStream = http.ByteStream(video.openRead());
    final videoLength = await video.length();
    final videoMultipart = http.MultipartFile(
      'video',
      videoStream,
      videoLength,
      filename: video.path.split('/').last,
      contentType: MediaType('video', 'mp4'), // not required but useful
    );
    req.files.add(videoMultipart);

    // attachments (optional)
    if (attachments != null && attachments.isNotEmpty) {
      for (final f in attachments) {
        final stream = http.ByteStream(f.openRead());
        final len = await f.length();
        final mf = http.MultipartFile(
          'attachments', // field name for each attachment
          stream,
          len,
          filename: f.path.split('/').last,
          contentType: MediaType('application', 'octet-stream'),
        );
        req.files.add(mf);
      }
    }

    // zip file (optional)
    if (zip != null) {
      final zstream = http.ByteStream(zip.openRead());
      final zlen = await zip.length();
      final zmf = http.MultipartFile(
        'zip',
        zstream,
        zlen,
        filename: zip.path.split('/').last,
        contentType: MediaType('application', 'zip'),
      );
      req.files.add(zmf);
    }

    try {
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        try {
          final decoded = jsonDecode(resp.body);
          return Map<String, dynamic>.from(decoded);
        } catch (e) {
          return {'success': true, 'message': resp.body};
        }
      } else {
        try {
          final decoded = jsonDecode(resp.body);
          return Map<String, dynamic>.from(decoded);
        } catch (e) {
          return {'success': false, 'message': 'Upload failed: ${resp.statusCode} ${resp.reasonPhrase}', 'body': resp.body};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Upload exception: ${e.toString()}'};
    }
  }

  // Enhanced getFeed method with filter support
  static Future<Map<String, dynamic>?> getFeed({
    int page = 1,
    int limit = 12,
    String? token,
    String? filter, // Added filter parameter
    String? search, // Added search parameter
    String? tags, // Added tags parameter
    String? uploader, // Added uploader parameter
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Build query parameters
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    // Add optional parameters if provided
    if (filter != null && filter.isNotEmpty) {
      queryParams['filter'] = filter;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (tags != null && tags.isNotEmpty) {
      queryParams['tags'] = tags;
    }
    if (uploader != null && uploader.isNotEmpty) {
      queryParams['uploader'] = uploader;
    }

    final uri = Uri.parse('$baseUrl/videos/feed').replace(queryParameters: queryParams);

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // Add authorization header if token is available
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http.get(uri, headers: headers).timeout(timeout);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return Map<String, dynamic>.from(decoded);
      } else if (res.statusCode == 401) {
        // Handle unauthorized - token might be expired
        return {
          'success': false,
          'message': 'Unauthorized access. Please login again.',
          'statusCode': res.statusCode,
        };
      } else if (res.statusCode >= 400 && res.statusCode < 500) {
        // Client error - try to parse error message
        try {
          final decoded = jsonDecode(res.body);
          return Map<String, dynamic>.from(decoded);
        } catch (e) {
          return {
            'success': false,
            'message': 'Client error: ${res.statusCode} ${res.reasonPhrase}',
            'statusCode': res.statusCode,
          };
        }
      } else {
        // Server error
        return {
          'success': false,
          'message': 'Server error: ${res.statusCode} ${res.reasonPhrase}',
          'statusCode': res.statusCode,
        };
      }
    } on SocketException catch (se) {
      // Connection refused / network unreachable
      return {
        'success': false,
        'message': 'Network error connecting to ${uri.host}:${uri.port} — ${se.message}. '
            'If you run on Android emulator, make sure to use 10.0.2.2 (this client uses it automatically). '
            'If using a physical device, set your dev host IP in ApiService and ensure server listens on 0.0.0.0.'
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request to ${uri.toString()} timed out after ${timeout.inSeconds}s'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch feed: ${e.toString()}'
      };
    }
  }

  // Get video by ID
  static Future<Map<String, dynamic>?> getVideoById(
      String videoId, {
        String? token,
        Duration timeout = const Duration(seconds: 10),
      }) async {
    final uri = Uri.parse('$baseUrl/videos/$videoId');

    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http.get(uri, headers: headers).timeout(timeout);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return Map<String, dynamic>.from(decoded);
      } else {
        try {
          final decoded = jsonDecode(res.body);
          return Map<String, dynamic>.from(decoded);
        } catch (e) {
          return {
            'success': false,
            'message': 'Status ${res.statusCode}: ${res.reasonPhrase}',
            'statusCode': res.statusCode,
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch video: ${e.toString()}'
      };
    }
  }

  // Toggle video like
  static Future<Map<String, dynamic>?> toggleVideoLike(
      String videoId, {
        bool? liked,
        String? token,
        Duration timeout = const Duration(seconds: 10),
      }) async {
    final uri = Uri.parse('$baseUrl/videos/$videoId/like');

    try {
      token ??= await AuthService.getToken();

      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = <String, dynamic>{};
      if (liked != null) {
        body['liked'] = liked;
      }

      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(timeout);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return Map<String, dynamic>.from(decoded);
      } else {
        try {
          final decoded = jsonDecode(res.body);
          return Map<String, dynamic>.from(decoded);
        } catch (e) {
          return {
            'success': false,
            'message': 'Status ${res.statusCode}: ${res.reasonPhrase}',
            'statusCode': res.statusCode,
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to toggle like: ${e.toString()}'
      };
    }
  }

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
  static Future<Map<String, dynamic>> registerForCompetition(String competitionId, Map<String, dynamic> payload) async {
    final uri = Uri.parse("$baseUrl/competitions/$competitionId/register");
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
        "statusCode": status,
      };
    }
  }
}

// // lib/services/api_service.dart
// import 'dart:convert';
// import 'dart:io';
// import 'dart:async';
// import 'package:path/path.dart' as p;
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
// import 'auth_service.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// class ApiService {
//   // dev host helper
//   static String get baseHost {
//     if (Platform.isAndroid) {
//       return "http://10.0.2.2:3000";
//     } else {
//       return "http://localhost:3000";
//     }
//   }
//
//   static String get baseUrl => "$baseHost/api/v1";
//
//   // optional in-memory token to avoid frequent storage reads
//   static String? _authToken;
//
//   static void setAuthToken(String token) => _authToken = token;
//   static void clearAuthTokenFromMemory() => _authToken = null;
//
//   static Future<String?> _resolveToken([String? override]) async {
//     if (override != null && override.isNotEmpty) return override;
//     if (_authToken != null && _authToken!.isNotEmpty) return _authToken;
//     try {
//       final t = await AuthService.getToken();
//       if (t != null && t.isNotEmpty) {
//         _authToken = t;
//         return t;
//       }
//     } catch (_) {}
//     return null;
//   }
//
//   static Map<String, String> _jsonHeaders({String? token}) {
//     final headers = <String, String>{
//       'Content-Type': 'application/json',
//       'Accept': 'application/json',
//     };
//     if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
//     return headers;
//   }
//
//   static Map<String, dynamic> _parseResponse(http.Response res) {
//     final status = res.statusCode;
//     try {
//       final decoded = jsonDecode(res.body);
//       if (decoded is Map) {
//         return Map<String, dynamic>.from(decoded as Map);
//       } else {
//         return {'success': status >= 200 && status < 300, 'data': decoded};
//       }
//     } catch (e) {
//       return {
//         'success': status >= 200 && status < 300,
//         'message': res.body,
//         'error': 'parse_error: ${e.toString()}'
//       };
//     }
//   }
//
//   // ---------------------------
//   // Auth endpoints (various)
//   // ---------------------------
//
//   static Future<Map<String, dynamic>> registerFromPayload(Map<String, dynamic> payload) async {
//     final url = Uri.parse("$baseUrl/auth/register");
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode(payload));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> register(String name, String email, String password, {String? role}) async {
//     final url = Uri.parse("$baseUrl/auth/register");
//     final body = {'name': name, 'email': email, 'password': password};
//     if (role != null) body['role'] = role;
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode(body));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> login(String email, String password, {String? role}) async {
//     final url = Uri.parse("$baseUrl/auth/login");
//     final body = {'email': email, 'password': password};
//     if (role != null) body['role'] = role;
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode(body));
//     final parsed = _parseResponse(res);
//     // if token returned, persist in-memory (and optionally to storage outside)
//     try {
//       if (parsed['success'] == true && parsed['data'] != null) {
//         final data = parsed['data'] as Map<String, dynamic>;
//         if (data.containsKey('token') && data['token'] is String) {
//           setAuthToken(data['token'] as String);
//         } else if (parsed['token'] is String) {
//           setAuthToken(parsed['token'] as String);
//         }
//       }
//     } catch (_) {}
//     return parsed;
//   }
//
//   static Future<Map<String, dynamic>> verifyEmail(String token) async {
//     final url = Uri.parse("$baseUrl/auth/verify-email");
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode({'token': token}));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
//     final url = Uri.parse("$baseUrl/auth/resend-verification");
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode({'email': email}));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> forgotPassword(String email) async {
//     final url = Uri.parse("$baseUrl/auth/forgot-password");
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode({'email': email}));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
//     final url = Uri.parse("$baseUrl/auth/reset-password");
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode({'token': token, 'newPassword': newPassword}));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
//     final token = await _resolveToken();
//     final headers = _jsonHeaders(token: token);
//     final url = Uri.parse("$baseUrl/auth/change-password");
//     final res = await http.post(url, headers: headers, body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> logout() async {
//     final token = await _resolveToken();
//     final headers = _jsonHeaders(token: token);
//     final url = Uri.parse("$baseUrl/auth/logout");
//     try {
//       final res = await http.post(url, headers: headers);
//       // clear in-memory token; caller should clear persisted storage if desired
//       clearAuthTokenFromMemory();
//       return _parseResponse(res);
//     } catch (e) {
//       clearAuthTokenFromMemory();
//       return {'success': false, 'message': 'Network error', 'error': e.toString()};
//     }
//   }
//
//   // allow screens to call getProfile(token) (positional) — matches existing usage
//   static Future<Map<String, dynamic>> getProfile([String? token]) async {
//     token = await _resolveToken(token);
//     final url = Uri.parse("$baseUrl/auth/profile");
//     final res = await http.get(url, headers: _jsonHeaders(token: token));
//     return _parseResponse(res);
//   }
//
//   // screens call updateProfile(token, payload)
//   static Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> payload) async {
//     final effective = await _resolveToken(token);
//     final url = Uri.parse("$baseUrl/auth/profile");
//     final res = await http.put(url, headers: _jsonHeaders(token: effective), body: jsonEncode(payload));
//     return _parseResponse(res);
//   }
//
//   // consume magic token (deep link)
//   static Future<Map<String, dynamic>> consumeMagicToken(String token) async {
//     final url = Uri.parse("$baseUrl/auth/consume-magic");
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode({'token': token}));
//     final parsed = _parseResponse(res);
//     try {
//       if (parsed['success'] == true && parsed['data'] != null) {
//         final data = parsed['data'] as Map<String, dynamic>;
//         if (data['token'] is String) setAuthToken(data['token'] as String);
//       }
//     } catch (_) {}
//     return parsed;
//   }
//
//   static Future<Map<String, dynamic>> requestAdminMagicLink(String email) async {
//     final url = Uri.parse("$baseUrl/auth/admin-magic-link");
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode({'email': email}));
//     return _parseResponse(res);
//   }
//
//   // ---------------------------
//   // OAuth helpers
//   // ---------------------------
//
//   static Future<Map<String, dynamic>> getGoogleAuthUrl({String? redirectUri, String? state}) async {
//     final url = Uri.parse("$baseUrl/auth/google");
//     final query = <String, String>{};
//     if (redirectUri != null) query['redirect_uri'] = redirectUri;
//     if (state != null) query['state'] = state;
//     final uri = url.replace(queryParameters: query);
//     final res = await http.get(uri, headers: _jsonHeaders());
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> getGitHubAuthUrl({String? redirectUri, String? state}) async {
//     final url = Uri.parse("$baseUrl/auth/github");
//     final query = <String, String>{};
//     if (redirectUri != null) query['redirect_uri'] = redirectUri;
//     if (state != null) query['state'] = state;
//     final uri = url.replace(queryParameters: query);
//     final res = await http.get(uri, headers: _jsonHeaders());
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> exchangeOAuthCode({
//     required String code,
//     required String provider,
//     String? redirectUri,
//   }) async {
//     final url = Uri.parse("$baseUrl/auth/oauth/exchange");
//     final body = {'code': code, 'provider': provider};
//     if (redirectUri != null) body['redirect_uri'] = redirectUri;
//     final res = await http.post(url, headers: _jsonHeaders(), body: jsonEncode(body));
//     return _parseResponse(res);
//   }
//
//   static Future<bool> launchOAuthUrl(String authUrl) async {
//     final uri = Uri.parse(authUrl);
//     try {
//       return await launchUrl(uri, mode: LaunchMode.externalApplication, webViewConfiguration: const WebViewConfiguration(enableJavaScript: true, enableDomStorage: true));
//     } catch (_) {
//       return false;
//     }
//   }
//
//   static Future<Map<String, dynamic>> initiateOAuth(String provider, {String? state}) async {
//     try {
//       Map<String, dynamic> response;
//       if (provider == 'google') response = await getGoogleAuthUrl(state: state ?? 'mobile');
//       else if (provider == 'github') response = await getGitHubAuthUrl(state: state ?? 'mobile');
//       else return {'success': false, 'message': 'Unsupported OAuth provider: $provider'};
//
//       if (response['success'] == true && response['data'] != null) {
//         final authUrl = (response['data'] as Map<String, dynamic>)['authUrl'] as String?;
//         if (authUrl != null && authUrl.isNotEmpty) {
//           final launched = await launchOAuthUrl(authUrl);
//           return {'success': launched, 'message': launched ? 'OAuth launched' : 'Failed to launch OAuth URL', 'url': authUrl};
//         }
//       }
//       return response;
//     } catch (e) {
//       return {'success': false, 'message': 'OAuth initiation failed: ${e.toString()}'};
//     }
//   }
//
//   // ---------------------------
//   // Video / upload / feed
//   // ---------------------------
//
//   static Future<Map<String, dynamic>> uploadSubmission({
//     required File video,
//     String? competitionId,
//     String? title,
//     String? summary,
//     String? repoUrl,
//     String? driveUrl,
//     List<File>? attachments,
//     File? zip,
//     String? token,
//   }) async {
//     final uri = Uri.parse("$baseUrl/videos");
//     final req = http.MultipartRequest('POST', uri);
//
//     token = await _resolveToken(token);
//     if (token != null && token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
//
//     if (competitionId != null) req.fields['competition_id'] = competitionId;
//     if (title != null) req.fields['title'] = title;
//     if (summary != null) req.fields['summary'] = summary;
//     if (repoUrl != null) req.fields['repo_url'] = repoUrl;
//     if (driveUrl != null) req.fields['drive_url'] = driveUrl;
//
//     final videoStream = http.ByteStream(video.openRead());
//     final videoLength = await video.length();
//     final videoMultipart = http.MultipartFile('video', videoStream, videoLength, filename: p.basename(video.path), contentType: MediaType('video', 'mp4'));
//     req.files.add(videoMultipart);
//
//     if (attachments != null && attachments.isNotEmpty) {
//       for (final f in attachments) {
//         final stream = http.ByteStream(f.openRead());
//         final len = await f.length();
//         final mf = http.MultipartFile('attachments', stream, len, filename: p.basename(f.path), contentType: MediaType('application', 'octet-stream'));
//         req.files.add(mf);
//       }
//     }
//
//     if (zip != null) {
//       final zstream = http.ByteStream(zip.openRead());
//       final zlen = await zip.length();
//       final zmf = http.MultipartFile('zip', zstream, zlen, filename: p.basename(zip.path), contentType: MediaType('application', 'zip'));
//       req.files.add(zmf);
//     }
//
//     try {
//       final streamed = await req.send();
//       final resp = await http.Response.fromStream(streamed);
//       if (resp.statusCode >= 200 && resp.statusCode < 300) {
//         try {
//           return Map<String, dynamic>.from(jsonDecode(resp.body));
//         } catch (_) {
//           return {'success': true, 'message': resp.body};
//         }
//       } else {
//         try {
//           return Map<String, dynamic>.from(jsonDecode(resp.body));
//         } catch (_) {
//           return {'success': false, 'message': 'Upload failed: ${resp.statusCode} ${resp.reasonPhrase}', 'body': resp.body};
//         }
//       }
//     } catch (e) {
//       return {'success': false, 'message': 'Upload exception: ${e.toString()}'};
//     }
//   }
//
//   static Future<Map<String, dynamic>?> getFeed({int page = 1, int limit = 12, String? token, Duration timeout = const Duration(seconds: 10)}) async {
//     final uri = Uri.parse('$baseUrl/videos/feed?page=$page&limit=$limit');
//     try {
//       token ??= await _resolveToken();
//       final headers = <String, String>{'Accept': 'application/json'};
//       if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
//       final res = await http.get(uri, headers: headers).timeout(timeout);
//       if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body));
//       return {'success': false, 'message': 'Status ${res.statusCode}', 'raw': res.body};
//     } on SocketException catch (se) {
//       return {'success': false, 'message': 'Network error connecting to ${uri.host}:${uri.port} — ${se.message}. Make sure emulator/dev host is reachable.'};
//     } on TimeoutException {
//       return {'success': false, 'message': 'Request to ${uri.toString()} timed out after ${timeout.inSeconds}s'};
//     } catch (e) {
//       return {'success': false, 'message': 'Failed to fetch feed: ${e.toString()}'};
//     }
//   }
//
//   // ---------------------------
//   // Perks / competitions
//   // ---------------------------
//
//   static Future<Map<String, dynamic>> getPerks({int page = 1, int limit = 50, String? search}) async {
//     final query = {'page': page.toString(), 'limit': limit.toString()};
//     if (search != null && search.isNotEmpty) query['search'] = search;
//     final uri = Uri.parse("$baseUrl/perks").replace(queryParameters: query);
//     final res = await http.get(uri, headers: _jsonHeaders());
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> redeemPerk(String perkId) async {
//     final token = await _resolveToken();
//     final url = Uri.parse("$baseUrl/perks/$perkId/redeem");
//     final res = await http.post(url, headers: _jsonHeaders(token: token));
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> getCompetitions({String? filter, String? search, int page = 1, int limit = 20}) async {
//     final query = <String, String>{'page': page.toString(), 'limit': limit.toString()};
//     if (filter != null && filter.isNotEmpty) query['filter'] = filter;
//     if (search != null && search.isNotEmpty) query['search'] = search;
//     final uri = Uri.parse("$baseUrl/competitions").replace(queryParameters: query);
//     final res = await http.get(uri, headers: _jsonHeaders());
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> getCompetitionDetails(String competitionId) async {
//     final uri = Uri.parse("$baseUrl/competitions/$competitionId");
//     final res = await http.get(uri, headers: _jsonHeaders());
//     return _parseResponse(res);
//   }
//
//   static Future<Map<String, dynamic>> registerForCompetition(String competitionId, Map<String, dynamic> payload) async {
//     final token = await _resolveToken();
//     final uri = Uri.parse("$baseUrl/competitions/$competitionId/register");
//     final res = await http.post(uri, headers: _jsonHeaders(token: token), body: jsonEncode(payload));
//     return _parseResponse(res);
//   }
// }
