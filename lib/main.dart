import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/storage_keys.dart';
import 'core/constants/supabase_config.dart';
import 'data/datasources/remote/google_auth_service.dart';

void _initializeDesktopFeatures() {
}

Future<void> main() async {
  await _initializeSupabase();
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    _initializeDesktopFeatures();
  }

  await _initializeHive();
  await _initializeGoogleAuth();

  runApp(
    const ProviderScope(
      child: AIAssistantApp(),
    ),
  );
}

Future<void> _initializeSupabase() async {
  try {
    await Supabase.initialize(
      url: SupabaseConfig.currentUrl,
      anonKey: SupabaseConfig.currentAnonKey,
      debug: kDebugMode,
    );

    final isConnected = await _testSupabaseConnection();

  } catch (e) {
    if (kDebugMode) {
      print('❌ Errore nell\'inizializzazione di Supabase: $e');
    }
  }
}

Future<bool> _testSupabaseConnection() async {
  try {
    final client = Supabase.instance.client;
    await client.from('chat_sessions').select().limit(1);
    
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> _initializeHive() async {
  try {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      await Hive.initFlutter();
    }

    await Hive.openBox(StorageKeys.cacheBox);
    await Hive.openBox(StorageKeys.settingsBox);

  } catch (e) {
    if (kDebugMode) {
      print('❌ Errore nell\'inizializzazione di Hive: $e');
    }
  }
}

Future<void> _initializeGoogleAuth() async {
  try {

    final googleAuthService = GoogleAuthService();
    await googleAuthService.initialize();

  } catch (e) {
    if (kDebugMode) {
      print('❌ Errore nell\'inizializzazione di Google Auth Service: $e');
    }
  }
}