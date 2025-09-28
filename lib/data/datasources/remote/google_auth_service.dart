import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import '../../../core/constants/google_config.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentAccount;

  GoogleSignInAccount? get currentAccount => _currentAccount;
  bool get isSignedIn => _currentAccount != null;
  String? get userEmail => _currentAccount?.email;
  String? get userName => _currentAccount?.displayName;
  String? get userPhotoUrl => _currentAccount?.photoUrl;

  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: GoogleConfig.webClientId,
          scopes: GoogleConfig.scopes,
        );
      } else {
        _googleSignIn = GoogleSignIn(
          clientId: GoogleConfig.desktopClientId,
          scopes: GoogleConfig.scopes,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _checkExistingSignIn() async {
    try {
      _currentAccount = await _googleSignIn?.signInSilently();
    } catch (e) {
      if (kDebugMode) {
        print('Nessun login esistente o token scaduto');
      }
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (_googleSignIn == null) {
        await initialize();
      }

      if (_googleSignIn == null) {
        throw Exception('Impossibile inizializzare Google Sign In');
      }

      try {
        await _googleSignIn!.signOut();
        _currentAccount = null;
      } catch (e) {
        if (kDebugMode) {
          print('Errore durante signOut: $e (ignorato)');
        }
      }

      _currentAccount = await _googleSignIn!.signIn();

      if (_currentAccount != null) {
        final granted = await _checkPermissions();
      }
      return _currentAccount;
    } catch (error) {
      if (error.toString().contains('sign_in_canceled') ||
          error.toString().contains('popup_closed_by_user')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
      _currentAccount = null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn?.disconnect();
      _currentAccount = null;

    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    try {
      if (_currentAccount == null) {
        return null;
      }
      
      final auth = await _currentAccount!.authentication;
      
      if (auth.accessToken == null) {
        return null;
      }
      
      return {
        'Authorization': 'Bearer ${auth.accessToken}',
        'X-Goog-AuthUser': '0',
      };
    } catch (e) {
      return null;
    }
  }

  Future<auth.AuthClient?> getAuthenticatedClient() async {
    try {
      if (_currentAccount == null) {
        await _checkExistingSignIn();

        if (_currentAccount == null) {
          _currentAccount = await signIn();
        }
      }

      if (_currentAccount == null) {
        return null;
      }

      final authentication = await _currentAccount!.authentication;

      if (authentication.accessToken == null) {
        return null;
      }

      final client = _GoogleAuthClient(
        accessToken: authentication.accessToken!,
        idToken: authentication.idToken,
      );

      return client;

    } catch (e) {
      return null;
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      if (_currentAccount == null) return false;
      final grantedScopes = await _googleSignIn?.requestScopes(GoogleConfig.scopes);

      return grantedScopes ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> refreshToken() async {
    try {
      if (_googleSignIn == null) return false;

      _currentAccount = await _googleSignIn!.signInSilently();
      
      if (_currentAccount != null) {
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  Map<String, String?> getUserInfo() {
    if (_currentAccount == null) {
      return {
        'email': null,
        'name': null,
        'id': null,
        'photoUrl': null,
      };
    }

    return {
      'email': _currentAccount!.email,
      'name': _currentAccount!.displayName,
      'id': _currentAccount!.id,
      'photoUrl': _currentAccount!.photoUrl,
    };
  }

  Future<void> resetAuthentication() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.disconnect();
        await _googleSignIn!.signOut();
      }

      _currentAccount = null;
      _googleSignIn = null;

    } catch (e) {
      if (kDebugMode) {
        print('Errore durante reset: $e (ignorato)');
      }
    }
  }
}

class _GoogleAuthClient extends http.BaseClient implements auth.AuthClient {
  final String accessToken;
  final String? idToken;
  final http.Client _client = http.Client();
  
  _GoogleAuthClient({
    required this.accessToken,
    this.idToken,
  });
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $accessToken';

    return _client.send(request);
  }
  
  @override
  void close() {
    _client.close();
  }
  
  @override
  get credentials => auth.AccessCredentials(
    auth.AccessToken(
      'Bearer',
      accessToken,
      DateTime.now().add(const Duration(hours: 1)).toUtc(),
    ),
    null,
    GoogleConfig.scopes,
  );
}