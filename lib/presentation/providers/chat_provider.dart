import 'dart:async';

import 'package:ai_assistant_mvp/data/datasources/remote/google_drive_content_extractor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/chat_session.dart';
import '../../domain/entities/message.dart';
import '../../data/datasources/remote/supabase_service.dart';
import '../../utils/artifact_parser.dart';
import 'google_drive_provider.dart';
import 'gmail_provider.dart';
import '../../data/datasources/remote/claude_api_service.dart';

class SupabaseUserAccount {
  final String email;
  final String id;
  final String? displayName;
  final String? photoUrl;

  SupabaseUserAccount({
    required this.email,
    required this.id,
    this.displayName,
    this.photoUrl,
  });

  Future<SupabaseAuthentication> get authentication async {
    return SupabaseAuthentication();
  }

  Future<void> clearAuthCache() async {}

  Future<Map<String, String>> get authHeaders async => {};

  String get serverAuthCode => '';
}

class SupabaseAuthentication {
  String? get accessToken => null;
  String? get idToken => null;
  String? get serverAuthCode => null;
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AppAuthState>((ref) {
  return AuthStateNotifier(ref);
});

final currentChatSessionProvider = StateNotifierProvider<ChatSessionNotifier, ChatSession?>((ref) {
  return ChatSessionNotifier(ref);
});

final messageStateProvider = StateNotifierProvider<MessageStateNotifier, AppMessageState>((ref) {
  return MessageStateNotifier();
});

final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AppAuthStateAuthenticated) {
    return [];
  }
  
  try {
    return await SupabaseService.getChatSessions();
  } catch (e) {
    return [];
  }
});

final claudeApiServiceProvider = Provider<ClaudeApiService>((ref) {
  return ClaudeApiService();
});

class AuthStateNotifier extends StateNotifier<AppAuthState> {
  final Ref _ref;
  
  AuthStateNotifier(this._ref) : super(const AppAuthState.loading()) {
    _init();
  }
  
  void _init() {
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      _updateSupabaseAuthState(data);
    });

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser != null) {
      state = AppAuthState.authenticated(
        _createSupabaseUserAccount(currentUser),
        {'email': currentUser.email, 'name': currentUser.userMetadata?['full_name']},
      );
    } else {
      state = const AppAuthState.unauthenticated();
    }
  }

  void _updateSupabaseAuthState(AuthState authState) {
    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        if (authState.session?.user != null) {
          final user = authState.session!.user;
          state = AppAuthState.authenticated(
            _createSupabaseUserAccount(user),
            {'email': user.email, 'name': user.userMetadata?['full_name']},
          );
        }
        break;
      case AuthChangeEvent.signedOut:
        state = const AppAuthState.unauthenticated();
        break;
      default:
        break;
    }
  }

  SupabaseUserAccount _createSupabaseUserAccount(User user) {
    return SupabaseUserAccount(
      email: user.email ?? '',
      id: user.id,
      displayName: user.userMetadata?['full_name'] ?? user.email ?? '',
      photoUrl: user.userMetadata?['avatar_url'],
    );
  }
  
  
  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
      state = const AppAuthState.unauthenticated();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }

  Future<void> signInWithSupabaseGoogle() async {
    try {
      state = const AppAuthState.loading();
      await SupabaseService.signInWithGoogle();
    } catch (e) {
      state = AppAuthState.error(e.toString());
    }
  }
}

class ChatSessionNotifier extends StateNotifier<ChatSession?> {
  final Ref _ref;
  
  ChatSessionNotifier(this._ref) : super(null);
  
  Future<void> createNewSession({String? title}) async {
    final authState = _ref.read(authStateProvider);

    if (authState is! AppAuthStateAuthenticated) {
      throw Exception('User not authenticated');
    }
    
    try {
      final session = await SupabaseService.createChatSession(title ?? 'Nuova Chat');
      state = session;

      _ref.invalidate(chatSessionsProvider);
    } catch (e) {
      _ref.read(messageStateProvider.notifier).setError('Errore nella creazione della chat: $e');
    }
  }

