import 'dart:convert';
import 'package:flutter/material.dart';

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

  GmailCategory get category {
    // Gmail usa le label per categorizzare le email
    if (labelIds.contains('CATEGORY_PROMOTIONS')) return GmailCategory.promotions;
    if (labelIds.contains('CATEGORY_SOCIAL')) return GmailCategory.social;
    if (labelIds.contains('CATEGORY_UPDATES')) return GmailCategory.updates;
    if (labelIds.contains('CATEGORY_FORUMS')) return GmailCategory.forums;

    // Fallback: categorizza in base al contenuto
    final subjectLower = subject.toLowerCase();
    final fromLower = from.toLowerCase();
    final snippetLower = snippet.toLowerCase();

    // Promozioni
    if (_isPromotionalEmail(subjectLower, fromLower, snippetLower)) {
      return GmailCategory.promotions;
    }

    // Social
    if (_isSocialEmail(fromLower)) {
      return GmailCategory.social;
    }

    // Aggiornamenti
    if (_isUpdateEmail(subjectLower, fromLower)) {
      return GmailCategory.updates;
    }

    // Default: Principale
    return GmailCategory.primary;
  }

  bool _isPromotionalEmail(String subject, String from, String snippet) {
    final promoKeywords = [
      'offerta', 'sconto', 'saldi', 'promozione', 'coupon', 'deal', 'shop',
      'acquista', 'risparmia', 'gratis', 'newsletter', 'marketing',
      'black friday', 'cyber monday', 'limited time', 'exclusive'
    ];

    final promoDomains = [
      'newsletter', 'promo', 'offers', 'deals', 'shop', 'store',
      'marketing', 'sales', 'justeat', 'takeaway', 'amazon', 'ebay'
    ];

    return promoKeywords.any((keyword) =>
      subject.contains(keyword) || snippet.contains(keyword)) ||
      promoDomains.any((domain) => from.contains(domain));
  }

  bool _isSocialEmail(String from) {
    final socialDomains = [
      'facebook', 'twitter', 'instagram', 'linkedin', 'youtube',
      'tiktok', 'snapchat', 'whatsapp', 'telegram', 'discord'
    ];

    return socialDomains.any((domain) => from.contains(domain));
  }

  bool _isUpdateEmail(String subject, String from) {
    final updateKeywords = [
      'aggiornamento', 'notifica', 'alert', 'notification', 'update',
      'invoice', 'fattura', 'receipt', 'ricevuta', 'payment', 'pagamento'
    ];

    final updateDomains = [
      'noreply', 'no-reply', 'notification', 'alert', 'update',
      'billing', 'invoice', 'payment', 'bank', 'finance'
    ];

    return updateKeywords.any((keyword) => subject.contains(keyword)) ||
           updateDomains.any((domain) => from.contains(domain));
  }

  String get bodyText {
    return _extractTextFromPart(payload);
  }

  String get bodyHtml {
    final rawHtml = _extractHtmlFromPart(payload);
    return _cleanHtml(rawHtml);
  }

  bool get hasHtmlContent {
    return bodyHtml.isNotEmpty;
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

  String _extractHtmlFromPart(GmailPayload part) {
    if (part.mimeType == 'text/html' && part.body.data.isNotEmpty) {
      return _decodeBase64(part.body.data);
    }

    for (final subPart in part.parts) {
      final html = _extractHtmlFromPart(subPart);
      if (html.isNotEmpty) return html;
    }

    return '';
  }

  String _decodeBase64(String data) {
    try {
      if (data.isEmpty) return '';

      // Gmail uses URL-safe base64 encoding
      String base64 = data.replaceAll('-', '+').replaceAll('_', '/');

      // Add padding if needed
      switch (base64.length % 4) {
        case 2:
          base64 += '==';
          break;
        case 3:
          base64 += '=';
          break;
      }

      // Import dart:convert for proper base64 decoding
      final bytes = const Base64Decoder().convert(base64);
      return utf8.decode(bytes);
    } catch (e) {
      print('Base64 decode error: $e');
      return data;
    }
  }

  String _cleanHtml(String html) {
    if (html.isEmpty) return html;

    // Strategia semplificata: mantieni le immagini base64 e rimuovi il tracking
    return html
        // Rimuovi tracking scripts e beacons
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', multiLine: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<noscript[^>]*>.*?</noscript>', multiLine: true, caseSensitive: false), '')

        // Rimuovi tracking pixels di dimensioni minime
        .replaceAll(RegExp(r'<img[^>]*(?:width|height)\s*=\s*["\x27]?0*1["\x27]?[^>]*>', caseSensitive: false), '')

        // Rimuovi link a domini di tracking noti
        .replaceAll(RegExp(r'<a[^>]*href\s*=\s*["\x27][^"\x27]*(?:click|track|analytics|utm_|pixel|beacon)[^"\x27]*["\x27][^>]*>(.*?)</a>', multiLine: true, caseSensitive: false), r'$1')

        // Pulisci attributi di tracking
        .replaceAll(RegExp(r'\s+data-(?:track|analytics|pixel)[^=]*=\s*["\x27][^"\x27]*["\x27]', caseSensitive: false), '')

        // Pulisci HTML entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")

        // Rimuovi tag vuoti
        .replaceAll(RegExp(r'<(\w+)[^>]*>\s*</\1>', caseSensitive: false), '')
        .trim();
  }

  bool _isTrackingUrl(String url) {
    final trackingDomains = [
      'click.', 'track.', 'analytics.', 'pixel.', 'beacon.',
      'utm_', 'mailtrack', 'mixpanel', 'amplitude',
      'justeat', 'takeaway', 'marketing', 'newsletter'
    ];

    return trackingDomains.any((domain) => url.toLowerCase().contains(domain));
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
      final headers = (json['headers'] as List?)
          ?.map((h) => GmailHeader.fromJson(h is Map<String, dynamic> ? h : {}))
          .toList() ?? [];

      return GmailPayload(
        partId: json['partId']?.toString() ?? '',
        mimeType: json['mimeType']?.toString() ?? '',
        filename: json['filename']?.toString() ?? '',
        headers: headers,
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

enum GmailCategory {
  primary,
  promotions,
  social,
  updates,
  forums,
}

extension GmailCategoryExtension on GmailCategory {
  String get displayName {
    switch (this) {
      case GmailCategory.primary:
        return 'Principale';
      case GmailCategory.promotions:
        return 'Promozioni';
      case GmailCategory.social:
        return 'Social';
      case GmailCategory.updates:
        return 'Aggiornamenti';
      case GmailCategory.forums:
        return 'Forum';
    }
  }

  IconData get icon {
    switch (this) {
      case GmailCategory.primary:
        return Icons.inbox;
      case GmailCategory.promotions:
        return Icons.local_offer;
      case GmailCategory.social:
        return Icons.people;
      case GmailCategory.updates:
        return Icons.info;
      case GmailCategory.forums:
        return Icons.forum;
    }
  }

  Color get color {
    switch (this) {
      case GmailCategory.primary:
        return const Color(0xFF1976D2); // Blue
      case GmailCategory.promotions:
        return const Color(0xFFE91E63); // Pink
      case GmailCategory.social:
        return const Color(0xFF2196F3); // Light Blue
      case GmailCategory.updates:
        return const Color(0xFFFF9800); // Orange
      case GmailCategory.forums:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}