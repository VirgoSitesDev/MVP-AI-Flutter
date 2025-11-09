class DocumentArtifact {
  final String id;
  final String title;
  final String content;
  final String type; // 'text', 'code', 'markdown', 'html', 'json', 'table', etc.
  final String? language; // For code artifacts
  final DateTime createdAt;

  // Table-specific data (for CSV/Excel artifacts)
  final List<String>? headers;
  final List<List<String>>? tableData;

  DocumentArtifact({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.language,
    DateTime? createdAt,
    this.headers,
    this.tableData,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isTable => type == 'table' || language == 'csv' || language == 'excel';

  String get fileExtension {
    // Check if it's a table/CSV/Excel type
    if (isTable) {
      return 'xlsx'; // Always export tables as Excel
    }

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
      case 'csv':
        return 'csv';
      case 'excel':
      case 'xlsx':
        return 'xlsx';
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
      'headers': headers,
      'tableData': tableData,
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
      headers: json['headers'] != null
          ? List<String>.from(json['headers'] as List)
          : null,
      tableData: json['tableData'] != null
          ? (json['tableData'] as List)
              .map((row) => List<String>.from(row as List))
              .toList()
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
    List<String>? headers,
    List<List<String>>? tableData,
  }) {
    return DocumentArtifact(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      headers: headers ?? this.headers,
      tableData: tableData ?? this.tableData,
    );
  }
}
