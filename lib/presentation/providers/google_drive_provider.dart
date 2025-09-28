// lib/presentation/providers/google_drive_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/google_drive_service.dart';
import '../../data/datasources/remote/google_auth_service.dart';

// Provider per il servizio Google Drive
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

// Provider per lo stato di Google Drive
final googleDriveStateProvider = StateNotifierProvider<GoogleDriveNotifier, GoogleDriveState>((ref) {
  final service = ref.watch(googleDriveServiceProvider);
  return GoogleDriveNotifier(service);
});

// Provider per i file attualmente selezionati (riferimenti sessione)
final selectedDriveFilesProvider = StateNotifierProvider<SelectedFilesNotifier, List<DriveFile>>((ref) {
  return SelectedFilesNotifier();
});

// Provider per il servizio Google Auth
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

// Provider per lo stato di autenticazione Google
final googleAuthStateProvider = StateNotifierProvider<GoogleAuthNotifier, GoogleAuthState>((ref) {
  final service = ref.watch(googleAuthServiceProvider);
  return GoogleAuthNotifier(service);
});

// Stati possibili per Google Drive
sealed class GoogleDriveState {
  const GoogleDriveState();
}

class GoogleDriveInitial extends GoogleDriveState {
  const GoogleDriveInitial();
}

class GoogleDriveLoading extends GoogleDriveState {
  const GoogleDriveLoading();
}

class GoogleDriveLoaded extends GoogleDriveState {
  final List<DriveFile> files;
  final String? currentFolderId;
  final String? currentFolderName;
  final List<BreadcrumbItem> breadcrumbs;
  final String? searchQuery;
  
  const GoogleDriveLoaded({
    required this.files,
    this.currentFolderId,
    this.currentFolderName,
    this.breadcrumbs = const [],
    this.searchQuery,
  });
  
  GoogleDriveLoaded copyWith({
    List<DriveFile>? files,
    String? currentFolderId,
    String? currentFolderName,
    List<BreadcrumbItem>? breadcrumbs,
    String? searchQuery,
  }) {
    return GoogleDriveLoaded(
      files: files ?? this.files,
      currentFolderId: currentFolderId ?? this.currentFolderId,
      currentFolderName: currentFolderName ?? this.currentFolderName,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class GoogleDriveError extends GoogleDriveState {
  final String message;
  const GoogleDriveError(this.message);
}

// Classe per i breadcrumbs (navigazione cartelle)
class BreadcrumbItem {
  final String id;
  final String name;
  
  const BreadcrumbItem({
    required this.id,
    required this.name,
  });
}

// Notifier per gestire lo stato di Google Drive
class GoogleDriveNotifier extends StateNotifier<GoogleDriveState> {
  final GoogleDriveService _service;
  
  GoogleDriveNotifier(this._service) : super(const GoogleDriveInitial());
  
  // Inizializza e carica i file recenti
  Future<void> initialize() async {
    try {
      state = const GoogleDriveLoading();
      
      await _service.initialize();
      final files = await _service.getRecentFiles(maxResults: 30);
      
      state = GoogleDriveLoaded(
        files: files,
        breadcrumbs: [
          const BreadcrumbItem(id: 'root', name: 'Il mio Drive'),
        ],
      );
    } catch (e) {
      state = GoogleDriveError(_parseError(e));
    }
  }
  
  // Cerca file
  Future<void> searchFiles(String query) async {
    try {
      // Mantieni lo stato corrente ma con loading
      if (state is GoogleDriveLoaded) {
        final currentState = state as GoogleDriveLoaded;
        state = const GoogleDriveLoading();
        
        final files = await _service.searchFiles(
          query: query,
          maxResults: 50,
        );
        
        state = currentState.copyWith(
          files: files,
          searchQuery: query,
        );
      } else {
        state = const GoogleDriveLoading();
        final files = await _service.searchFiles(
          query: query,
          maxResults: 50,
        );
        
        state = GoogleDriveLoaded(
          files: files,
          searchQuery: query,
          breadcrumbs: [
            const BreadcrumbItem(id: 'search', name: 'Risultati ricerca'),
          ],
        );
      }
    } catch (e) {
      state = GoogleDriveError(_parseError(e));
    }
  }
  
  // Naviga in una cartella
  Future<void> navigateToFolder(String folderId, String folderName) async {
    try {
      if (state is GoogleDriveLoaded) {
        final currentState = state as GoogleDriveLoaded;
        state = const GoogleDriveLoading();
        
        final files = await _service.listFiles(folderId: folderId);
        
        // Aggiorna breadcrumbs
        List<BreadcrumbItem> newBreadcrumbs;
        if (folderId == 'root') {
          newBreadcrumbs = [
            const BreadcrumbItem(id: 'root', name: 'Il mio Drive'),
          ];
        } else {
          // Trova se questa cartella è già nei breadcrumbs
          final existingIndex = currentState.breadcrumbs
              .indexWhere((b) => b.id == folderId);
          
          if (existingIndex >= 0) {
            // Torna indietro nei breadcrumbs
            newBreadcrumbs = currentState.breadcrumbs
                .sublist(0, existingIndex + 1);
          } else {
            // Aggiungi nuovo breadcrumb
            newBreadcrumbs = [
              ...currentState.breadcrumbs,
              BreadcrumbItem(id: folderId, name: folderName),
            ];
          }
        }
        
        state = GoogleDriveLoaded(
          files: files,
          currentFolderId: folderId,
          currentFolderName: folderName,
          breadcrumbs: newBreadcrumbs,
          searchQuery: null, // Reset search when navigating
        );
      }
    } catch (e) {
      state = GoogleDriveError(_parseError(e));
    }
  }
  
  // Torna alla root
  Future<void> navigateToRoot() async {
    await navigateToFolder('root', 'Il mio Drive');
  }
  
  // Ricarica la vista corrente
  Future<void> refresh() async {
    if (state is GoogleDriveLoaded) {
      final currentState = state as GoogleDriveLoaded;
      
      if (currentState.searchQuery != null) {
        await searchFiles(currentState.searchQuery!);
      } else if (currentState.currentFolderId != null) {
        await navigateToFolder(
          currentState.currentFolderId!,
          currentState.currentFolderName ?? 'Cartella',
        );
      } else {
        await initialize();
      }
    } else {
      await initialize();
    }
  }
  
  // Clear search
  void clearSearch() {
    if (state is GoogleDriveLoaded) {
      final currentState = state as GoogleDriveLoaded;
      state = currentState.copyWith(searchQuery: null);
      refresh();
    }
  }
  
  String _parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('client non autenticato')) {
      return 'Non sei autenticato con Google. Clicca per effettuare il login.';
    }
    if (errorStr.contains('permission')) {
      return 'Permessi insufficienti per accedere a Google Drive';
    }
    if (errorStr.contains('not found')) {
      return 'File o cartella non trovata';
    }
    if (errorStr.contains('network')) {
      return 'Errore di rete. Controlla la connessione';
    }
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Autorizzazione scaduta. Effettua nuovamente il login.';
    }
    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return 'Accesso negato. Verifica i permessi del tuo account Google.';
    }

