import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/dropbox_service.dart';
import '../../data/datasources/remote/dropbox_auth_service.dart';
import '../../domain/entities/dropbox_file.dart';

// Services
final dropboxServiceProvider = Provider<DropboxService>((ref) {
  return DropboxService();
});

final dropboxAuthServiceProvider = Provider<DropboxAuthService>((ref) {
  return DropboxAuthService();
});

// Auth State
final dropboxAuthStateProvider = StateNotifierProvider<DropboxAuthNotifier, DropboxAuthState>((ref) {
  final service = ref.watch(dropboxAuthServiceProvider);
  return DropboxAuthNotifier(service);
});

// File Selection
final selectedDropboxFilesProvider = StateNotifierProvider<SelectedDropboxFilesNotifier, List<DropboxFile>>((ref) {
  return SelectedDropboxFilesNotifier();
});

// File Browser State
final dropboxStateProvider = StateNotifierProvider<DropboxNotifier, DropboxState>((ref) {
  final service = ref.watch(dropboxServiceProvider);
  return DropboxNotifier(service);
});

// ===== Auth States =====

sealed class DropboxAuthState {
  const DropboxAuthState();
}

class DropboxAuthInitial extends DropboxAuthState {
  const DropboxAuthInitial();
}

class DropboxAuthLoading extends DropboxAuthState {
  const DropboxAuthLoading();
}

class DropboxAuthAuthenticated extends DropboxAuthState {
  final String email;
  final String? name;

  const DropboxAuthAuthenticated({
    required this.email,
    this.name,
  });
}

class DropboxAuthUnauthenticated extends DropboxAuthState {
  const DropboxAuthUnauthenticated();
}

class DropboxAuthError extends DropboxAuthState {
  final String message;
  const DropboxAuthError(this.message);
}

// ===== Auth Notifier =====

class DropboxAuthNotifier extends StateNotifier<DropboxAuthState> {
  final DropboxAuthService _service;

  DropboxAuthNotifier(this._service) : super(const DropboxAuthInitial()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      await _service.initialize();

      if (_service.isAuthenticated) {
        state = DropboxAuthAuthenticated(
          email: _service.userEmail ?? 'Unknown',
          name: _service.userName,
        );
      } else {
        state = const DropboxAuthUnauthenticated();
      }
    } catch (e) {
      state = const DropboxAuthUnauthenticated();
    }
  }

  Future<void> signIn() async {
    try {
      state = const DropboxAuthLoading();

      final success = await _service.signIn();

      if (success) {
        state = DropboxAuthAuthenticated(
          email: _service.userEmail ?? 'Unknown',
          name: _service.userName,
        );
      } else {
        state = const DropboxAuthUnauthenticated();
      }
    } catch (e) {
      state = DropboxAuthError('Errore durante il login: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      state = const DropboxAuthLoading();
      await _service.signOut();
      state = const DropboxAuthUnauthenticated();
    } catch (e) {
      state = DropboxAuthError('Errore durante il logout: ${e.toString()}');
    }
  }

  void refresh() {
    _checkAuthStatus();
  }
}

// ===== File States =====

sealed class DropboxState {
  const DropboxState();
}

class DropboxInitial extends DropboxState {
  const DropboxInitial();
}

class DropboxLoading extends DropboxState {
  const DropboxLoading();
}

class DropboxLoaded extends DropboxState {
  final List<DropboxFile> files;
  final String? currentPath;
  final List<BreadcrumbItem> breadcrumbs;
  final String? searchQuery;

  const DropboxLoaded({
    required this.files,
    this.currentPath,
    this.breadcrumbs = const [],
    this.searchQuery,
  });

