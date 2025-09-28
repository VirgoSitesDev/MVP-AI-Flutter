// lib/core/constants/google_config.dart
import 'package:flutter/foundation.dart';

class GoogleConfig {
  // IMPORTANTE: Sostituisci questi valori con quelli del tuo progetto Google Cloud
  // Li trovi nel file JSON scaricato da Google Cloud Console
  
  // Per Desktop (Windows, macOS, Linux)
  static const String desktopClientId = '1015899649183-ocukl2gesl8bb7502v3nsub4frko8btc.apps.googleusercontent.com';
  
  // Per Web (se decidi di supportarlo in futuro)
  static const String webClientId = '1015899649183-6qsdcijpdpskf2sn65ujfmhdt1j1eko1.apps.googleusercontent.com';
  
  // Scopes richiesti - definiscono cosa può fare l'app
  static const List<String> scopes = [
    'email', // Per ottenere l'email dell'utente
    'https://www.googleapis.com/auth/drive.readonly', // Lettura Google Drive
    'https://www.googleapis.com/auth/gmail.readonly', // Lettura Gmail
    'https://www.googleapis.com/auth/documents.readonly', // Lettura Google Docs
    'https://www.googleapis.com/auth/spreadsheets.readonly', // Lettura Google Sheets
  ];
  
  // Usa client ID diverso per web vs desktop
  static String get currentClientId {
    if (kIsWeb) {
      return webClientId;
    }
    return desktopClientId;
  }
  
  // Verifica se siamo in sviluppo
  static bool get isDevelopment => kDebugMode;
  
  // URL di redirect per OAuth
  static String get redirectUrl {
    if (kIsWeb) {
      // Per sviluppo locale su web
      if (isDevelopment) {
        return 'http://localhost:58409'; // Porta di default Flutter web, modifica se necessario
      }
      // Per produzione (quando avrai un dominio reale)
      return 'https://tuodominio.com/auth/callback';
    }
    // Per desktop, Google Sign In gestisce automaticamente
    return 'urn:ietf:wg:oauth:2.0:oob';
  }
}