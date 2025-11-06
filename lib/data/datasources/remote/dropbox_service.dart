import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/dropbox_config.dart';
import '../../../domain/entities/dropbox_file.dart';
import 'dropbox_auth_service.dart';

class DropboxService {
  static final DropboxService _instance = DropboxService._internal();
  factory DropboxService() => _instance;
  DropboxService._internal();

  final Dio _dio = Dio();
  final DropboxAuthService _authService = DropboxAuthService();

  bool get isAuthenticated => _authService.isAuthenticated;
  String? get userEmail => _authService.userEmail;
  String? get userName => _authService.userName;

  Future<void> initialize() async {
    await _authService.initialize();
  }

  Future<List<DropboxFile>> listFiles({
    String path = '',
    int limit = 50,
  }) async {
    try {
      _ensureAuthenticated();

      final response = await _dio.post(
        '${DropboxConfig.apiEndpoint}/files/list_folder',
        data: {
          'path': path.isEmpty ? '' : path,
          'limit': limit,
          'include_mounted_folders': true,
          'include_non_downloadable_files': false,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_authService.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final entries = response.data['entries'] as List;
        return entries
            .map((entry) => DropboxFile.fromJson(entry))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error listing Dropbox files: $e');
      rethrow;
    }
  }

  Future<List<DropboxFile>> searchFiles({
    required String query,
    String path = '',
    int maxResults = 50,
  }) async {
    try {
      _ensureAuthenticated();

      final response = await _dio.post(
        '${DropboxConfig.apiEndpoint}/files/search_v2',
        data: {
          'query': query,
          'options': {
            'path': path.isEmpty ? '' : path,
            'max_results': maxResults,
            'file_status': 'active',
          },
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_authService.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final matches = response.data['matches'] as List;
        return matches
            .map((match) {
              final metadata = match['metadata']['metadata'];
              return DropboxFile.fromJson(metadata);
            })
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error searching Dropbox files: $e');
      rethrow;
    }
  }

  Future<List<int>?> downloadFile(String path) async {
    try {
      _ensureAuthenticated();

      final response = await _dio.post(
        '${DropboxConfig.contentEndpoint}/files/download',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_authService.accessToken}',
            'Dropbox-API-Arg': jsonEncode({'path': path}),
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200) {
        return response.data as List<int>;
      }

      return null;
    } catch (e) {
      debugPrint('Error downloading file from Dropbox: $e');
      return null;
    }
  }

  Future<DropboxFile?> getFileMetadata(String path) async {
    try {
      _ensureAuthenticated();

      final response = await _dio.post(
        '${DropboxConfig.apiEndpoint}/files/get_metadata',
        data: {
          'path': path,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_authService.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return DropboxFile.fromJson(response.data);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting file metadata: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSpaceUsage() async {
    try {
      _ensureAuthenticated();

      final response = await _dio.post(
        '${DropboxConfig.apiEndpoint}/users/get_space_usage',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_authService.accessToken}',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'used': data['used'],
          'allocated': data['allocation']['allocated'],
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error getting space usage: $e');
      return null;
    }
  }

  Future<String?> getTemporaryLink(String path) async {
    try {
      _ensureAuthenticated();

      final response = await _dio.post(
        '${DropboxConfig.apiEndpoint}/files/get_temporary_link',
        data: {
          'path': path,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_authService.accessToken}',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['link'];
      }

      return null;
    } catch (e) {
      debugPrint('Error getting temporary link: $e');
      return null;
    }
  }

  void _ensureAuthenticated() {
    if (!_authService.isAuthenticated) {
      throw Exception('Not authenticated with Dropbox');
    }
  }
}
