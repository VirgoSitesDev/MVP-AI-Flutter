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
    try {
      return GmailMessage(
        id: json['id']?.toString() ?? '',
        threadId: json['threadId']?.toString() ?? '',
        labelIds: (json['labelIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
        snippet: json['snippet']?.toString() ?? '',
        historyId: json['historyId']?.toString() ?? '',
        internalDate: int.tryParse(json['internalDate']?.toString() ?? '0') ?? 0,
        payload: GmailPayload.fromJson((json['payload'] is Map<String, dynamic>) ? json['payload'] : {}),
        sizeEstimate: (json['sizeEstimate'] is int) ? json['sizeEstimate'] : int.tryParse(json['sizeEstimate']?.toString() ?? '0') ?? 0,
        raw: json['raw']?.toString() ?? '',
      );
    } catch (e) {
      print('❌ GmailMessage.fromJson error: $e');
      print('JSON data keys: ${json.keys.toList()}');
      rethrow;
    }
  }

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(internalDate);

  String get subject {
    final subjectHeaders = payload.headers
        .where((h) => h.name.toLowerCase() == 'subject')
        .map((h) => h.value);
    return subjectHeaders.isNotEmpty ? subjectHeaders.first : '';
  }

  String get from {
    final fromHeaders = payload.headers
        .where((h) => h.name.toLowerCase() == 'from')
        .map((h) => h.value);
    return fromHeaders.isNotEmpty ? fromHeaders.first : '';
  }

  String get to {
    final toHeaders = payload.headers
        .where((h) => h.name.toLowerCase() == 'to')
        .map((h) => h.value);
    return toHeaders.isNotEmpty ? toHeaders.first : '';
  }

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
    try {
      return GmailPayload(
        partId: json['partId']?.toString() ?? '',
        mimeType: json['mimeType']?.toString() ?? '',
        filename: json['filename']?.toString() ?? '',
        headers: (json['headers'] as List?)
            ?.map((h) => GmailHeader.fromJson(h is Map<String, dynamic> ? h : {}))
            .toList() ?? [],
        body: GmailBody.fromJson((json['body'] is Map<String, dynamic>) ? json['body'] : {}),
        parts: (json['parts'] as List?)
            ?.map((p) => GmailPayload.fromJson(p is Map<String, dynamic> ? p : {}))
            .toList() ?? [],
      );
    } catch (e) {
      print('❌ GmailPayload.fromJson error: $e');
      print('JSON data: $json');
      return GmailPayload(
        partId: '',
        mimeType: '',
        filename: '',
        headers: [],
        body: GmailBody(attachmentId: '', size: 0, data: ''),
        parts: [],
      );
    }
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
    try {
      return GmailHeader(
        name: json['name']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );
    } catch (e) {
      print('❌ GmailHeader.fromJson error: $e');
      return GmailHeader(name: '', value: '');
    }
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
    try {
      return GmailBody(
        attachmentId: json['attachmentId']?.toString() ?? '',
        size: (json['size'] is int) ? json['size'] : int.tryParse(json['size']?.toString() ?? '0') ?? 0,
        data: json['data']?.toString() ?? '',
      );
    } catch (e) {
      print('❌ GmailBody.fromJson error: $e');
      return GmailBody(attachmentId: '', size: 0, data: '');
    }
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