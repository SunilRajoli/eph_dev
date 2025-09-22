// lib/services/social_oauth.dart
import 'dart:async';
import 'dart:io' show Platform;
// import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';

class SocialOAuth {
  // Build oauth url on backend
  // Example: https://your-backend.com/auth/oauth/google
  // Pass optional redirect param if backend supports.
  static String oauthUrl(String provider, {String? backendHost}) {
    final host = backendHost ?? _defaultBackendHost();
    return '$host/auth/oauth/$provider';
  }

  // Default backend host used (change to LAN IP or production URL)
  static String _defaultBackendHost() {
    // For Android emulator use 10.0.2.2 -> backend at :3000
    // For real devices, pass explicit backendHost param to oauthUrl
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  // Start OAuth: open system browser and listen for deep-link callback that contains token
  // Returns the token string (or null if cancelled/failed).
  static Future<String?> startOAuth({
    required String provider,
    Duration timeout = const Duration(minutes: 2),
    String? backendHost,
  }) async {
    final url = oauthUrl(provider, backendHost: backendHost);
    final uri = Uri.parse(url);

    // open system browser
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open OAuth URL');
    }

    // Now listen for incoming links (deep link)
    StreamSubscription? sub;
    try {
      final completer = Completer<String?>();
      sub = uriLinkStream.listen((Uri? link) {
        if (link == null) return;
        // Expecting something like: eph://auth_callback?token=...&provider=google
        final token = link.queryParameters['token'];
        final p = link.queryParameters['provider'];
        if (token != null && p != null && p.toLowerCase() == provider.toLowerCase()) {
          if (!completer.isCompleted) completer.complete(token);
        }
      }, onError: (err) {
        if (!completer.isCompleted) completer.completeError(err);
      });

      return await completer.future.timeout(timeout, onTimeout: () {
        return null;
      });
    } finally {
      await sub?.cancel();
    }
  }
}