  Future<void> loadSession(ChatSession session) async {
    try {
      final messages = await SupabaseService.getMessages(session.id);
      final sessionWithMessages = session.copyWith(messages: messages);
      state = sessionWithMessages;
    } catch (e) {
      _ref.read(messageStateProvider.notifier).setError('Errore nel caricamento dei messaggi: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    final messageNotifier = _ref.read(messageStateProvider.notifier);
    
    try {
      messageNotifier.setSending();

      if (state == null) {
        await createNewSession(title: content.substring(0, content.length > 50 ? 50 : content.length));
      }

      final selectedDriveFiles = _ref.read(selectedDriveFilesProvider);
      final selectedEmails = _ref.read(selectedGmailMessagesProvider);
      String fileContext = '';
      String emailContext = '';

      if (selectedDriveFiles.isNotEmpty) {

        final extractor = GoogleDriveContentExtractor();

        try {
          fileContext = await extractor.extractMultipleFiles(selectedDriveFiles);
        } catch (e) {
          fileContext = '\n\n--- FILE DI RIFERIMENTO ---\n';
          for (final file in selectedDriveFiles) {
            fileContext += '📎 ${file.name} (${file.fileTypeDescription})\n';
          }
          fileContext += '--- FINE RIFERIMENTI ---\n\n';
        }
      }

      if (selectedEmails.isNotEmpty) {
        emailContext = '\n\n=== EMAIL DI RIFERIMENTO ===\n\n';

        for (final email in selectedEmails) {
          emailContext += '--- EMAIL ${selectedEmails.indexOf(email) + 1} ---\n';
          emailContext += 'Da: ${email.from}\n';
          emailContext += 'A: ${email.to}\n';
          emailContext += 'Oggetto: ${email.subject}\n';
          emailContext += 'Data: ${email.date.day}/${email.date.month}/${email.date.year} ${email.date.hour}:${email.date.minute}\n';
          emailContext += '\nContenuto:\n';
          emailContext += email.bodyText.isNotEmpty ? email.bodyText : email.snippet;
          emailContext += '\n\n';
        }

        emailContext += '=== FINE EMAIL ===\n\n';
      }

      String fullMessage = content;
      if (fileContext.isNotEmpty || emailContext.isNotEmpty) {
        fullMessage = """
$fileContext$emailContext
DOMANDA UTENTE: $content

Istruzioni: Usa i file e le email forniti come contesto per rispondere alla domanda. Se contengono informazioni rilevanti, citale nella risposta.
""";
      }
    
      final userMessage = Message.user(
        content: content,
        sessionId: state!.id,
      );

      state = state!.addMessage(userMessage);

      final sentUserMessage = userMessage.copyWith(status: MessageStatus.sent);
      final updatedMessages = state!.messages.map((m) =>
          m.id == userMessage.id ? sentUserMessage : m).toList();

      state = state!.copyWith(messages: updatedMessages);

      final tempAssistantMessage = Message(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
        sessionId: state!.id,
      );

      state = state!.addMessage(tempAssistantMessage);

      try {
        final history = state!.messages
            .where((m) => m.id != tempAssistantMessage.id && m.status != MessageStatus.sending)
            .toList();

        final claudeService = _ref.read(claudeApiServiceProvider);
        
        Map<String, dynamic> response;

        if (claudeService.hasApiKey) {
          response = await claudeService.sendMessage(
            message: fullMessage,
            history: history,
          );
        } else {
          response = await SupabaseService.sendToClaude(
            message: fullMessage,
            history: history,
            sessionId: state!.id,
          );
        }

        final messagesWithoutTemp = state!.messages
            .where((m) => m.id != tempAssistantMessage.id)
            .toList();

        final responseContent = response['content'] ?? 'Mi dispiace, non ho ricevuto una risposta valida.';

        // DEBUG: Print what Claude returned
        print('=== CLAUDE RESPONSE ===');
        print('Length: ${responseContent.length}');
        print('Content: $responseContent');
        print('======================');

        // Parse artifacts from Claude's response
        final artifacts = ArtifactParser.parseArtifacts(responseContent);

        print('=== ARTIFACTS FOUND ===');
        print('Count: ${artifacts.length}');
        for (var a in artifacts) {
          print('- ${a.title} (${a.language})');
        }
        print('======================');

        // Clean content by replacing code blocks with references
        final displayContent = artifacts.isNotEmpty
            ? ArtifactParser.getDisplayContent(responseContent, artifacts)
            : responseContent;

        final assistantMessage = Message.assistant(
          content: displayContent,
          sessionId: state!.id,
        ).copyWith(artifacts: artifacts);

        state = state!.copyWith(
          messages: [...messagesWithoutTemp, assistantMessage],
        );
        
        messageNotifier.setIdle();

      } catch (claudeError) {
        final messagesWithoutTemp = state!.messages
            .where((m) => m.id != tempAssistantMessage.id)
            .toList();

        final errorMessage = Message.system(
          content: 'Mi dispiace, si è verificato un errore nel contattare Claude. Errore: ${claudeError.toString()}',
          sessionId: state!.id,
        );
        
        state = state!.copyWith(
          messages: [...messagesWithoutTemp, errorMessage],
        );
        
        messageNotifier.setError('Errore Claude: ${claudeError.toString()}');
      }
    } catch (e) {
      messageNotifier.setError('Errore nell\'invio del messaggio: $e');
    }
  }

  Future<void> deleteCurrentSession() async {
    if (state == null) return;

    try {
      await SupabaseService.deleteChatSession(state!.id);
      state = null;

      _ref.invalidate(chatSessionsProvider);
    } catch (e) {
      _ref.read(messageStateProvider.notifier).setError('Errore nell\'eliminazione della chat: $e');
    }
  }
  
  void clearSession() {
    state = null;
  }
}

class MessageStateNotifier extends StateNotifier<AppMessageState> {
  MessageStateNotifier() : super(const AppMessageState.idle());
  
  void setSending() => state = const AppMessageState.sending();
  void setIdle() => state = const AppMessageState.idle();
  void setError(String message) => state = AppMessageState.error(message);
}

sealed class AppAuthState {
  const AppAuthState();
  
  const factory AppAuthState.loading() = AppAuthStateLoading;
  const factory AppAuthState.authenticated(SupabaseUserAccount account, Map<String, String?> userInfo) = AppAuthStateAuthenticated;
  const factory AppAuthState.unauthenticated() = AppAuthStateUnauthenticated;
  const factory AppAuthState.error(String message) = AppAuthStateError;
}

class AppAuthStateLoading extends AppAuthState {
  const AppAuthStateLoading();
}

class AppAuthStateAuthenticated extends AppAuthState {
  final SupabaseUserAccount account;
  final Map<String, String?> userInfo;
  const AppAuthStateAuthenticated(this.account, this.userInfo);
}

class AppAuthStateUnauthenticated extends AppAuthState {
  const AppAuthStateUnauthenticated();
}

class AppAuthStateError extends AppAuthState {
  final String message;
  const AppAuthStateError(this.message);
}

sealed class AppMessageState {
  const AppMessageState();
  
  const factory AppMessageState.idle() = AppMessageStateIdle;
  const factory AppMessageState.sending() = AppMessageStateSending;
  const factory AppMessageState.error(String message) = AppMessageStateError;
}

class AppMessageStateIdle extends AppMessageState {
  const AppMessageStateIdle();
}

class AppMessageStateSending extends AppMessageState {
  const AppMessageStateSending();
}

class AppMessageStateError extends AppMessageState {
  final String message;
  const AppMessageStateError(this.message);
}