import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/message.dart';
import '../../../domain/entities/chat_session.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> signInWithGoogle() async {
    try {
      String? redirectTo;
      if (kIsWeb) {
        if (Uri.base.host.contains('netlify') || Uri.base.host.contains('virgo')) {
          redirectTo = Uri.base.toString();
        } else {
          redirectTo = 'http://localhost:${Uri.base.port}';
        }
      }

      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        scopes: 'email profile',
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  static String get currentUserId {
    final user = client.auth.currentUser;
    if (user != null) {
      return user.id;
    }
    throw Exception('User not authenticated. Please sign in with Google first.');
  }

  static bool get isAuthenticated {
    return client.auth.currentUser != null;
  }

  static Future<List<ChatSession>> getChatSessions() async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      final response = await client
          .from('chat_sessions')
          .select()
          .eq('user_id', currentUserId)
          .order('updated_at', ascending: false);

      return (response as List).map((json) => ChatSession(
        id: json['id'],
        title: json['title'] ?? 'Chat senza titolo',
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      )).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<ChatSession> createChatSession(String title) async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      final response = await client
          .from('chat_sessions')
          .insert({
            'user_id': currentUserId,
            'title': title,
          })
          .select()
          .single();

      return ChatSession(
        id: response['id'],
        title: response['title'],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteChatSession(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      await client.from('messages').delete().eq('session_id', sessionId);
      await client.from('chat_sessions').delete().eq('id', sessionId);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateChatSessionTitle(String sessionId, String newTitle) async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      await client
          .from('chat_sessions')
          .update({
            'title': newTitle,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Message>> getMessages(String sessionId) async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      final response = await client
          .from('messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => Message(
        id: json['id'],
        content: json['content'],
        isUser: json['is_user'] == true,
        timestamp: DateTime.parse(json['created_at']),
        sessionId: sessionId,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Message> saveMessage({
    required String content,
    required bool isUser,
    required String sessionId,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      final response = await client
          .from('messages')
          .insert({
            'session_id': sessionId,
            'content': content,
            'is_user': isUser,
          })
          .select()
          .single();

      await client
          .from('chat_sessions')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', sessionId);

      return Message(
        id: response['id'],
        content: response['content'],
        isUser: response['is_user'] == true,
        timestamp: DateTime.parse(response['created_at']),
        sessionId: sessionId,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendToClaude({
    required String message,
    required List<Message> history,
    required String sessionId,
  }) async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      await saveMessage(
        content: message,
        isUser: true,
        sessionId: sessionId,
      );

      final formattedHistory = history.map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      }).toList();

      formattedHistory.add({
        'role': 'user',
        'content': message,
      });

      const systemPrompt = '''When creating documents or code files, use this format:

```language filename.ext
content
```

Example: ```python script.py''';

      final response = await client.functions.invoke(
        'claude-proxy',
        body: {
          'message': message,
          'session_id': sessionId,
          'history': formattedHistory,
          'user_id': currentUserId,
          'system': systemPrompt,
        },
      );

      if (response.data == null) {
        throw Exception('Nessuna risposta dalla edge function');
      }

      if (response.data is Map && response.data['error'] != null) {
        throw Exception(response.data['error']);
      }

      if (response.data is String) {
        if (response.data.toString().toLowerCase().contains('error')) {
          throw Exception(response.data);
        }
        final assistantContent = response.data.toString();

        await saveMessage(
          content: assistantContent,
          isUser: false,
          sessionId: sessionId,
        );

        return {
          'content': assistantContent,
          'tokens_used': 0,
          'cost_cents': 0,
        };
      }

      if (response.data is Map) {
        final responseData = response.data as Map<String, dynamic>;

        final assistantContent = responseData['content'] ?? responseData['response'] ?? '';

        if (assistantContent.isNotEmpty) {
          await saveMessage(
            content: assistantContent,
            isUser: false,
            sessionId: sessionId,
          );
        }

        return {
          'content': assistantContent,
          'tokens_used': responseData['tokens_used'] ?? 0,
          'cost_cents': responseData['cost_cents'] ?? 0,
        };
      }

      throw Exception('Formato di risposta non riconosciuto: ${response.data.runtimeType}');

    } catch (e, stackTrace) {
      rethrow;
    }
  }

  static Future<Map<String, int>> getUserUsage() async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

      final response = await client
          .from('usage_logs')
          .select('tokens_used, cost_cents')
          .eq('user_id', currentUserId)
          .gte('created_at', oneDayAgo);

      int totalTokens = 0;
      int totalCost = 0;

      for (final log in response as List) {
        totalTokens += (log['tokens_used'] as int? ?? 0);
        totalCost += (log['cost_cents'] as int? ?? 0);
      }

      return {
        'messages': (response as List).length,
        'tokens': totalTokens,
        'cost_cents': totalCost,
      };
    } catch (e) {
      return {
        'messages': 0,
        'tokens': 0,
        'cost_cents': 0,
      };
    }
  }

  static Future<bool> testConnection() async {
    try {
      await client.from('chat_sessions').select().limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}