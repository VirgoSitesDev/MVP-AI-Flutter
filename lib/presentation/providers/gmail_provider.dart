import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/gmail_service.dart';
import '../../domain/entities/gmail_message.dart';

final gmailServiceProvider = Provider<GmailService>((ref) {
  return GmailService();
});

final gmailMessagesProvider = FutureProvider.family<List<GmailMessage>, GmailQuery>((ref, query) async {
  final gmailService = ref.read(gmailServiceProvider);

  print('🔍 Gmail Provider: Tentativo di caricamento messaggi per query: ${query.type}');

  try {
    switch (query.type) {
      case GmailQueryType.inbox:
        return await gmailService.getInboxMessages(maxResults: query.maxResults);
      case GmailQueryType.unread:
        return await gmailService.getUnreadMessages(maxResults: query.maxResults);
      case GmailQueryType.important:
        return await gmailService.getImportantMessages(maxResults: query.maxResults);
      case GmailQueryType.search:
        return await gmailService.searchMessages(query: query.searchQuery!, maxResults: query.maxResults);
      case GmailQueryType.fromSender:
        return await gmailService.getMessagesFromSender(senderEmail: query.senderEmail!, maxResults: query.maxResults);
      case GmailQueryType.recent:
        return await gmailService.getRecentMessages(days: query.days!, maxResults: query.maxResults);
    }
  } catch (e) {
    print('❌ Gmail Provider Error: $e');
    rethrow;
  }
});

final gmailMessageProvider = FutureProvider.family<GmailMessage?, String>((ref, messageId) async {
  final gmailService = ref.read(gmailServiceProvider);
  return gmailService.getMessage(messageId);
});

final gmailThreadProvider = FutureProvider.family<GmailThread?, String>((ref, threadId) async {
  final gmailService = ref.read(gmailServiceProvider);
  return gmailService.getThread(threadId);
});

final gmailLabelsProvider = FutureProvider((ref) async {
  final gmailService = ref.read(gmailServiceProvider);
  return gmailService.getLabels();
});

final gmailProfileProvider = FutureProvider((ref) async {
  final gmailService = ref.read(gmailServiceProvider);
  return gmailService.getUserProfile();
});

final gmailMessageCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final gmailService = ref.read(gmailServiceProvider);
  return gmailService.getMessageCounts();
});

class GmailNotifier extends StateNotifier<GmailState> {
  GmailNotifier(this._gmailService) : super(const GmailState());

  final GmailService _gmailService;

  Future<void> markAsRead(String messageId) async {
    final success = await _gmailService.markAsRead(messageId);
    if (success) {
      state = state.copyWith(lastAction: GmailAction.markRead, lastMessageId: messageId);
    }
  }

  Future<void> markAsUnread(String messageId) async {
    final success = await _gmailService.markAsUnread(messageId);
    if (success) {
      state = state.copyWith(lastAction: GmailAction.markUnread, lastMessageId: messageId);
    }
  }

  Future<void> addStar(String messageId) async {
    final success = await _gmailService.addStar(messageId);
    if (success) {
      state = state.copyWith(lastAction: GmailAction.addStar, lastMessageId: messageId);
    }
  }

  Future<void> removeStar(String messageId) async {
    final success = await _gmailService.removeStar(messageId);
    if (success) {
      state = state.copyWith(lastAction: GmailAction.removeStar, lastMessageId: messageId);
    }
  }

  void setSelectedMessage(GmailMessage? message) {
    state = state.copyWith(selectedMessage: message);
  }

  void clearSelectedMessage() {
    state = state.copyWith(selectedMessage: null);
  }
}

final gmailNotifierProvider = StateNotifierProvider<GmailNotifier, GmailState>((ref) {
  final gmailService = ref.read(gmailServiceProvider);
  return GmailNotifier(gmailService);
});

class GmailQuery {
  final GmailQueryType type;
  final int maxResults;
  final String? searchQuery;
  final String? senderEmail;
  final int? days;

  const GmailQuery({
    required this.type,
    this.maxResults = 20,
    this.searchQuery,
    this.senderEmail,
    this.days,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GmailQuery &&
        other.type == type &&
        other.maxResults == maxResults &&
        other.searchQuery == searchQuery &&
        other.senderEmail == senderEmail &&
        other.days == days;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        maxResults.hashCode ^
        searchQuery.hashCode ^
        senderEmail.hashCode ^
        days.hashCode;
  }
}

enum GmailQueryType {
  inbox,
  unread,
  important,
  search,
  fromSender,
  recent,
}

class GmailState {
  final GmailMessage? selectedMessage;
  final GmailAction? lastAction;
  final String? lastMessageId;

  const GmailState({
    this.selectedMessage,
    this.lastAction,
    this.lastMessageId,
  });

  GmailState copyWith({
    GmailMessage? selectedMessage,
    GmailAction? lastAction,
    String? lastMessageId,
  }) {
    return GmailState(
      selectedMessage: selectedMessage ?? this.selectedMessage,
      lastAction: lastAction ?? this.lastAction,
      lastMessageId: lastMessageId ?? this.lastMessageId,
    );
  }
}

enum GmailAction {
  markRead,
  markUnread,
  addStar,
  removeStar,
}