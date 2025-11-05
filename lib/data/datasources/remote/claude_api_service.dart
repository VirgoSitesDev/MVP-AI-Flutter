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

1. Scrivi una breve introduzione (1-2 righe)
2. Poi crea SEMPRE il documento usando questo formato esatto:
   ```linguaggio nomefile.estensione
   [contenuto del documento]
   ```

REGOLE FONDAMENTALI:
- OGNI richiesta di documento DEVE generare un code block scaricabile
- Se l'utente chiede "un documento su X", usa ```text documento_x.txt
- Se l'utente chiede "un codice Python", usa ```python nome_file.py
- Se l'utente chiede contenuto formattato, usa ```markdown documento.md
- Il nome file DEVE essere sulla stessa riga del linguaggio, separato da uno spazio

Esempi:
- "Creami un documento sulla storia di Roma" → ```text storia_roma.txt
- "Fammi un codice Python per fibonacci" → ```python fibonacci.py
- "Scrivimi un documento formattato" → ```markdown documento.md
- "Creami un file HTML" → ```html index.html
- "Dammi un documento Excel" → ```text dati.csv (per tabelle usa formato CSV)

IMPORTANTE: SEMPRE creare il code block con nome file, anche per semplici documenti di testo. L'utente deve poter scaricare TUTTO.''';

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