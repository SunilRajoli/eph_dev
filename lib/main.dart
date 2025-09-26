import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart'; // add to pubspec

import 'screens/splash_screen.dart';
import 'screens/main_nav.dart';
import 'screens/competition_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/competition_register_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/perks_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_theme.dart';
import 'screens/competition_submit_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const EPHApp());
}

class EPHApp extends StatefulWidget {
  const EPHApp({super.key});

  @override
  State<EPHApp> createState() => _EPHAppState();
}

class _EPHAppState extends State<EPHApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _sub;
  bool _handledInitialUri = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Skip uni_links on web or unsupported desktop platforms to avoid MissingPluginException.
    if (kIsWeb) {
      debugPrint('Deep links: running on Web — skipping uni_links.');
      return;
    }
    // Only call uni_links on platforms it supports (Android, iOS, macOS)
    final bool supportedPlatform =
        Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    if (!supportedPlatform) {
      debugPrint('Deep links: platform not supported by uni_links: ${Platform.operatingSystem}');
      return;
    }

    // Subscribe to uriLinkStream to receive incoming links while app is running.
    try {
      _sub = uriLinkStream.listen((Uri? uri) {
        if (uri != null) _handleIncomingUri(uri);
      }, onError: (err) {
        debugPrint('uriLinkStream error: $err');
      });
    } catch (e) {
      // Catch MissingPluginException or other issues
      debugPrint('Failed to subscribe to uriLinkStream: $e');
    }

    // Also handle initial uri (app launched from terminated state)
    _handleInitialUri();
  }

  Future<void> _handleInitialUri() async {
    if (_handledInitialUri) return;
    _handledInitialUri = true;

    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        debugPrint('Initial deep link: $initialUri');
        _handleIncomingUri(initialUri);
      }
    } on FormatException catch (err) {
      debugPrint('Malformed initial uri: $err');
    } catch (err) {
      // Could be MissingPluginException on unsupported platforms — just log
      debugPrint('getInitialUri failed (ignored): $err');
    }
  }

  void _handleIncomingUri(Uri uri) {
    debugPrint('Received deep link: $uri');

    // Accept formats:
    // eph://reset-password?token=abc
    // eph://auth_callback?token=abc&provider=google
    // https://app.eph-platform.com/reset-password?token=abc
    final path = uri.path;
    final token = uri.queryParameters['token'];
    final provider = uri.queryParameters['provider'];

    if (path.contains('reset-password') && token != null && token.isNotEmpty) {
      _handlePasswordReset(token);
      return;
    }

    if (path.contains('auth_callback') && token != null && token.isNotEmpty) {
      _handleOAuthCallback(token, provider);
      return;
    }

    // handle other deep link types here if needed
    debugPrint('Unhandled deep link: $uri');
  }

  void _handlePasswordReset(String token) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Avoid pushing duplicate reset screens with same token
    bool shouldPush = true;
    navigator.popUntil((route) {
      return true;
    });

    // Check current route arguments (best-effort)
    final ModalRoute? top = ModalRoute.of(navigator.context);
    if (top != null && top.settings.name == '/reset-password') {
      final args = top.settings.arguments;
      if (args is Map && args['token'] == token) {
        shouldPush = false;
      }
    }

    if (shouldPush) {
      // Push reset screen with token; screen should read token from ModalRoute.arguments
      navigator.pushNamed('/reset-password', arguments: {'token': token});
    } else {
      debugPrint('Deep link: reset-password with same token already active, skipping push.');
    }
  }

  void _handleOAuthCallback(String token, String? provider) async {
    debugPrint('OAuth callback received: token=$token, provider=$provider');

    try {
      // Save the token and redirect to main screen
      await AuthService.saveToken(token);

      // Try to get user info from token or make a profile request
      // For now, we'll just navigate to main and let splash screen handle user data

      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        // Clear navigation stack and go to main
        navigator.pushNamedAndRemoveUntil('/main', (route) => false);

        // Show success message
        final context = navigator.context;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully logged in with ${provider ?? 'OAuth'}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling OAuth callback: $e');

      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        final context = navigator.context;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OAuth login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        // Navigate back to login
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engineering Projects Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey, // important for deep link navigation
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/main': (context) => const MainNav(),
        '/competitions': (context) => const CompetitionScreen(),
        '/roles': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        // ResetPasswordScreen should read token from ModalRoute.of(context)!.settings.arguments
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/competitions/register': (context) => const CompetitionRegisterScreen(),
        '/competitions/submit': (context) => const CompetitionSubmitScreen(),
        '/feed': (context) => const FeedScreen(),
        '/perks': (context) => const PerksScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

// // lib/main.dart
// import 'dart:async';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'dart:io' show Platform;
//
// import 'package:flutter/material.dart';
// import 'package:uni_links/uni_links.dart'; // add to pubspec
//
// import 'screens/splash_screen.dart';
// import 'screens/main_nav.dart';
// import 'screens/competition_screen.dart';
// import 'screens/role_selection_screen.dart';
// import 'screens/login_screen.dart';
// import 'screens/register_screen.dart';
// import 'screens/forgot_password_screen.dart';
// import 'screens/reset_password_screen.dart';
// import 'screens/competition_register_screen.dart';
// import 'screens/feed_screen.dart';
// import 'screens/perks_screen.dart';
// import 'screens/profile_screen.dart';
// import 'screens/verify_email_screen.dart'; // <-- added
// import 'theme/app_theme.dart';
// import 'screens/competition_submit_screen.dart';
// import 'services/auth_service.dart';
//
// void main() {
//   runApp(const EPHApp());
// }
//
// class EPHApp extends StatefulWidget {
//   const EPHApp({super.key});
//
//   @override
//   State<EPHApp> createState() => _EPHAppState();
// }
//
// class _EPHAppState extends State<EPHApp> {
//   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
//   StreamSubscription? _sub;
//   bool _handledInitialUri = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initDeepLinks();
//   }
//
//   void _initDeepLinks() {
//     // Skip uni_links on web or unsupported desktop platforms to avoid MissingPluginException.
//     if (kIsWeb) {
//       debugPrint('Deep links: running on Web — skipping uni_links.');
//       return;
//     }
//     // Only call uni_links on platforms it supports (Android, iOS, macOS)
//     final bool supportedPlatform =
//         Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
//     if (!supportedPlatform) {
//       debugPrint('Deep links: platform not supported by uni_links: ${Platform.operatingSystem}');
//       return;
//     }
//
//     // Subscribe to uriLinkStream to receive incoming links while app is running.
//     try {
//       _sub = uriLinkStream.listen((Uri? uri) {
//         if (uri != null) _handleIncomingUri(uri);
//       }, onError: (err) {
//         debugPrint('uriLinkStream error: $err');
//       });
//     } catch (e) {
//       // Catch MissingPluginException or other issues
//       debugPrint('Failed to subscribe to uriLinkStream: $e');
//     }
//
//     // Also handle initial uri (app launched from terminated state)
//     _handleInitialUri();
//   }
//
//   Future<void> _handleInitialUri() async {
//     if (_handledInitialUri) return;
//     _handledInitialUri = true;
//
//     try {
//       final initialUri = await getInitialUri();
//       if (initialUri != null) {
//         debugPrint('Initial deep link: $initialUri');
//         _handleIncomingUri(initialUri);
//       }
//     } on FormatException catch (err) {
//       debugPrint('Malformed initial uri: $err');
//     } catch (err) {
//       // Could be MissingPluginException on unsupported platforms — just log
//       debugPrint('getInitialUri failed (ignored): $err');
//     }
//   }
//
//   void _handleIncomingUri(Uri uri) {
//     debugPrint('Received deep link: $uri');
//
//     // Accept formats:
//     // eph://reset-password?token=abc
//     // eph://auth_callback?token=abc&provider=google
//     // eph://verify-email?token=abc&email=me@x.com
//     // https://app.eph-platform.com/reset-password?token=abc
//     // https://app.eph-platform.com/verify-email?token=abc
//     final path = uri.path.toLowerCase();
//     final token = uri.queryParameters['token'];
//     final provider = uri.queryParameters['provider'];
//     final email = uri.queryParameters['email'];
//
//     // verify-email deep link: route into in-app VerifyEmailScreen
//     if (path.contains('verify-email') && token != null && token.isNotEmpty) {
//       _handleVerifyEmail(token, email);
//       return;
//     }
//
//     if (path.contains('reset-password') && token != null && token.isNotEmpty) {
//       _handlePasswordReset(token);
//       return;
//     }
//
//     if (path.contains('auth_callback') && token != null && token.isNotEmpty) {
//       _handleOAuthCallback(token, provider);
//       return;
//     }
//
//     // handle other deep link types here if needed
//     debugPrint('Unhandled deep link: $uri');
//   }
//
//   void _handleVerifyEmail(String token, String? email) {
//     final navigator = navigatorKey.currentState;
//     if (navigator == null) return;
//
//     // Avoid pushing duplicate verify-email screens with same token
//     bool shouldPush = true;
//     navigator.popUntil((route) {
//       return true;
//     });
//
//     final ModalRoute? top = ModalRoute.of(navigator.context);
//     if (top != null && top.settings.name == '/verify-email') {
//       final args = top.settings.arguments;
//       if (args is Map && args['token'] == token) {
//         shouldPush = false;
//       }
//     }
//
//     if (shouldPush) {
//       navigator.pushNamed('/verify-email', arguments: {'token': token, 'email': email});
//     } else {
//       debugPrint('Deep link: verify-email with same token already active, skipping push.');
//     }
//   }
//
//   void _handlePasswordReset(String token) {
//     final navigator = navigatorKey.currentState;
//     if (navigator == null) return;
//
//     // Avoid pushing duplicate reset screens with same token
//     bool shouldPush = true;
//     navigator.popUntil((route) {
//       return true;
//     });
//
//     // Check current route arguments (best-effort)
//     final ModalRoute? top = ModalRoute.of(navigator.context);
//     if (top != null && top.settings.name == '/reset-password') {
//       final args = top.settings.arguments;
//       if (args is Map && args['token'] == token) {
//         shouldPush = false;
//       }
//     }
//
//     if (shouldPush) {
//       // Push reset screen with token; screen should read token from ModalRoute.arguments
//       navigator.pushNamed('/reset-password', arguments: {'token': token});
//     } else {
//       debugPrint('Deep link: reset-password with same token already active, skipping push.');
//     }
//   }
//
//   void _handleOAuthCallback(String token, String? provider) async {
//     debugPrint('OAuth callback received: token=$token, provider=$provider');
//
//     try {
//       // Save the token and redirect to main screen
//       await AuthService.saveToken(token);
//
//       // Try to get user info from token or make a profile request
//       // For now, we'll just navigate to main and let splash screen handle user data
//
//       final navigator = navigatorKey.currentState;
//       if (navigator != null) {
//         // Clear navigation stack and go to main
//         navigator.pushNamedAndRemoveUntil('/main', (route) => false);
//
//         // Show success message
//         final context = navigator.context;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Successfully logged in with ${provider ?? 'OAuth'}!'),
//             backgroundColor: Colors.green,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } catch (e) {
//       debugPrint('Error handling OAuth callback: $e');
//
//       final navigator = navigatorKey.currentState;
//       if (navigator != null) {
//         final context = navigator.context;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('OAuth login failed: ${e.toString()}'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 5),
//           ),
//         );
//
//         // Navigate back to login
//         navigator.pushNamedAndRemoveUntil('/login', (route) => false);
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _sub?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Engineering Projects Hub',
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.lightTheme,
//       navigatorKey: navigatorKey, // important for deep link navigation
//       initialRoute: '/',
//       routes: {
//         '/': (context) => const SplashScreen(),
//         '/main': (context) => const MainNav(),
//         '/competitions': (context) => const CompetitionScreen(),
//         '/roles': (context) => const RoleSelectionScreen(),
//         '/login': (context) => const LoginScreen(),
//         '/register': (context) => const RegisterScreen(),
//         '/forgot-password': (context) => const ForgotPasswordScreen(),
//         // ResetPasswordScreen should read token from ModalRoute.of(context)!.settings.arguments
//         '/reset-password': (context) => const ResetPasswordScreen(),
//         '/competitions/register': (context) => const CompetitionRegisterScreen(),
//         '/competitions/submit': (context) => const CompetitionSubmitScreen(),
//         '/feed': (context) => const FeedScreen(),
//         '/perks': (context) => const PerksScreen(),
//         '/profile': (context) => const ProfileScreen(),
//
//         // Verify email route: we extract args and pass to the screen constructor
//         '/verify-email': (context) {
//           final args = ModalRoute.of(context)?.settings.arguments;
//           String? token;
//           String? email;
//           if (args is Map<String, dynamic>) {
//             token = args['token'] as String?;
//             email = args['email'] as String?;
//           }
//           return VerifyEmailScreen(token: token, email: email);
//         },
//       },
//     );
//   }
// }
