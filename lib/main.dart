import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import condizionali per gestire le differenze tra web e desktop
import 'app.dart';
import 'core/constants/storage_keys.dart';
import 'core/constants/supabase_config.dart';
import 'data/datasources/remote/google_auth_service.dart';

// Stub per le funzionalità desktop non disponibili su web
void _initializeDesktopFeatures() {
  // Questa funzione verrà sovrascritta su desktop
}

Future<void> main() async {
  // INIZIALIZZA SUPABASE - QUESTO MANCAVA!
  await _initializeSupabase();
  WidgetsFlutterBinding.ensureInitialized();
  
  // NON usare Platform o dart:io direttamente!
  // Usa kIsWeb per verificare se siamo su web
  if (!kIsWeb) {
    // Solo per desktop, non per web
    _initializeDesktopFeatures();
  }
  
  
  // Inizializza Hive per caching locale
  await _initializeHive();

  // Inizializza Google Auth Service
  await _initializeGoogleAuth();

  if (kDebugMode) {
    print('✅ App inizializzata con successo');
  }
  
  runApp(
    const ProviderScope(
      child: AIAssistantApp(),
    ),
  );
}

Future<void> _initializeSupabase() async {
  try {
    if (kDebugMode) {
      print('🔧 Inizializzazione Supabase...');
    }

    await Supabase.initialize(
      url: SupabaseConfig.currentUrl,
      anonKey: SupabaseConfig.currentAnonKey,
      debug: kDebugMode,
    );

    if (kDebugMode) {
      print('✅ Supabase inizializzato con successo');
      print('📍 URL: ${SupabaseConfig.currentUrl}');
    }

    // Test della connessione
    final isConnected = await _testSupabaseConnection();
    if (kDebugMode) {
      if (isConnected) {
        print('✅ Connessione a Supabase verificata');
      } else {
        print('⚠️ Impossibile verificare la connessione a Supabase');
      }
    }

  } catch (e) {
    if (kDebugMode) {
      print('❌ Errore nell\'inizializzazione di Supabase: $e');
    }
    // Non bloccare l'app se Supabase fallisce, potrebbe funzionare offline
  }
}

Future<bool> _testSupabaseConnection() async {
  try {
    // Prova una query semplice per verificare la connessione
    final client = Supabase.instance.client;

    // Prova a fare una query di health check
    await client.from('chat_sessions').select().limit(1);
    
    return true;
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Test connessione Supabase fallito: $e');
    }
    return false;
  }
}

Future<void> _initializeHive() async {
  try {
    if (kIsWeb) {
      // Su web, Hive usa IndexedDB
      await Hive.initFlutter();
    } else {
      // Su desktop, usa path_provider
      await Hive.initFlutter();
    }

    // Apri i box necessari
    await Hive.openBox(StorageKeys.cacheBox);
    await Hive.openBox(StorageKeys.settingsBox);

    if (kDebugMode) {
      print('✅ Hive inizializzato con successo');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Errore nell\'inizializzazione di Hive: $e');
    }
  }
}

Future<void> _initializeGoogleAuth() async {
  try {
    if (kDebugMode) {
      print('🔧 Inizializzazione Google Auth Service...');
    }

    final googleAuthService = GoogleAuthService();
    await googleAuthService.initialize();

    if (kDebugMode) {
      print('✅ Google Auth Service inizializzato con successo');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Errore nell\'inizializzazione di Google Auth Service: $e');
    }
    // Non bloccare l'app se Google Auth fallisce
  }
}