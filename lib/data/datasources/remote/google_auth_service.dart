// lib/data/datasources/remote/google_auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import '../../../core/constants/google_config.dart';

class GoogleAuthService {
  // Singleton pattern
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();
  
  // Google Sign In instance
  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentAccount;
  
  // Getters
  GoogleSignInAccount? get currentAccount => _currentAccount;
  bool get isSignedIn => _currentAccount != null;
  String? get userEmail => _currentAccount?.email;
  String? get userName => _currentAccount?.displayName;
  String? get userPhotoUrl => _currentAccount?.photoUrl;
  
  /// Inizializza il servizio Google Sign In
  Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('🔧 Inizializzazione Google Sign In...');
        print('🌐 Platform: ${kIsWeb ? "Web" : "Desktop"}');
      }

      // Configurazione diversa per Desktop vs Web
      if (kIsWeb) {
        _googleSignIn = GoogleSignIn(
          clientId: GoogleConfig.webClientId,
          scopes: GoogleConfig.scopes,
        );
        if (kDebugMode) {
          print('🔑 Web Client ID: ${GoogleConfig.webClientId}');
          print('📋 Scopes: ${GoogleConfig.scopes}');
        }
      } else {
        // Per Desktop
        _googleSignIn = GoogleSignIn(
          clientId: GoogleConfig.desktopClientId,
          scopes: GoogleConfig.scopes,
          // Per desktop, Google gestisce automaticamente il flusso OAuth
        );
        if (kDebugMode) {
          print('🔑 Desktop Client ID: ${GoogleConfig.desktopClientId}');
        }
      }

      // NON fare silent sign-in durante l'inizializzazione per evitare rate limiting
      // await _checkExistingSignIn();

      if (kDebugMode) {
        print('✅ Google Sign In inizializzato (senza silent auth)');
        print('❌ Nessun utente connesso - richiederà login manuale');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore inizializzazione Google Sign In: $e');
        print('📋 Stack trace: ${StackTrace.current}');
      }
      rethrow;
    }
  }
  
  /// Controlla se c'è già un login attivo
  Future<void> _checkExistingSignIn() async {
    try {
      // signInSilently tenta di riautenticare senza mostrare UI
      _currentAccount = await _googleSignIn?.signInSilently();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Nessun login esistente o token scaduto');
      }
    }
  }
  
  /// Effettua il login con Google (forzando UI manuale)
  Future<GoogleSignInAccount?> signIn() async {
    try {
      if (kDebugMode) {
        print('🔐 Avvio processo di login Google MANUALE...');
        print('🔍 GoogleSignIn instance: ${_googleSignIn != null ? "OK" : "NULL"}');
      }

      if (_googleSignIn == null) {
        if (kDebugMode) {
          print('❌ Google Sign In non inizializzato, provo a inizializzare...');
        }
        await initialize();
      }

      if (_googleSignIn == null) {
        throw Exception('Impossibile inizializzare Google Sign In');
      }

      // PRIMA: Disconnetti qualsiasi sessione esistente per evitare auto re-auth
      if (kDebugMode) {
        print('🧹 Pulizia sessioni esistenti...');
      }

      try {
        await _googleSignIn!.signOut();
        _currentAccount = null;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Errore durante signOut: $e (ignorato)');
        }
      }

      if (kDebugMode) {
        print('🚀 Chiamata signIn() con UI forzata...');
      }

      // Forza la UI di Google (non silent)
      _currentAccount = await _googleSignIn!.signIn();

      if (kDebugMode) {
        print('📤 Risposta signIn: ${_currentAccount != null ? "Account ricevuto" : "NULL"}');
      }

      if (_currentAccount != null) {
        if (kDebugMode) {
          print('✅ Login riuscito!');
          print('👤 Email: ${_currentAccount!.email}');
          print('👤 Nome: ${_currentAccount!.displayName}');
          print('🔑 ID: ${_currentAccount!.id}');
        }

        // Verifica che abbiamo tutti i permessi richiesti
        final granted = await _checkPermissions();
        if (kDebugMode) {
          print('🔐 Permessi concessi: $granted');
        }
      } else {
        if (kDebugMode) {
          print('❌ Login annullato dall\'utente o fallito');
        }
      }

      return _currentAccount;
    } catch (error) {
      if (kDebugMode) {
        print('❌ Errore durante il login: $error');
        print('📋 Error type: ${error.runtimeType}');
        print('📋 Stack trace: ${StackTrace.current}');
      }
      // Non rilanciare l'errore se l'utente ha solo annullato
      if (error.toString().contains('sign_in_canceled') ||
          error.toString().contains('popup_closed_by_user')) {
        return null;
      }
      rethrow;
    }
  }
  
  /// Effettua il logout
  Future<void> signOut() async {
    try {
      if (kDebugMode) {
        print('🚪 Logout da Google...');
      }
      
      await _googleSignIn?.signOut();
      _currentAccount = null;
      
      if (kDebugMode) {
        print('✅ Logout completato');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore durante il logout: $e');
      }
      rethrow;
    }
  }
  
  /// Disconnetti completamente l'account (revoca i permessi)
  Future<void> disconnect() async {
    try {
      if (kDebugMode) {
        print('🔌 Disconnessione completa da Google...');
      }
      
      await _googleSignIn?.disconnect();
      _currentAccount = null;
      
      if (kDebugMode) {
        print('✅ Disconnessione completata');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore durante la disconnessione: $e');
      }
      rethrow;
    }
  }
  
  /// Ottieni gli header di autenticazione per le API Google
  Future<Map<String, String>?> getAuthHeaders() async {
    try {
      if (_currentAccount == null) {
        if (kDebugMode) {
          print('⚠️ Nessun account connesso');
        }
        return null;
      }
      
      final auth = await _currentAccount!.authentication;
      
      if (auth.accessToken == null) {
        if (kDebugMode) {
          print('⚠️ Access token non disponibile');
        }
        return null;
      }
      
      return {
        'Authorization': 'Bearer ${auth.accessToken}',
        'X-Goog-AuthUser': '0',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore ottenendo auth headers: $e');
      }
      return null;
    }
  }
  
