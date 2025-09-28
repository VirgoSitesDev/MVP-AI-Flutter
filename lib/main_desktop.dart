import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Classe per bypassare verifiche SSL su desktop (solo per sviluppo)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (kDebugMode) {
          print('🔓 Accepting ALL certificates in debug mode for host: $host');
          return true;
        }
        return false;
      }
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);
  }
}

void initializeDesktop() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    if (kDebugMode) {
      HttpOverrides.global = MyHttpOverrides();
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}