  DropboxLoaded copyWith({
    List<DropboxFile>? files,
    String? currentPath,
    List<BreadcrumbItem>? breadcrumbs,
    String? searchQuery,
  }) {
    return DropboxLoaded(
      files: files ?? this.files,
      currentPath: currentPath ?? this.currentPath,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class DropboxError extends DropboxState {
  final String message;
  const DropboxError(this.message);
}

class BreadcrumbItem {
  final String path;
  final String name;

  const BreadcrumbItem({
    required this.path,
    required this.name,
  });
}

// ===== File Browser Notifier =====

class DropboxNotifier extends StateNotifier<DropboxState> {
  final DropboxService _service;

  DropboxNotifier(this._service) : super(const DropboxInitial());

  Future<void> initialize() async {
    try {
      state = const DropboxLoading();

      await _service.initialize();
      final files = await _service.listFiles(path: '');

      state = DropboxLoaded(
        files: files,
        currentPath: '',
        breadcrumbs: [
          const BreadcrumbItem(path: '', name: 'Dropbox'),
        ],
      );
    } catch (e) {
      state = DropboxError(_parseError(e));
    }
  }

  Future<void> searchFiles(String query) async {
    try {
      if (state is DropboxLoaded) {
        final currentState = state as DropboxLoaded;
        state = const DropboxLoading();

        final files = await _service.searchFiles(
          query: query,
          maxResults: 50,
        );

        state = currentState.copyWith(
          files: files,
          searchQuery: query,
        );
      } else {
        state = const DropboxLoading();
        final files = await _service.searchFiles(
          query: query,
          maxResults: 50,
        );

        state = DropboxLoaded(
          files: files,
          searchQuery: query,
          breadcrumbs: [
            const BreadcrumbItem(path: 'search', name: 'Risultati ricerca'),
          ],
        );
      }
    } catch (e) {
      state = DropboxError(_parseError(e));
    }
  }

  Future<void> navigateToFolder(String path, String folderName) async {
    try {
      if (state is DropboxLoaded) {
        final currentState = state as DropboxLoaded;
        state = const DropboxLoading();

        final files = await _service.listFiles(path: path);

        List<BreadcrumbItem> newBreadcrumbs;
        if (path.isEmpty) {
          newBreadcrumbs = [
            const BreadcrumbItem(path: '', name: 'Dropbox'),
          ];
        } else {
          final existingIndex = currentState.breadcrumbs
              .indexWhere((b) => b.path == path);

          if (existingIndex >= 0) {
            newBreadcrumbs = currentState.breadcrumbs
                .sublist(0, existingIndex + 1);
          } else {
            newBreadcrumbs = [
              ...currentState.breadcrumbs,
              BreadcrumbItem(path: path, name: folderName),
            ];
          }
        }

        state = DropboxLoaded(
          files: files,
          currentPath: path,
          breadcrumbs: newBreadcrumbs,
          searchQuery: null,
        );
      }
    } catch (e) {
      state = DropboxError(_parseError(e));
    }
  }

  Future<void> navigateToRoot() async {
    await navigateToFolder('', 'Dropbox');
  }

  Future<void> refresh() async {
    if (state is DropboxLoaded) {
      final currentState = state as DropboxLoaded;

      if (currentState.searchQuery != null) {
        await searchFiles(currentState.searchQuery!);
      } else if (currentState.currentPath != null) {
        await navigateToFolder(
          currentState.currentPath!,
          currentState.breadcrumbs.last.name,
        );
      } else {
        await initialize();
      }
    } else {
      await initialize();
    }
  }

  void clearSearch() {
    if (state is DropboxLoaded) {
      final currentState = state as DropboxLoaded;
      state = currentState.copyWith(searchQuery: null);
      refresh();
    }
  }

  String _parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('not authenticated')) {
      return 'Non sei autenticato con Dropbox. Clicca per effettuare il login.';
    }
    if (errorStr.contains('permission') || errorStr.contains('forbidden')) {
      return 'Permessi insufficienti per accedere a Dropbox';
    }
    if (errorStr.contains('not found')) {
      return 'File o cartella non trovata';
    }
    if (errorStr.contains('network')) {
      return 'Errore di rete. Controlla la connessione';
    }

    return 'Errore: ${error.toString()}';
  }
}

// ===== Selected Files Notifier =====

class SelectedDropboxFilesNotifier extends StateNotifier<List<DropboxFile>> {
  SelectedDropboxFilesNotifier() : super([]);

  void addFile(DropboxFile file) {
    if (!state.any((f) => f.id == file.id)) {
      state = [...state, file];
    }
  }

  void removeFile(String fileId) {
    state = state.where((f) => f.id != fileId).toList();
  }

  void toggleFile(DropboxFile file) {
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
