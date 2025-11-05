import 'package:uuid/uuid.dart';
import '../domain/entities/document_artifact.dart';

class ArtifactParser {
  static const uuid = Uuid();

  /// Parses Claude's response to extract document artifacts
  /// Looks for code blocks with filenames (like Claude Desktop does)
  static List<DocumentArtifact> parseArtifacts(String content) {
    final List<DocumentArtifact> artifacts = [];

    // Look for code blocks with filenames: ```language filename.ext
    final codeBlockPattern = RegExp(
      r'```(\w+)\s+([^\n]+)\n([\s\S]*?)```',
      multiLine: true,
    );

    final matches = codeBlockPattern.allMatches(content);

    for (final match in matches) {
      final language = match.group(1) ?? '';
      final filename = match.group(2)?.trim() ?? '';
      final codeContent = match.group(3) ?? '';

      // Must have a filename that looks like a file (has extension)
      if (filename.isEmpty || !filename.contains('.')) continue;

      // Content must not be empty
      if (codeContent.trim().isEmpty) continue;

      artifacts.add(DocumentArtifact(
        id: uuid.v4(),
        title: filename,
        content: codeContent.trim(),
        type: 'code',
        language: language,
      ));
    }

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
}
