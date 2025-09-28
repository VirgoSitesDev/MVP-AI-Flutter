import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/google_drive_service.dart';
import '../../data/datasources/remote/google_auth_service.dart';

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  return GoogleDriveService();
});

final googleDriveStateProvider = StateNotifierProvider<GoogleDriveNotifier, GoogleDriveState>((ref) {
  final service = ref.watch(googleDriveServiceProvider);
  return GoogleDriveNotifier(service);
});

final selectedDriveFilesProvider = StateNotifierProvider<SelectedFilesNotifier, List<DriveFile>>((ref) {
  return SelectedFilesNotifier();
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final googleAuthStateProvider = StateNotifierProvider<GoogleAuthNotifier, GoogleAuthState>((ref) {
  final service = ref.watch(googleAuthServiceProvider);
  return GoogleAuthNotifier(service);
});

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

class BreadcrumbItem {
  final String id;
  final String name;
  
  const BreadcrumbItem({
    required this.id,
    required this.name,
  });
}

class GoogleDriveNotifier extends StateNotifier<GoogleDriveState> {
  final GoogleDriveService _service;
  
  GoogleDriveNotifier(this._service) : super(const GoogleDriveInitial());

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

  Future<void> searchFiles(String query) async {
    try {
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

  Future<void> navigateToFolder(String folderId, String folderName) async {
    try {
      if (state is GoogleDriveLoaded) {
        final currentState = state as GoogleDriveLoaded;
        state = const GoogleDriveLoading();
        
        final files = await _service.listFiles(folderId: folderId);

        List<BreadcrumbItem> newBreadcrumbs;
        if (folderId == 'root') {
          newBreadcrumbs = [
            const BreadcrumbItem(id: 'root', name: 'Il mio Drive'),
          ];
        } else {
          final existingIndex = currentState.breadcrumbs
              .indexWhere((b) => b.id == folderId);
          
          if (existingIndex >= 0) {
            newBreadcrumbs = currentState.breadcrumbs
                .sublist(0, existingIndex + 1);
          } else {
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
          searchQuery: null,
        );
      }
    } catch (e) {
      state = GoogleDriveError(_parseError(e));
    }
  }

  Future<void> navigateToRoot() async {
    await navigateToFolder('root', 'Il mio Drive');
  }

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

class SelectedFilesNotifier extends StateNotifier<List<DriveFile>> {
  SelectedFilesNotifier() : super([]);

  void addFile(DriveFile file) {
    if (!state.any((f) => f.id == file.id)) {
      state = [...state, file];
    }
  }

  void removeFile(String fileId) {
    state = state.where((f) => f.id != fileId).toList();
  }

  void toggleFile(DriveFile file) {
    if (state.any((f) => f.id == file.id)) {
      removeFile(file.id);
    } else {
      addFile(file);
    }
  }

  bool isSelected(String fileId) {
    return state.any((f) => f.id == fileId);
  }

  void clearSelection() {
    state = [];
  }

  int get selectionCount => state.length;
}

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

class GoogleAuthNotifier extends StateNotifier<GoogleAuthState> {
  final GoogleAuthService _service;

  GoogleAuthNotifier(this._service) : super(const GoogleAuthInitial()) {
    _checkAuthStatus();
  }

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

  Future<void> signIn() async {
    try {
      state = const GoogleAuthLoading();

      final account = await _service.signIn();

      if (account != null) {
        state = GoogleAuthAuthenticated(
          email: account.email,
          name: account.displayName,
          photoUrl: account.photoUrl,
        );
      } else {
        state = const GoogleAuthUnauthenticated();
      }
    } catch (e) {
      state = GoogleAuthError('Errore durante il login: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      state = const GoogleAuthLoading();
      await _service.signOut();
      state = const GoogleAuthUnauthenticated();
    } catch (e) {
      state = GoogleAuthError('Errore durante il logout: ${e.toString()}');
    }
  }

  void refresh() {
    _checkAuthStatus();
  }
}