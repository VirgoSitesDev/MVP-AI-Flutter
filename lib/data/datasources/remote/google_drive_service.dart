import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

class DriveFile {
  final String id;
  final String name;
  final String? mimeType;
  final DateTime? modifiedTime;
  final String? size;
  final String? webViewLink;
  final String? webContentLink;
  final String? iconLink;
  final bool isFolder;
  final List<String>? parents;
  final String? description;

  DriveFile({
    required this.id,
    required this.name,
    this.mimeType,
    this.modifiedTime,
    this.size,
    this.webViewLink,
    this.webContentLink,
    this.iconLink,
    this.isFolder = false,
    this.parents,
    this.description,
  });

  factory DriveFile.fromGoogleFile(drive.File file) {
    return DriveFile(
      id: file.id ?? '',
      name: file.name ?? 'Senza nome',
      mimeType: file.mimeType,
      modifiedTime: file.modifiedTime,
      size: _formatFileSize(file.size),
      webViewLink: file.webViewLink,
      webContentLink: file.webContentLink,
      iconLink: file.iconLink,
      isFolder: file.mimeType == 'application/vnd.google-apps.folder',
      parents: file.parents,
      description: file.description,
    );
  }

  String get fileTypeIcon {
    if (isFolder) return '📁';

    switch (mimeType) {
      case 'application/vnd.google-apps.document':
        return '📝';
      case 'application/vnd.google-apps.spreadsheet':
        return '📊';
      case 'application/vnd.google-apps.presentation':
        return '📰';
      case 'application/vnd.google-apps.form':
        return '📋';

      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      case 'application/msword':
        return '📄';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      case 'application/vnd.ms-excel':
        return '📊';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      case 'application/vnd.ms-powerpoint':
        return '📊';

      case 'image/jpeg':
      case 'image/png':
      case 'image/gif':
      case 'image/webp':
        return '🖼️';

      case 'application/pdf':
        return '📕';

      case 'video/mp4':
      case 'video/quicktime':
      case 'video/x-msvideo':
        return '🎬';

      case 'audio/mpeg':
      case 'audio/wav':
      case 'audio/ogg':
        return '🎵';

      case 'application/zip':
      case 'application/x-rar-compressed':
      case 'application/x-7z-compressed':
        return '🗜️';

      default:
        return '📎';
    }
  }

  String get fileTypeDescription {
    if (isFolder) return 'Cartella';

    switch (mimeType) {
      case 'application/vnd.google-apps.document':
        return 'Google Docs';
      case 'application/vnd.google-apps.spreadsheet':
        return 'Google Sheets';
      case 'application/vnd.google-apps.presentation':
        return 'Google Slides';
      case 'application/vnd.google-apps.form':
        return 'Google Forms';
      case 'application/pdf':
        return 'PDF';
      default:
        return mimeType?.split('/').last.toUpperCase() ?? 'File';
    }
  }

