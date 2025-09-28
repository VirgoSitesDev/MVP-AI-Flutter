class GmailMessage {
  final String id;
  final String threadId;
  final List<String> labelIds;
  final String snippet;
  final String historyId;
  final int internalDate;
  final GmailPayload payload;
  final int sizeEstimate;
  final String raw;

  GmailMessage({
    required this.id,
    required this.threadId,
    required this.labelIds,
    required this.snippet,
    required this.historyId,
    required this.internalDate,
    required this.payload,
    required this.sizeEstimate,
    this.raw = '',
  });

  factory GmailMessage.fromJson(Map<String, dynamic> json) {
    return GmailMessage(
      id: json['id'] ?? '',
      threadId: json['threadId'] ?? '',
      labelIds: List<String>.from(json['labelIds'] ?? []),
      snippet: json['snippet'] ?? '',
      historyId: json['historyId'] ?? '',
      internalDate: int.tryParse(json['internalDate']?.toString() ?? '0') ?? 0,
      payload: GmailPayload.fromJson(json['payload'] ?? {}),
      sizeEstimate: json['sizeEstimate'] ?? 0,
      raw: json['raw'] ?? '',
    );
  }

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(internalDate);

  String get subject => payload.headers
      .where((h) => h.name.toLowerCase() == 'subject')
      .map((h) => h.value)
      .firstOrNull ?? '';

  String get from => payload.headers
      .where((h) => h.name.toLowerCase() == 'from')
      .map((h) => h.value)
      .firstOrNull ?? '';

  String get to => payload.headers
      .where((h) => h.name.toLowerCase() == 'to')
      .map((h) => h.value)
      .firstOrNull ?? '';

  bool get isUnread => labelIds.contains('UNREAD');
  bool get isImportant => labelIds.contains('IMPORTANT');
  bool get isStarred => labelIds.contains('STARRED');

  String get bodyText {
    return _extractTextFromPart(payload);
  }

  String _extractTextFromPart(GmailPayload part) {
    if (part.mimeType == 'text/plain' && part.body.data.isNotEmpty) {
      return _decodeBase64(part.body.data);
    }

    if (part.mimeType == 'text/html' && part.body.data.isNotEmpty) {
      final html = _decodeBase64(part.body.data);
      return _stripHtml(html);
    }

    for (final subPart in part.parts) {
      final text = _extractTextFromPart(subPart);
      if (text.isNotEmpty) return text;
    }

    return snippet;
  }

  String _decodeBase64(String data) {
    try {
      final bytes = Uri.decodeFull(data).replaceAll('-', '+').replaceAll('_', '/');
      final padding = '=' * (4 - (bytes.length % 4));
      final base64String = bytes + padding;
      return String.fromCharCodes(Uri.decodeComponent(base64String).codeUnits);
    } catch (e) {
      return data;
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', multiLine: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', multiLine: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<br[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }
}

class GmailPayload {
  final String partId;
  final String mimeType;
  final String filename;
  final List<GmailHeader> headers;
  final GmailBody body;
  final List<GmailPayload> parts;

  GmailPayload({
    required this.partId,
    required this.mimeType,
    required this.filename,
    required this.headers,
    required this.body,
    required this.parts,
  });

  factory GmailPayload.fromJson(Map<String, dynamic> json) {
    return GmailPayload(
      partId: json['partId'] ?? '',
      mimeType: json['mimeType'] ?? '',
      filename: json['filename'] ?? '',
      headers: (json['headers'] as List?)
          ?.map((h) => GmailHeader.fromJson(h))
          .toList() ?? [],
      body: GmailBody.fromJson(json['body'] ?? {}),
      parts: (json['parts'] as List?)
          ?.map((p) => GmailPayload.fromJson(p))
          .toList() ?? [],
    );
  }
}

class GmailHeader {
  final String name;
  final String value;

  GmailHeader({
    required this.name,
    required this.value,
  });

  factory GmailHeader.fromJson(Map<String, dynamic> json) {
    return GmailHeader(
      name: json['name'] ?? '',
      value: json['value'] ?? '',
    );
  }
}

class GmailBody {
  final String attachmentId;
  final int size;
  final String data;

  GmailBody({
    required this.attachmentId,
    required this.size,
    required this.data,
  });

  factory GmailBody.fromJson(Map<String, dynamic> json) {
    return GmailBody(
      attachmentId: json['attachmentId'] ?? '',
      size: json['size'] ?? 0,
      data: json['data'] ?? '',
    );
  }
}

class GmailThread {
  final String id;
  final String historyId;
  final List<GmailMessage> messages;

  GmailThread({
    required this.id,
    required this.historyId,
    required this.messages,
  });

  factory GmailThread.fromJson(Map<String, dynamic> json) {
    return GmailThread(
      id: json['id'] ?? '',
      historyId: json['historyId'] ?? '',
      messages: (json['messages'] as List?)
          ?.map((m) => GmailMessage.fromJson(m))
          .toList() ?? [],
    );
  }

  GmailMessage? get latestMessage => messages.isNotEmpty ? messages.last : null;
  String get subject => latestMessage?.subject ?? '';
  bool get isUnread => messages.any((m) => m.isUnread);
}