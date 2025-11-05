import 'package:uuid/uuid.dart';
import 'document_artifact.dart';

class Message {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageStatus status;
  final String? sessionId;
  final List<DocumentArtifact> artifacts;

  const Message({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.sessionId,
    this.artifacts = const [],
  });

  factory Message.user({
    required String content,
    String? sessionId,
  }) {
    return Message(
      id: const Uuid().v4(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      sessionId: sessionId,
    );
  }

  factory Message.assistant({
    required String content,
    String? sessionId,
  }) {
    return Message(
      id: const Uuid().v4(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      sessionId: sessionId,
    );
  }

  factory Message.system({
    required String content,
    String? sessionId,
  }) {
    return Message(
      id: const Uuid().v4(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.system,
      sessionId: sessionId,
    );
  }

  Message copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    MessageStatus? status,
    String? sessionId,
    List<DocumentArtifact>? artifacts,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      artifacts: artifacts ?? this.artifacts,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'Message(id: $id, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}, isUser: $isUser, status: $status)';
  }
}

enum MessageStatus {
  sending,
  sent,
  error,
  system,
}