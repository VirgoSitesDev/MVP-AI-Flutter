import 'package:uuid/uuid.dart';
import '../domain/entities/document_artifact.dart';

class ArtifactParser {
  static const uuid = Uuid();

  /// Parses Claude's response to extract document artifacts
  /// Looks for code blocks with filenames (like Claude Desktop does)
  static List<DocumentArtifact> parseArtifacts(String content) {
    final List<DocumentArtifact> artifacts = [];

    print('[ArtifactParser] Starting parse...');
    print('[ArtifactParser] Content length: ${content.length}');

    // Look for code blocks with filenames: ```language filename.ext
    final codeBlockPattern = RegExp(
      r'```(\w+)\s+([^\n]+)\n([\s\S]*?)```',
      multiLine: true,
    );

    final matches = codeBlockPattern.allMatches(content);
    print('[ArtifactParser] Found ${matches.length} potential code blocks');

    for (final match in matches) {
      final language = match.group(1) ?? '';
      final filename = match.group(2)?.trim() ?? '';
      final codeContent = match.group(3) ?? '';

      print('[ArtifactParser] Match: lang="$language" filename="$filename" contentLen=${codeContent.length}');

      // Must have a filename that looks like a file (has extension)
      if (filename.isEmpty || !filename.contains('.')) {
        print('[ArtifactParser] Skipped: no valid filename');
        continue;
      }

      // Content must not be empty
      if (codeContent.trim().isEmpty) {
        print('[ArtifactParser] Skipped: empty content');
        continue;
      }

      print('[ArtifactParser] Creating artifact: $filename');

      // Check if it's a CSV file - parse it into table structure
      if (language.toLowerCase() == 'csv' || filename.toLowerCase().endsWith('.csv')) {
        print('[ArtifactParser] Detected CSV - parsing into table structure');
        final tableResult = _parseCSV(codeContent.trim());

        artifacts.add(DocumentArtifact(
          id: uuid.v4(),
          title: filename,
          content: codeContent.trim(),
          type: 'table',
          language: 'csv',
          headers: tableResult['headers'] as List<String>?,
          tableData: tableResult['data'] as List<List<String>>?,
        ));
      } else {
        artifacts.add(DocumentArtifact(
          id: uuid.v4(),
          title: filename,
          content: codeContent.trim(),
          type: 'code',
          language: language,
        ));
      }
    }

    print('[ArtifactParser] Total artifacts created: ${artifacts.length}');
    return artifacts;
  }

  /// Extracts just the readable content, replacing code blocks with artifact references
  static String getDisplayContent(String content, List<DocumentArtifact> artifacts) {
    if (artifacts.isEmpty) return content;

    String display = content;

    // Replace each artifact's code block with a reference
    for (final artifact in artifacts) {
      final escapedFilename = RegExp.escape(artifact.title);
      final pattern = RegExp(
        '```${artifact.language}\\s+$escapedFilename\\n[\\s\\S]*?```',
        multiLine: true,
      );

      display = display.replaceFirst(
        pattern,
        '\n[📄 ${artifact.title}]\n',
      );
    }

    return display.trim();
  }

  /// Parses CSV content into headers and table data
  static Map<String, dynamic> _parseCSV(String csvContent) {
    try {
      final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        return {'headers': null, 'data': null};
      }

      // First line is headers
      final headers = _parseCSVLine(lines[0]);

      // Remaining lines are data
      final data = <List<String>>[];
      for (int i = 1; i < lines.length; i++) {
        final row = _parseCSVLine(lines[i]);
        if (row.isNotEmpty) {
          data.add(row);
        }
      }

      print('[ArtifactParser] Parsed CSV: ${headers.length} columns, ${data.length} rows');

      return {
        'headers': headers,
        'data': data,
      };
    } catch (e) {
      print('[ArtifactParser] Error parsing CSV: $e');
      return {'headers': null, 'data': null};
    }
  }

  /// Parses a single CSV line, handling quotes
  static List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    final StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        // Handle escaped quotes
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentField.write('"');
          i++; // Skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(currentField.toString().trim());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }

    // Add the last field
    result.add(currentField.toString().trim());

    return result;
  }
}