/// Ottieni un client HTTP autenticato per le API Google
  Future<auth.AuthClient?> getAuthenticatedClient() async {
    try {
      if (kDebugMode) {
        print('🔍 Ottenimento client autenticato Google...');
      }

      // Verifica se abbiamo un account connesso
      if (_currentAccount == null) {
        if (kDebugMode) {
          print('❌ Nessun account Google connesso');
        }

        // Tenta di effettuare login silenzioso
        await _checkExistingSignIn();

        if (_currentAccount == null) {
          if (kDebugMode) {
            print('🔐 Effettuo login Google...');
          }
          // Effettua login se necessario
          _currentAccount = await signIn();
        }
      }

      if (_currentAccount == null) {
        if (kDebugMode) {
          print('❌ Login Google fallito o annullato');
        }
        return null;
      }

      // Ottieni l'authentication token dall'account Google
      final authentication = await _currentAccount!.authentication;

      if (authentication.accessToken == null) {
        if (kDebugMode) {
          print('❌ Access token non disponibile');
        }
        return null;
      }

      if (kDebugMode) {
        print('✅ Token Google ottenuto con successo');
        print('🔑 Token: ${authentication.accessToken!.substring(0, 20)}...');
      }

      // Crea un client HTTP con il token
      final client = _GoogleAuthClient(
        accessToken: authentication.accessToken!,
        idToken: authentication.idToken,
      );

      return client;

    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore ottenendo client autenticato: $e');
      }
      return null;
    }
  }

  /// Verifica che tutti i permessi richiesti siano stati concessi
  Future<bool> _checkPermissions() async {
    try {
      if (_currentAccount == null) return false;
      
      // Google Sign In su desktop concede automaticamente gli scope richiesti
      // Su web potrebbe essere necessario verificarli
      
      final grantedScopes = await _googleSignIn?.requestScopes(GoogleConfig.scopes);
      
      if (kDebugMode) {
        print('📝 Permessi concessi: $grantedScopes');
      }
      
      return grantedScopes ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore verifica permessi: $e');
      }
      return false;
    }
  }
  
  /// Refresh del token se scaduto
  Future<bool> refreshToken() async {
    try {
      if (_googleSignIn == null) return false;
      
      if (kDebugMode) {
        print('🔄 Refresh del token...');
      }
      
      // signInSilently forza un refresh del token
      _currentAccount = await _googleSignIn!.signInSilently();
      
      if (_currentAccount != null) {
        if (kDebugMode) {
          print('✅ Token refreshato');
        }
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore refresh token: $e');
      }
      return false;
    }
  }
  
  /// Ottieni informazioni dettagliate sull'utente
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

  /// Reset completo per risolvere rate limiting
  Future<void> resetAuthentication() async {
    try {
      if (kDebugMode) {
        print('🔄 Reset completo autenticazione Google...');
      }

      if (_googleSignIn != null) {
        await _googleSignIn!.disconnect();
        await _googleSignIn!.signOut();
      }

      _currentAccount = null;
      _googleSignIn = null;

      if (kDebugMode) {
        print('✅ Reset completato');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Errore durante reset: $e (ignorato)');
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
    // Aggiungi l'header Authorization a ogni richiesta
    request.headers['Authorization'] = 'Bearer $accessToken';
    
    if (kDebugMode) {
      print('📤 Request: ${request.method} ${request.url}');
    }
    
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
      // Scadenza token - impostiamo 1 ora da ora (verrà refreshato automaticamente)
      DateTime.now().add(const Duration(hours: 1)).toUtc(),
    ),
    null, // refreshToken non disponibile su Web
    GoogleConfig.scopes,
  );
}