    return 'Errore: ${error.toString()}';
  }
}

// Notifier per i file selezionati
class SelectedFilesNotifier extends StateNotifier<List<DriveFile>> {
  SelectedFilesNotifier() : super([]);
  
  // Aggiungi un file alla selezione
  void addFile(DriveFile file) {
    if (!state.any((f) => f.id == file.id)) {
      state = [...state, file];
    }
  }
  
  // Rimuovi un file dalla selezione
  void removeFile(String fileId) {
    state = state.where((f) => f.id != fileId).toList();
  }
  
  // Toggle selezione file
  void toggleFile(DriveFile file) {
    if (state.any((f) => f.id == file.id)) {
      removeFile(file.id);
    } else {
      addFile(file);
    }
  }
  
  // Verifica se un file è selezionato
  bool isSelected(String fileId) {
    return state.any((f) => f.id == fileId);
  }
  
  // Pulisci selezione
  void clearSelection() {
    state = [];
  }
  
  // Ottieni il numero di file selezionati
  int get selectionCount => state.length;
}

// Stati possibili per Google Auth
sealed class GoogleAuthState {
  const GoogleAuthState();
}

class GoogleAuthInitial extends GoogleAuthState {
  const GoogleAuthInitial();
}

class GoogleAuthLoading extends GoogleAuthState {
  const GoogleAuthLoading();
}

class GoogleAuthAuthenticated extends GoogleAuthState {
  final String email;
  final String? name;
  final String? photoUrl;

  const GoogleAuthAuthenticated({
    required this.email,
    this.name,
    this.photoUrl,
  });
}

class GoogleAuthUnauthenticated extends GoogleAuthState {
  const GoogleAuthUnauthenticated();
}

class GoogleAuthError extends GoogleAuthState {
  final String message;
  const GoogleAuthError(this.message);
}

// Notifier per gestire lo stato di Google Auth
class GoogleAuthNotifier extends StateNotifier<GoogleAuthState> {
  final GoogleAuthService _service;

  GoogleAuthNotifier(this._service) : super(const GoogleAuthInitial()) {
    _checkAuthStatus();
  }

  // Controlla lo stato di autenticazione all'avvio
  Future<void> _checkAuthStatus() async {
    try {
      if (_service.isSignedIn && _service.currentAccount != null) {
        final account = _service.currentAccount!;
        state = GoogleAuthAuthenticated(
          email: account.email,
          name: account.displayName,
          photoUrl: account.photoUrl,
        );
      } else {
        state = const GoogleAuthUnauthenticated();
      }
    } catch (e) {
      state = const GoogleAuthUnauthenticated();
    }
  }

  // Effettua il login
  Future<void> signIn() async {
    try {
      if (kDebugMode) {
        print('🏁 Provider: Inizio signIn()');
      }

      state = const GoogleAuthLoading();

      if (kDebugMode) {
        print('🔄 Provider: Stato cambiato a Loading');
      }

      final account = await _service.signIn();

      if (kDebugMode) {
        print('📱 Provider: Ricevuto account: ${account != null ? account.email : "NULL"}');
      }

      if (account != null) {
        state = GoogleAuthAuthenticated(
          email: account.email,
          name: account.displayName,
          photoUrl: account.photoUrl,
        );
        if (kDebugMode) {
          print('✅ Provider: Stato cambiato a Authenticated (${account.email})');
        }
      } else {
        state = const GoogleAuthUnauthenticated();
        if (kDebugMode) {
          print('❌ Provider: Stato cambiato a Unauthenticated');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 Provider: Errore nel signIn: $e');
      }
      state = GoogleAuthError('Errore durante il login: ${e.toString()}');
    }
  }

  // Effettua il logout
  Future<void> signOut() async {
    try {
      state = const GoogleAuthLoading();
      await _service.signOut();
      state = const GoogleAuthUnauthenticated();
    } catch (e) {
      state = GoogleAuthError('Errore durante il logout: ${e.toString()}');
    }
  }

  // Aggiorna lo stato
  void refresh() {
    _checkAuthStatus();
  }
}