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

      const systemPrompt = '''IMPORTANT: When the user asks you to create ANY document, file, or content, you MUST use this EXACT format:

```language filename.extension
[file content here]
```

The filename MUST be on the same line as the language tag, separated by a space.

Examples for CODE:
```python fibonacci.py
def fibonacci(n):
    return n if n <= 1 else fibonacci(n-1) + fibonacci(n-2)
```

Examples for TEXT DOCUMENTS:
```text document.txt
This is a plain text document with content.
```

Examples for CSV/EXCEL:
```csv data.csv
Name,Age,City
John,30,New York
Jane,25,London
```

Examples for MARKDOWN:
```markdown notes.md
# My Notes
This is a formatted document.
```

This works for ALL file types: code (py, js, java), documents (txt, md, csv, xml), and any other format.
ALWAYS include the filename with extension. This is REQUIRED.''';

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