import 'package:uuid/uuid.dart';
import '../domain/entities/document_artifact.dart';

class ArtifactParser {
  static const uuid = Uuid();

  /// Parses Claude's response to extract document artifacts
  /// Looks for code blocks with titles or special artifact markers
  static List<DocumentArtifact> parseArtifacts(String content) {
    final List<DocumentArtifact> artifacts = [];

    // Pattern 1: Look for markdown code blocks with file names as titles
    // Example: ```python filename.py
    final codeBlockPattern = RegExp(
      r'```(\w+)(?:\s+([^\n]+))?\n([\s\S]*?)```',
      multiLine: true,
    );

    final matches = codeBlockPattern.allMatches(content);

    for (final match in matches) {
      final language = match.group(1);
      final title = match.group(2)?.trim() ?? 'Documento senza titolo';
      final codeContent = match.group(3) ?? '';

      // Only create artifact if there's a title or it looks like a file
      if (title.isNotEmpty && title != language) {
        artifacts.add(DocumentArtifact(
          id: uuid.v4(),
          title: title,
          content: codeContent.trim(),
          type: 'code',
          language: language,
        ));
      }
    }

    // Pattern 2: Look for explicit document creation phrases
    // Example: "Ecco il documento..." followed by code block
    final documentCreationPattern = RegExp(
      r'(?:ecco|ho creato|ti presento|ti ho preparato|ti invio|ti mostro)(?:\s+il)?\s+(?:documento|file|codice|testo)(?:\s+["\']([^"\']+)["\'])?[:\s]+```(\w+)?\n([\s\S]*?)```',
      caseSensitive: false,
      multiLine: true,
    );

    final docMatches = documentCreationPattern.allMatches(content);
    for (final match in docMatches) {
      final title = match.group(1) ?? 'Documento creato';
      final language = match.group(2);
      final docContent = match.group(3) ?? '';

      artifacts.add(DocumentArtifact(
        id: uuid.v4(),
        title: title,
        content: docContent.trim(),
        type: language != null ? 'code' : 'text',
        language: language,
      ));
    }

    return artifacts;
  }

  /// Removes artifact content from the message to clean up display
  static String removeArtifacts(String content, List<DocumentArtifact> artifacts) {
    String cleaned = content;

    // Remove code blocks that were converted to artifacts
    for (final artifact in artifacts) {
      // Remove the specific code block
      final pattern = RegExp(
        r'```\w*\s*${RegExp.escape(artifact.title)}[\s\S]*?```',
        multiLine: true,
      );
      cleaned = cleaned.replaceAll(pattern, '');

      // Also try to remove document creation phrases
      final creationPattern = RegExp(
        r'(?:ecco|ho creato|ti presento|ti ho preparato)(?:\s+il)?\s+(?:documento|file|codice)[:\s]+```\w*\n[\s\S]*?```',
        caseSensitive: false,
        multiLine: true,
      );
      cleaned = cleaned.replaceAll(creationPattern, '');
    }

    return cleaned.trim();
  }

  /// Extracts just the readable content, keeping artifact references
  static String getDisplayContent(String content, List<DocumentArtifact> artifacts) {
    if (artifacts.isEmpty) return content;

    String display = content;

    // Replace large code blocks with reference placeholders
    for (final artifact in artifacts) {
      final pattern = RegExp(
        r'```\w*[\s\S]*?```',
        multiLine: true,
      );

      // Only replace the first occurrence for each artifact
      display = display.replaceFirst(
        pattern,
        '\n[📄 Documento: ${artifact.title}]\n',
      );
    }

    return display.trim();
  }
}
