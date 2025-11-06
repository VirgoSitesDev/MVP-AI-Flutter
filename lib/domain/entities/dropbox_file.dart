class DropboxFile {
  final String id;
  final String name;
  final String pathLower;
  final String pathDisplay;
  final String? rev;
  final DateTime? clientModified;
  final DateTime? serverModified;
  final int? size;
  final bool isFolder;
  final String? contentHash;

  DropboxFile({
    required this.id,
    required this.name,
    required this.pathLower,
    required this.pathDisplay,
    this.rev,
    this.clientModified,
    this.serverModified,
    this.size,
    this.isFolder = false,
    this.contentHash,
  });

  factory DropboxFile.fromJson(Map<String, dynamic> json) {
    final isFolder = json['.tag'] == 'folder';

    return DropboxFile(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Senza nome',
      pathLower: json['path_lower'] ?? '',
      pathDisplay: json['path_display'] ?? '',
      rev: json['rev'],
      clientModified: json['client_modified'] != null
          ? DateTime.parse(json['client_modified'])
          : null,
      serverModified: json['server_modified'] != null
          ? DateTime.parse(json['server_modified'])
          : null,
      size: json['size'],
      isFolder: isFolder,
      contentHash: json['content_hash'],
    );
  }

  String get fileTypeIcon {
    if (isFolder) return '📁';

    final extension = name.split('.').last.toLowerCase();

    switch (extension) {
      // Documents
      case 'doc':
      case 'docx':
        return '📄';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📊';
      case 'txt':
      case 'md':
        return '📝';

      // PDF
      case 'pdf':
        return '📕';

      // Images
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'svg':
        return '🖼️';

      // Videos
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return '🎬';

      // Audio
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'flac':
        return '🎵';

      // Archives
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return '🗜️';

      // Code
      case 'dart':
      case 'js':
      case 'ts':
      case 'py':
      case 'java':
      case 'cpp':
      case 'c':
      case 'html':
      case 'css':
        return '💻';

      default:
        return '📎';
    }
  }

  String get fileTypeDescription {
    if (isFolder) return 'Cartella';

    final extension = name.split('.').last.toLowerCase();
    return extension.toUpperCase();
  }

  String get formattedSize {
    if (size == null) return '';

    if (size! < 1024) return '$size B';
    if (size! < 1048576) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1073741824) return '${(size! / 1048576).toStringAsFixed(1)} MB';
    return '${(size! / 1073741824).toStringAsFixed(1)} GB';
  }
}
