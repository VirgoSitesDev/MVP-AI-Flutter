// lib/data/datasources/remote/google_token_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleTokenService {
  
  static Future<String?> getGoogleToken() async {
    try {
      if (kDebugMode) {
        print('🔑 Recupero Google token da Supabase...');
      }
      
      try {
        final response = await Supabase.instance.client
            .rpc('get_google_token');
        
        if (response != null && response['provider_token'] != null) {
          if (kDebugMode) {
            print('✅ Token recuperato dalla funzione SQL');
          }
          return response['provider_token'];
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Funzione SQL non trovata o errore: $e');
        }
      }
      
      if (kDebugMode) {
        print('🔄 Tentativo con Edge Function...');
      }
      
      final edgeResponse = await Supabase.instance.client.functions.invoke(
        'google-drive-auth',
        body: {},
      );
      
      if (kDebugMode) {
        print('📥 Risposta Edge Function: ${edgeResponse.data}');
      }
      
      if (edgeResponse.data != null) {
        if (edgeResponse.data['error'] != null) {
          if (kDebugMode) {
            print('⚠️ Errore dalla Edge Function: ${edgeResponse.data['error']}');
          }
          
          if (edgeResponse.data['requiresReauth'] == true) {
            if (kDebugMode) {
              print('🔄 Ri-autenticazione richiesta');
            }
            return null;
          }
        }
        
        if (edgeResponse.data['access_token'] != null) {
          if (kDebugMode) {
            print('✅ Token recuperato dalla Edge Function');
          }
          return edgeResponse.data['access_token'];
        }
      }
      
      if (kDebugMode) {
        print('⚠️ Nessun token trovato, ri-autenticazione necessaria');
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
      if (kDebugMode) {
        print('🔄 Triggering re-authentication with Drive scopes...');
      }
      
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