  static String _formatFileSize(String? sizeStr) {
    if (sizeStr == null) return '';

    try {
      final bytes = int.parse(sizeStr);
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } catch (e) {
      return '';
    }
  }
}

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  drive.DriveApi? _driveApi;
  final GoogleAuthService _authService = GoogleAuthService();
  GoogleSignInAccount? _currentAccount;

  GoogleSignInAccount? get currentAccount => _currentAccount;
  bool get isSignedIn => _currentAccount != null;
  String? get userEmail => _currentAccount?.email;
  String? get userName => _currentAccount?.displayName;
  String? get userPhotoUrl => _currentAccount?.photoUrl;

  Future<void> initialize() async {
    try {
      await _authService.initialize();
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        throw Exception('Client non autenticato');
      }
      _driveApi = drive.DriveApi(client);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DriveFile>> searchFiles({
    String? query,
    String? folderId,
    int maxResults = 50,
    String? mimeType,
    bool onlyFolders = false,
  }) async {
    try {
      await _ensureInitialized();

      final queryParts = <String>[];

      queryParts.add('trashed = false');

      if (query != null && query.isNotEmpty) {
        queryParts.add("name contains '${query.replaceAll("'", "\\'")}'");
      }

      if (folderId != null && folderId.isNotEmpty) {
        queryParts.add("'$folderId' in parents");
      }

      if (mimeType != null) {
        queryParts.add("mimeType = '$mimeType'");
      }

      if (onlyFolders) {
        queryParts.add("mimeType = 'application/vnd.google-apps.folder'");
      }

      final searchQuery = queryParts.join(' and ');

      final fileList = await _driveApi!.files.list(
        q: searchQuery,
        pageSize: maxResults,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,iconLink,parents,description)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return [];
      }

      final results = fileList.files!
          .map((f) => DriveFile.fromGoogleFile(f))
          .toList();

      return results;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DriveFile>> listFiles({
    String? folderId,
    int maxResults = 50,
  }) async {
    return searchFiles(
      folderId: folderId ?? 'root',
      maxResults: maxResults,
    );
  }

  Future<List<DriveFile>> getRecentFiles({int maxResults = 20}) async {
    try {
      await _ensureInitialized();

      final fileList = await _driveApi!.files.list(
        q: 'trashed = false',
        pageSize: maxResults,
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,iconLink,parents,description)',
      );

      if (fileList.files == null) return [];

      return fileList.files!
          .map((f) => DriveFile.fromGoogleFile(f))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<DriveFile?> getFile(String fileId) async {
    try {
      await _ensureInitialized();

      final file = await _driveApi!.files.get(
        fileId,
        $fields: 'id,name,mimeType,modifiedTime,size,webViewLink,webContentLink,iconLink,parents,description',
      ) as drive.File;

      return DriveFile.fromGoogleFile(file);
    } catch (e) {
      return null;
    }
  }

  Future<List<int>?> downloadFile(String fileId) async {
    try {
      await _ensureInitialized();

      final fileInfo = await getFile(fileId);
      if (fileInfo == null) {
        debugPrint('❌ downloadFile: File not found: $fileId');
        throw Exception('File non trovato');
      }

      debugPrint('📥 downloadFile: ${fileInfo.name} (${fileInfo.mimeType})');

      if (fileInfo.mimeType?.startsWith('application/vnd.google-apps') ?? false) {
        debugPrint('🔄 downloadFile: Exporting Google Workspace file');
        return await exportGoogleFile(fileId, fileInfo.mimeType!);
      }

      debugPrint('⬇️ downloadFile: Starting download...');
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }

      debugPrint('✅ downloadFile: Downloaded ${bytes.length} bytes');
      return bytes;
    } catch (e, stackTrace) {
      debugPrint('❌ downloadFile ERROR for $fileId: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<int>?> exportGoogleFile(String fileId, String mimeType) async {
    try {
      await _ensureInitialized();

      String exportMimeType;
      switch (mimeType) {
        case 'application/vnd.google-apps.document':
          exportMimeType = 'text/plain';
          break;
        case 'application/vnd.google-apps.spreadsheet':
          exportMimeType = 'text/csv';
          break;
        case 'application/vnd.google-apps.presentation':
          exportMimeType = 'text/plain';
          break;
        case 'application/vnd.google-apps.form':
          throw Exception('Google Forms non possono essere esportati');
        case 'application/vnd.google-apps.drawing':
          exportMimeType = 'application/pdf';
          break;
        default:
          throw Exception('Tipo di file non esportabile: $mimeType');
      }

      try {
        final response = await _driveApi!.files.export(
          fileId,
          exportMimeType,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
        }

        if (bytes.isEmpty && mimeType == 'application/vnd.google-apps.document') {
          final htmlResponse = await _driveApi!.files.export(
            fileId,
            'text/html',
            downloadOptions: drive.DownloadOptions.fullMedia,
          ) as drive.Media;

          bytes.clear();
          await for (final chunk in htmlResponse.stream) {
            bytes.addAll(chunk);
          }

          if (bytes.isNotEmpty) {
            final htmlContent = utf8.decode(bytes);
            final textContent = _stripHtml(htmlContent);
            return utf8.encode(textContent);
          }
        }

        return bytes;

      } catch (e) {
        if (exportMimeType != 'application/pdf') {
          try {
            final pdfResponse = await _driveApi!.files.export(
              fileId,
              'application/pdf',
              downloadOptions: drive.DownloadOptions.fullMedia,
            ) as drive.Media;

            final pdfBytes = <int>[];
            await for (final chunk in pdfResponse.stream) {
              pdfBytes.addAll(chunk);
            }

            return pdfBytes;

          } catch (pdfError) {
          }
        }

        throw e;
      }
    } catch (e) {
      return null;
    }
  }

  String _stripHtml(String htmlContent) {
    htmlContent = htmlContent.replaceAll(RegExp(r'<script[^>]*>.*?</script>',
        multiLine: true, caseSensitive: false), '');
    htmlContent = htmlContent.replaceAll(RegExp(r'<style[^>]*>.*?</style>',
        multiLine: true, caseSensitive: false), '');

    htmlContent = htmlContent.replaceAll(RegExp(r'<br[^>]*>', caseSensitive: false), '\n');
    htmlContent = htmlContent.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    htmlContent = htmlContent.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');

    htmlContent = htmlContent.replaceAll(RegExp(r'<[^>]*>'), '');

    htmlContent = htmlContent
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–');

    htmlContent = htmlContent.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    htmlContent = htmlContent.replaceAll(RegExp(r' {2,}'), ' ');

    return htmlContent.trim();
  }

  Future<void> _ensureInitialized() async {
    if (_driveApi == null) {
      await initialize();
      if (_driveApi == null) {
        throw Exception('Google Drive Service non inizializzato');
      }
    }
  }

  Future<Map<String, dynamic>?> getStorageInfo() async {
    try {
      await _ensureInitialized();

      final about = await _driveApi!.about.get(
        $fields: 'storageQuota',
      );

      if (about.storageQuota == null) return null;

      final quota = about.storageQuota!;
      return {
        'limit': quota.limit,
        'usage': quota.usage,
        'usageInDrive': quota.usageInDrive,
        'usageInTrash': quota.usageInDriveTrash,
      };
    } catch (e) {
      return null;
    }
  }
}