import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../domain/entities/message.dart';

class ClaudeApiService {
  static const String baseUrl = 'https://api.anthropic.com/v1';
  static const String apiVersion = '2023-06-01';
  
  final Dio _dio;
  final String? apiKey;
  
  ClaudeApiService({String? apiKey}) 
      : apiKey = apiKey ?? const String.fromEnvironment('CLAUDE_API_KEY'),
        _dio = Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.headers = {
      'anthropic-version': apiVersion,
      'content-type': 'application/json',
    };
    
    if (this.apiKey != null && this.apiKey!.isNotEmpty) {
      _dio.options.headers['x-api-key'] = this.apiKey;
    }
  }
  
  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;
  
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required List<Message> history,
    String model = 'claude-3-haiku-20240307',
    int maxTokens = 4096,
  }) async {
    if (!hasApiKey) {
      throw Exception('Claude API key non configurata');
    }

    try {
      final messages = [
        ...history.map((m) => {
          'role': m.isUser ? 'user' : 'assistant',
          'content': m.content,
        }),
        {
          'role': 'user',
          'content': message,
        },
      ];

      const systemPrompt = '''Sei un assistente AI intelligente. Quando l'utente ti chiede di creare un documento, file, codice, o qualsiasi contenuto scaricabile:

1. Scrivi una breve introduzione
2. Poi crea il documento usando questo formato esatto:
   ```linguaggio nomefile.estensione
   [contenuto del documento]
   ```

Esempi:
- Per Python: ```python calcolo_fibonacci.py
- Per JavaScript: ```javascript app.js
- Per HTML: ```html index.html
- Per testo: ```text documento.txt
- Per Markdown: ```markdown README.md

IMPORTANTE: Il nome del file DEVE essere sulla stessa riga del linguaggio, separato da uno spazio.

Questo permette all'utente di scaricare il documento creato.''';

      final response = await _dio.post('/messages', data: {
        'model': model,
        'max_tokens': maxTokens,
        'system': systemPrompt,
        'messages': messages,
      });
      
      final content = response.data['content'][0]['text'] ?? '';
      
      return {
        'content': content,
        'tokens_used': (response.data['usage']['input_tokens'] ?? 0) + 
                      (response.data['usage']['output_tokens'] ?? 0),
      };
      
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('API key non valida');
      }
      throw Exception('Errore Claude: ${e.message}');
    }
  }
}