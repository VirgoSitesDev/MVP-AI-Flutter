import 'package:flutter/foundation.dart';

class GoogleConfig {
  static const String desktopClientId = '1015899649183-ocukl2gesl8bb7502v3nsub4frko8btc.apps.googleusercontent.com';
  static const String webClientId = '1015899649183-6qsdcijpdpskf2sn65ujfmhdt1j1eko1.apps.googleusercontent.com';

  static const List<String> scopes = [
    'email',
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/documents.readonly',
    'https://www.googleapis.com/auth/spreadsheets.readonly',
  ];

  static String get currentClientId {
    if (kIsWeb) {
      return webClientId;
    }
    return desktopClientId;
  }

  static bool get isDevelopment => kDebugMode;

  static String get redirectUrl {
    if (kIsWeb) {
      if (isDevelopment) {
        return 'http://localhost:58409';
      }
      return 'https://virgoai.netlify.app/auth/callback';
    }
    return 'urn:ietf:wg:oauth:2.0:oob';
  }
}