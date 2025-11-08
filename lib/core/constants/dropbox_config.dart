import 'package:flutter/foundation.dart';

class DropboxConfig {
  // Dropbox App Key from environment or default
  static const String appKey = String.fromEnvironment(
    'DROPBOX_APP_KEY',
    defaultValue: 'pfrfzf7yq238ylh',
  );

  // Dropbox App Secret from environment or default
  static const String appSecret = String.fromEnvironment(
    'DROPBOX_APP_SECRET',
    defaultValue: 'h9aj11d211m3dsn',
  );

  // Dropbox OAuth2 endpoints
  static const String authorizationEndpoint = 'https://www.dropbox.com/oauth2/authorize';
  static const String tokenEndpoint = 'https://api.dropboxapi.com/oauth2/token';

  // Dropbox API endpoints
  static const String apiEndpoint = 'https://api.dropboxapi.com/2';
  static const String contentEndpoint = 'https://content.dropboxapi.com/2';

  // OAuth2 scopes required for file access
  static const List<String> scopes = [
    'account_info.read',
    'files.metadata.read',
    'files.content.read',
  ];

  static bool get isDevelopment => kDebugMode;

  // Redirect URI for web (should match what you configured in Dropbox App Console)
  static String get redirectUri {
    if (kIsWeb) {
      if (isDevelopment) {
        return 'http://localhost:5000';
      } else {
        // Production URL - matches your Netlify deployment
        return 'https://virgoai.netlify.app';
      }
    }
    return 'http://localhost:5000';
  }
}
