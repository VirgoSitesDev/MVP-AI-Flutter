import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleTokenService {
  
  static Future<String?> getGoogleToken() async {
    try {
      try {
        final response = await Supabase.instance.client
            .rpc('get_google_token');
        
        if (response != null && response['provider_token'] != null) {
          return response['provider_token'];
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Funzione SQL non trovata o errore: $e');
        }
      }

      final edgeResponse = await Supabase.instance.client.functions.invoke(
        'google-drive-auth',
        body: {},
      );

      if (edgeResponse.data != null) {
        if (edgeResponse.data['error'] != null) {
          if (edgeResponse.data['requiresReauth'] == true) {
            return null;
          }
        }
        
        if (edgeResponse.data['access_token'] != null) {
          return edgeResponse.data['access_token'];
        }
      }

      await _triggerReauthWithDriveScopes();
      
      return null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore recupero token: $e');
      }
      return null;
    }
  }
  
  static Future<void> _triggerReauthWithDriveScopes() async {
    try {
      await Supabase.instance.client.auth.signOut();
      
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        scopes: 'email profile https://www.googleapis.com/auth/drive.readonly',
        queryParams: {
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Errore ri-autenticazione: $e');
      }
    }
  }
}