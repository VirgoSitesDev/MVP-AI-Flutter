// lib/domain/entities/chat_session.dart
import 'package:uuid/uuid.dart';
import 'message.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message> messages;
  final bool isActive;
  final String? contextSummary;
  
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.isActive = true,
    this.contextSummary,
  });
  
  /// Crea una nuova sessione chat
  factory ChatSession.create({
    String? title,
  }) {
    final now = DateTime.now();
    return ChatSession(
      id: const Uuid().v4(),
      title: title ?? 'Nuova Chat ${_formatDate(now)}',
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// Aggiunge un messaggio alla sessione
  ChatSession addMessage(Message message) {
    final updatedMessages = [...messages, message];
    return copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Aggiorna l'ultimo messaggio (utile per streaming)
  ChatSession updateLastMessage(String content) {
    if (messages.isEmpty) return this;
    
    final updatedMessages = [...messages];
    final lastMessage = updatedMessages.last;
    updatedMessages[updatedMessages.length - 1] = lastMessage.copyWith(
      content: content,
      status: MessageStatus.sent,
    );
    
    return copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Segna un messaggio come errore
  ChatSession markLastMessageError() {
    if (messages.isEmpty) return this;
    
    final updatedMessages = [...messages];
    final lastMessage = updatedMessages.last;
    updatedMessages[updatedMessages.length - 1] = lastMessage.copyWith(
      status: MessageStatus.error,
    );
    
    return copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Aggiorna il titolo automaticamente basandosi sui messaggi
  ChatSession updateTitleFromMessages() {
    if (messages.isEmpty) return this;
    
    final firstUserMessage = messages.firstWhere(
      (msg) => msg.isUser,
      orElse: () => messages.first,
    );
    
    String newTitle = firstUserMessage.content;
    if (newTitle.length > 50) {
      newTitle = '${newTitle.substring(0, 50)}...';
    }
    
    return copyWith(title: newTitle);
  }
  
  /// Ottiene solo i messaggi dell'utente e dell'assistente (esclude sistema)
  List<Message> get conversationMessages {
    return messages.where((msg) => msg.status != MessageStatus.system).toList();
  }
  
  /// Ottiene l'ultimo messaggio
  Message? get lastMessage {
    return messages.isNotEmpty ? messages.last : null;
  }
  
  /// Verifica se la sessione ha messaggi
  bool get hasMessages => messages.isNotEmpty;
  
  /// Conta i messaggi dell'utente
  int get userMessageCount => messages.where((msg) => msg.isUser).length;
  
  /// Crea una copia della sessione con modifiche
  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Message>? messages,
    bool? isActive,
    String? contextSummary,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      contextSummary: contextSummary ?? this.contextSummary,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatSession && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  @override
  String toString() {
    return 'ChatSession(id: $id, title: $title, messages: ${messages.length})';
  }
}