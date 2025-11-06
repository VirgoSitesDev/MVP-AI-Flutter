import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/dropbox_config.dart';
import 'package:dio/dio.dart';
import 'dart:html' as html;
import 'package:crypto/crypto.dart';

class DropboxAuthService {
  static final DropboxAuthService _instance = DropboxAuthService._internal();
  factory DropboxAuthService() => _instance;
  DropboxAuthService._internal();

  final Dio _dio = Dio();
  String? _accessToken;
  String? _userEmail;
  String? _userName;

  bool get isAuthenticated => _accessToken != null;
  String? get accessToken => _accessToken;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  static const String _tokenKey = 'dropbox_access_token';
  static const String _emailKey = 'dropbox_user_email';
  static const String _nameKey = 'dropbox_user_name';

  /// Initialize and check if we have a stored token
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_tokenKey);
      _userEmail = prefs.getString(_emailKey);
      _userName = prefs.getString(_nameKey);

      if (_accessToken != null) {
        // Verify token is still valid
        final isValid = await _verifyToken();
        if (!isValid) {
          await signOut();
        }
      }
    } catch (e) {
      debugPrint('Error initializing Dropbox auth: $e');
    }
  }

  /// Start OAuth2 flow (for web)
  Future<bool> signIn() async {
    try {
      if (kIsWeb) {
        return await _signInWeb();
      } else {
        throw UnimplementedError('Dropbox auth only supported on web for now');
      }
    } catch (e) {
      debugPrint('Error signing in to Dropbox: $e');
      rethrow;
    }
  }

  Future<bool> _signInWeb() async {
    try {
      // Generate PKCE code verifier and challenge
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      // Store code verifier for later
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dropbox_code_verifier', codeVerifier);

      // Build authorization URL
      final authUrl = Uri.parse(DropboxConfig.authorizationEndpoint).replace(
        queryParameters: {
          'client_id': DropboxConfig.appKey,
          'response_type': 'code',
          'redirect_uri': DropboxConfig.redirectUri,
          'token_access_type': 'offline',  // Get refresh token
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      // Open popup window for OAuth
      final width = 500;
      final height = 600;
      final left = (html.window.screen!.width! - width) ~/ 2;
      final top = (html.window.screen!.height! - height) ~/ 2;

      final popup = html.window.open(
        authUrl.toString(),
        'Dropbox Authorization',
        'width=$width,height=$height,left=$left,top=$top',
      );

      if (popup == null) {
        throw Exception('Could not open authorization window. Please allow popups.');
      }

      // Listen for the OAuth callback
      final completer = Completer<bool>();

      late StreamSubscription subscription;
      subscription = html.window.onMessage.listen((event) async {
        try {
          debugPrint('📬 Received message event: ${event.data}');
          final data = event.data;
          if (data is Map && data['type'] == 'dropbox_oauth_callback') {
            debugPrint('✅ Dropbox OAuth callback received');
            final code = data['code'] as String?;
            final error = data['error'] as String?;

            if (error != null) {
              debugPrint('❌ OAuth error: $error');
              completer.complete(false);
            } else if (code != null) {
              debugPrint('✅ Authorization code received, exchanging for token...');
              // Exchange code for access token
              final success = await _exchangeCodeForToken(code, codeVerifier);
              completer.complete(success);
            } else {
              debugPrint('❌ No code or error in callback');
              completer.complete(false);
            }

            subscription.cancel();
            popup.close();
          }
        } catch (e) {
          debugPrint('❌ Error handling OAuth callback: $e');
          completer.complete(false);
          subscription.cancel();
        }
      });

      // Timeout after 5 minutes
      Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          subscription.cancel();
          popup.close();
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('Error in web sign in: $e');
      return false;
    }
  }

  Future<bool> _exchangeCodeForToken(String code, String codeVerifier) async {
    try {
      debugPrint('🔄 Exchanging authorization code for token...');
      debugPrint('Code: ${code.substring(0, 10)}...');

      final response = await _dio.post(
        DropboxConfig.tokenEndpoint,
        data: {
          'code': code,
          'grant_type': 'authorization_code',
          'client_id': DropboxConfig.appKey,
          'client_secret': DropboxConfig.appSecret,
          'redirect_uri': DropboxConfig.redirectUri,
          'code_verifier': codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      debugPrint('Token exchange response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        _accessToken = response.data['access_token'];
        debugPrint('✅ Access token received successfully');

        // Get user info
        await _fetchUserInfo();
        debugPrint('✅ User info fetched: $_userEmail');

        // Store token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _accessToken!);
        if (_userEmail != null) {
          await prefs.setString(_emailKey, _userEmail!);
        }
        if (_userName != null) {
          await prefs.setString(_nameKey, _userName!);
        }

        debugPrint('✅ Token and user info stored successfully');
        return true;
      }

      debugPrint('❌ Token exchange failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Error exchanging code for token: $e');
      if (e is DioException) {
        debugPrint('Response data: ${e.response?.data}');
        debugPrint('Status code: ${e.response?.statusCode}');
      }
      return false;
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      final response = await _dio.post(
        '${DropboxConfig.apiEndpoint}/users/get_current_account',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _userEmail = data['email'];
        _userName = data['name']?['display_name'];
      }
    } catch (e) {
      debugPrint('Error fetching user info: $e');
    }
  }

  Future<bool> _verifyToken() async {
    if (_accessToken == null) return false;

    try {
      final response = await _dio.post(
        '${DropboxConfig.apiEndpoint}/users/get_current_account',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_accessToken',
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _userEmail = null;
    _userName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
  }

  String _generateCodeVerifier() {
    final random = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64UrlEncode(random).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
