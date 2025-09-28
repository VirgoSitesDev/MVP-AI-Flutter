import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'google_auth_service.dart';
import '../../../domain/entities/gmail_message.dart';

class GmailService {
  static final GmailService _instance = GmailService._internal();
  factory GmailService() => _instance;
  GmailService._internal();

  gmail.GmailApi? _gmailApi;
  final GoogleAuthService _authService = GoogleAuthService();

  Future<void> initialize() async {
    try {
      print('🔧 Gmail Service: Inizializzazione...');
      final client = await _authService.getAuthenticatedClient();
      if (client == null) {
        print('❌ Gmail Service: Client non autenticato');
        throw Exception('Client non autenticato - Effettua il login con Google Workspace');
      }
      print('✅ Gmail Service: Client autenticato ottenuto');
      _gmailApi = gmail.GmailApi(client);

      await _testGmailAccess();
      print('✅ Gmail Service: Inizializzazione completata');
    } catch (e) {
      print('❌ Gmail Service: Errore inizializzazione: $e');
      rethrow;
    }
  }

  Future<void> _testGmailAccess() async {
    try {
      if (_gmailApi == null) {
        print('❌ Gmail Service: API non inizializzata per test accesso');
        return;
      }

      print('🔍 Gmail Service: Test accesso Gmail...');
      final profile = await _gmailApi!.users.getProfile('me');
      print('✅ Gmail Service: Accesso Gmail confermato - Email: ${profile.emailAddress}');
    } catch (e) {
      print('❌ Gmail Service: Test accesso fallito: $e');
      if (e.toString().contains('403') || e.toString().contains('insufficient')) {
        throw Exception('Accesso Gmail non autorizzato - Clicca su "Autorizza Gmail" per concedere i permessi');
      }
      rethrow;
    }
  }

  Future<List<GmailMessage>> getMessages({
    String query = '',
    int maxResults = 20,
    String? labelIds,
    String? pageToken,
  }) async {
    try {
      print('🔍 Gmail Service: getMessages chiamato con query="$query", labelIds="$labelIds", maxResults=$maxResults');
      await _ensureInitialized();

      final listRequest = await _gmailApi!.users.messages.list(
        'me',
        q: query.isNotEmpty ? query : null,
        maxResults: maxResults,
        labelIds: labelIds?.split(','),
        pageToken: pageToken,
      );

      print('📧 Gmail Service: Risposta API - ${listRequest.messages?.length ?? 0} messaggi trovati');

      if (listRequest.messages == null || listRequest.messages!.isEmpty) {
        print('📭 Gmail Service: Nessun messaggio trovato nella risposta API');
        return [];
      }

      final messages = <GmailMessage>[];
      print('🔄 Gmail Service: Elaborazione ${listRequest.messages!.length} messaggi...');

      for (final messageRef in listRequest.messages!) {
        if (messageRef.id != null) {
          print('📩 Gmail Service: Caricamento messaggio ${messageRef.id}');
          final fullMessage = await getMessage(messageRef.id!);
          if (fullMessage != null) {
            messages.add(fullMessage);
            print('✅ Gmail Service: Messaggio ${messageRef.id} caricato - Subject: ${fullMessage.subject}');
          } else {
            print('❌ Gmail Service: Messaggio ${messageRef.id} non caricato');
          }
        }
      }

      print('📬 Gmail Service: Totale messaggi elaborati: ${messages.length}');
      return messages;
    } catch (e) {
      print('❌ Gmail Service: Errore in getMessages: $e');
      rethrow;
    }
  }

  Future<GmailMessage?> getMessage(String messageId) async {
    try {
      await _ensureInitialized();

      print('📄 Gmail Service: Caricamento dettagli messaggio $messageId');
      final message = await _gmailApi!.users.messages.get(
        'me',
        messageId,
        format: 'full',
      );

      final gmailMessage = GmailMessage.fromJson(message.toJson());
      print('✅ Gmail Service: Messaggio $messageId caricato - From: ${gmailMessage.from}, Subject: ${gmailMessage.subject}');
      return gmailMessage;
    } catch (e) {
      print('❌ Gmail Service: Errore caricamento messaggio $messageId: $e');
      return null;
    }
  }

  Future<List<GmailMessage>> getInboxMessages({int maxResults = 20}) async {
    return getMessages(
      labelIds: 'INBOX',
      maxResults: maxResults,
    );
  }

