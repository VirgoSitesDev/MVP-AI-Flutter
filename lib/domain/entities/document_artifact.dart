class DocumentArtifact {
  final String id;
  final String title;
  final String content;
  final String type; // 'text', 'code', 'markdown', 'html', 'json', etc.
  final String? language; // For code artifacts
  final DateTime createdAt;

  DocumentArtifact({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.language,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get fileExtension {
    switch (type) {
      case 'code':
        return _getCodeExtension(language ?? '');
      case 'markdown':
        return 'md';
      case 'html':
        return 'html';
      case 'json':
        return 'json';
      case 'text':
      default:
        return 'txt';
    }
  }

  String get fileName => '${_sanitizeFileName(title)}.$fileExtension';

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  String _getCodeExtension(String lang) {
    switch (lang.toLowerCase()) {
      case 'javascript':
      case 'js':
        return 'js';
      case 'typescript':
      case 'ts':
        return 'ts';
      case 'python':
      case 'py':
        return 'py';
      case 'java':
        return 'java';
      case 'dart':
        return 'dart';
      case 'html':
        return 'html';
      case 'css':
        return 'css';
      case 'json':
        return 'json';
      case 'xml':
        return 'xml';
      case 'yaml':
      case 'yml':
        return 'yaml';
      default:
        return 'txt';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DocumentArtifact.fromJson(Map<String, dynamic> json) {
    return DocumentArtifact(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      type: json['type'] as String,
      language: json['language'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  DocumentArtifact copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    String? language,
    DateTime? createdAt,
  }) {
    return DocumentArtifact(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
