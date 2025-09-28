// lib/core/constants/supabase_config.dart
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // I tuoi dati Supabase reali
  static const String url = 'https://scjptlxittvbhcibmbiv.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjanB0bHhpdHR2YmhjaWJtYml2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzNzU1NzMsImV4cCI6MjA3Mzk1MTU3M30.v33FvZDPA5zzSKLe2I1e--QEmemoPUrWOv315zTmp0o';
  
  // Configurazione per sviluppo locale
  static const String localUrl = 'http://localhost:54321';
  
  // Configurazione per produzione
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  
  // Usa sempre Supabase cloud per MVP
  static String get currentUrl => url;
  static String get currentAnonKey => anonKey;
  
  // Verifica se siamo su desktop (web-safe!)
  static bool get isDesktop {
    if (kIsWeb) return false;
    
    // Usa defaultTargetPlatform invece di Platform
    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux ||
           defaultTargetPlatform == TargetPlatform.macOS;
  }
  
  // Configurazione specifica per desktop
  static bool get shouldSkipCertificateVerification => isDesktop && kDebugMode;
}