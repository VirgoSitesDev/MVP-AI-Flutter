import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const String url = 'https://scjptlxittvbhcibmbiv.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNjanB0bHhpdHR2YmhjaWJtYml2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzNzU1NzMsImV4cCI6MjA3Mzk1MTU3M30.v33FvZDPA5zzSKLe2I1e--QEmemoPUrWOv315zTmp0o';

  static const String localUrl = 'http://localhost:54321';

  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');

  static String get currentUrl => url;
  static String get currentAnonKey => anonKey;

  static bool get isDesktop {
    if (kIsWeb) return false;

    return defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux ||
           defaultTargetPlatform == TargetPlatform.macOS;
  }

  static bool get shouldSkipCertificateVerification => isDesktop && kDebugMode;
}