  Future<List<GmailMessage>> getUnreadMessages({int maxResults = 20}) async {
    return getMessages(
      query: 'is:unread',
      maxResults: maxResults,
    );
  }

  Future<List<GmailMessage>> getImportantMessages({int maxResults = 20}) async {
    return getMessages(
      query: 'is:important',
      maxResults: maxResults,
    );
  }

  Future<List<GmailMessage>> searchMessages({
    required String query,
    int maxResults = 20,
  }) async {
    return getMessages(
      query: query,
      maxResults: maxResults,
    );
  }

  Future<List<GmailMessage>> getMessagesFromSender({
    required String senderEmail,
    int maxResults = 20,
  }) async {
    return getMessages(
      query: 'from:$senderEmail',
      maxResults: maxResults,
    );
  }

  Future<List<GmailMessage>> getMessagesBySubject({
    required String subject,
    int maxResults = 20,
  }) async {
    return getMessages(
      query: 'subject:"$subject"',
      maxResults: maxResults,
    );
  }

  Future<List<GmailMessage>> getRecentMessages({
    int days = 7,
    int maxResults = 20,
  }) async {
    final date = DateTime.now().subtract(Duration(days: days));
    final dateString = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return getMessages(
      query: 'after:$dateString',
      maxResults: maxResults,
    );
  }

  Future<GmailThread?> getThread(String threadId) async {
    try {
      await _ensureInitialized();

      final thread = await _gmailApi!.users.threads.get(
        'me',
        threadId,
        format: 'full',
      );

      return GmailThread.fromJson(thread.toJson());
    } catch (e) {
      return null;
    }
  }

  Future<List<gmail.Label>> getLabels() async {
    try {
      await _ensureInitialized();

      final response = await _gmailApi!.users.labels.list('me');
      return response.labels ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getMessageCounts() async {
    try {
      await _ensureInitialized();

      final profile = await _gmailApi!.users.getProfile('me');

      return {
        'total': profile.messagesTotal ?? 0,
        'threads': profile.threadsTotal ?? 0,
      };
    } catch (e) {
      return {
        'total': 0,
        'threads': 0,
      };
    }
  }

  Future<bool> markAsRead(String messageId) async {
    try {
      await _ensureInitialized();

      await _gmailApi!.users.messages.modify(
        gmail.ModifyMessageRequest(
          removeLabelIds: ['UNREAD'],
        ),
        'me',
        messageId,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAsUnread(String messageId) async {
    try {
      await _ensureInitialized();

      await _gmailApi!.users.messages.modify(
        gmail.ModifyMessageRequest(
          addLabelIds: ['UNREAD'],
        ),
        'me',
        messageId,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addStar(String messageId) async {
    try {
      await _ensureInitialized();

      await _gmailApi!.users.messages.modify(
        gmail.ModifyMessageRequest(
          addLabelIds: ['STARRED'],
        ),
        'me',
        messageId,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeStar(String messageId) async {
    try {
      await _ensureInitialized();

      await _gmailApi!.users.messages.modify(
        gmail.ModifyMessageRequest(
          removeLabelIds: ['STARRED'],
        ),
        'me',
        messageId,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<gmail.Profile?> getUserProfile() async {
    try {
      await _ensureInitialized();
      return await _gmailApi!.users.getProfile('me');
    } catch (e) {
      return null;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_gmailApi == null) {
      await initialize();
      if (_gmailApi == null) {
        throw Exception('Gmail Service non inizializzato - Verifica che l\'account Google sia autorizzato per Gmail');
      }
    }
  }

  String formatEmailContent(GmailMessage message) {
    final buffer = StringBuffer();

    buffer.writeln('From: ${message.from}');
    buffer.writeln('To: ${message.to}');
    buffer.writeln('Subject: ${message.subject}');
    buffer.writeln('Date: ${message.date.toString()}');
    buffer.writeln('');
    buffer.writeln(message.bodyText);

    return buffer.toString();
  }

  String extractEmailSummary(GmailMessage message, {int maxLength = 200}) {
    final text = message.bodyText;
    if (text.length <= maxLength) return text;

    final trimmed = text.substring(0, maxLength);
    final lastSpace = trimmed.lastIndexOf(' ');

    if (lastSpace > maxLength * 0.8) {
      return '${trimmed.substring(0, lastSpace)}...';
    }

    return '$trimmed...';
  }
}