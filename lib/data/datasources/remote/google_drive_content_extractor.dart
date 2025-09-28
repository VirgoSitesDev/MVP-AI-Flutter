// lib/data/datasources/remote/google_drive_content_extractor.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart' as excel_lib; // Import della libreria Excel
import 'google_drive_service.dart';

class StructuredContent {
  final String type; // 'text', 'table'
  final String? text;
  final List<List<String>>? tableData;
  final List<String>? headers;
  final String title;

  StructuredContent({
    required this.type,
    this.text,
    this.tableData,
    this.headers,
    required this.title,
  });

  bool get isTable => type == 'table';
  bool get isText => type == 'text';
}

class GoogleDriveContentExtractor {
  final GoogleDriveService _driveService = GoogleDriveService();
  
  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  static const int maxTextLength = 100000;
  static const int maxExcelRows = 1000;
  
  Future<StructuredContent> extractStructuredContent(DriveFile file) async {
    try {

      // Per file Google Workspace, usa l'export
      if (file.mimeType?.startsWith('application/vnd.google-apps') ?? false) {
        return await _extractGoogleWorkspaceStructuredContent(file);
      }

      // Per altri file, verifica il tipo
      switch (file.mimeType) {
        case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        case 'application/vnd.ms-excel':
        case 'application/x-excel':
        case 'application/x-msexcel':
          return await _extractExcelStructuredContent(file);
        default:
          // Per altri tipi, ritorna come testo
          final textContent = await extractContent(file);
          return StructuredContent(
            type: 'text',
            text: textContent,
            title: file.name,
          );
      }
    } catch (e) {
      return StructuredContent(
        type: 'text',
        text: _getFileMetadata(file, reason: 'Errore: ${e.toString()}'),
        title: file.name,
      );
    }
  }

  Future<String> extractContent(DriveFile file) async {
    try {
      
      // Per file Google Workspace, usa l'export
      if (file.mimeType?.startsWith('application/vnd.google-apps') ?? false) {
        return await _extractGoogleWorkspaceContent(file);
      }
      
      // Per altri file, verifica il tipo
      switch (file.mimeType) {
        case 'text/plain':
        case 'text/csv':
        case 'text/html':
        case 'text/xml':
        case 'application/json':
        case 'text/markdown':
          return await _extractTextContent(file);
          
        case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        case 'application/vnd.ms-excel':
        case 'application/x-excel':
        case 'application/x-msexcel':
          return await _extractExcelContent(file);
          
        case 'application/pdf':
          return await _extractPdfMetadata(file);
          
        case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        case 'application/msword':
          return await _extractWordMetadata(file);
          
        default:
          // Se il nome del file termina con .xlsx o .xls, prova comunque a leggerlo come Excel
          if (file.name.toLowerCase().endsWith('.xlsx') || 
              file.name.toLowerCase().endsWith('.xls')) {
            return await _extractExcelContent(file);
          }
          return _getFileMetadata(file);
      }
    } catch (e) {
      return _getFileMetadata(file, reason: 'Errore: ${e.toString()}');
    }
  }
  
  Future<String> _extractExcelContent(DriveFile file) async {
    try {
      
      // Scarica il file
      final bytes = await _driveService.downloadFile(file.id);
      if (bytes == null || bytes.isEmpty) {
        return _getFileMetadata(file, reason: 'File Excel vuoto o non accessibile');
      }
      
      
      // Decodifica il file Excel
      final excel = excel_lib.Excel.decodeBytes(Uint8List.fromList(bytes));
      
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('📊 ${file.name}');
      buffer.writeln('Tipo: Microsoft Excel');
      buffer.writeln('Dimensione: ${file.size ?? "N/A"}');
      buffer.writeln('Fogli: ${excel.tables.length}');
      buffer.writeln('---\n');
      
      int totalRows = 0;
      
      // Itera attraverso tutti i fogli
      for (final tableName in excel.tables.keys) {
        final table = excel.tables[tableName];
        if (table == null) continue;
        
        buffer.writeln('FOGLIO: $tableName');
        buffer.writeln('Righe: ${table.maxRows}, Colonne: ${table.maxCols}');
        buffer.writeln('');
        
        // Estrai il contenuto del foglio
        int rowCount = 0;
        List<String>? headers;
        
        for (final row in table.rows) {
          rowCount++;
          totalRows++;
          
          // Limita il numero di righe per non sovraccaricare
          if (rowCount > maxExcelRows) {
            buffer.writeln('\n[... Foglio troncato dopo $maxExcelRows righe ...]');
            break;
          }
          
          // Converti la riga in stringa con formattazione migliorata
          final rowData = <String>[];
          for (final cell in row) {
            String cellText = '';
            
            if (cell != null && cell.value != null) {
              cellText = _formatCellValue(cell.value);
            }
            
            rowData.add(cellText);
          }
          
          // Rimuovi celle vuote alla fine per output più pulito
          while (rowData.isNotEmpty && rowData.last.isEmpty) {
            rowData.removeLast();
          }
          
          // Salta righe completamente vuote
          if (rowData.every((cell) => cell.isEmpty)) {
            continue;
          }
          
          // Se è la prima riga con dati, considerala come header
          if (headers == null && rowData.any((cell) => cell.isNotEmpty)) {
            headers = List.from(rowData);
            buffer.writeln('COLONNE: ${headers.join(' | ')}');
            buffer.writeln('-' * 50);
          } else if (rowData.any((cell) => cell.isNotEmpty)) {
            // Formatta i dati con gli headers se disponibili
            if (headers != null && headers.isNotEmpty) {
              final formattedRow = <String>[];
              for (int i = 0; i < rowData.length && i < headers.length; i++) {
                if (headers[i].isNotEmpty && rowData[i].isNotEmpty) {
                  formattedRow.add('${headers[i]}: ${rowData[i]}');
                } else if (rowData[i].isNotEmpty) {
                  formattedRow.add(rowData[i]);
                }
              }
              if (formattedRow.isNotEmpty) {
                buffer.writeln('Riga ${rowCount - 1}: ${formattedRow.join(', ')}');
              }
            } else {
              buffer.writeln('Riga $rowCount: ${rowData.join(' | ')}');
            }
          }
        }
        
        buffer.writeln('\n');
        
        // Se abbiamo già troppe righe totali, ferma
        if (totalRows > maxExcelRows * 2) {
          buffer.writeln('[... Altri fogli non mostrati per limiti di spazio ...]');
          break;
        }
      }
      
      // Aggiungi statistiche riassuntive
      buffer.writeln('---');
      buffer.writeln('RIEPILOGO:');
      buffer.writeln('Totale fogli processati: ${excel.tables.length}');
      buffer.writeln('Totale righe con dati: ${totalRows}');
      
      // Se il file sembra contenere dati specifici (basandoci sul nome)
      final fileName = file.name.toLowerCase();
      if (fileName.contains('vini') || fileName.contains('wine')) {
        buffer.writeln('\n📝 Database di vini identificato');
      } else if (fileName.contains('vendite') || fileName.contains('sales')) {
        buffer.writeln('\n📝 Report vendite identificato');
      } else if (fileName.contains('inventory') || fileName.contains('inventario')) {
        buffer.writeln('\n📝 Inventario identificato');
      }
      
      final content = buffer.toString();
      
      if (content.length > maxTextLength) {
        return content.substring(0, maxTextLength) + '\n\n[... contenuto Excel troncato ...]';
      }
      
      return content;
      
    } catch (e) {
      
      return _getExcelErrorMessage(file, e.toString());
    }
  }
  
  String _formatCellValue(dynamic cellValue) {
    if (cellValue == null) return '';
    
    String valueStr = cellValue.toString();
    
    if (valueStr.endsWith('.0')) {
      final withoutDecimal = valueStr.substring(0, valueStr.length - 2);
      if (int.tryParse(withoutDecimal) != null) {
        return withoutDecimal;
      }
    }
    
    final numValue = num.tryParse(valueStr);
    if (numValue != null && numValue >= 1000) {
      if (numValue == numValue.toInt()) {
        return _formatWithThousands(numValue.toInt());
      }
    }
    
    return valueStr;
  }
  
  String _formatWithThousands(int number) {
    String result = number.toString();
    String formatted = '';
    int count = 0;
    
    for (int i = result.length - 1; i >= 0; i--) {
      if (count == 3) {
        formatted = '.$formatted';
        count = 0;
      }
      formatted = result[i] + formatted;
      count++;
    }
    
    return formatted;
  }
  
  String _getExcelErrorMessage(DriveFile file, String error) {
    return """
📊 ${file.name}
Tipo: Microsoft Excel  
Dimensione: ${file.size ?? 'N/A'}
Ultima modifica: ${file.modifiedTime}

⚠️ Impossibile leggere il contenuto del file Excel

ERRORE TECNICO:
$error

SOLUZIONI CONSIGLIATE:
1. 📄 Converti il file in Google Sheets:
   - Apri il file in Google Drive
   - Fai clic destro → "Apri con" → "Google Sheets"
   - Il file convertito sarà leggibile automaticamente

2. 💾 Esporta come CSV:
   - Apri il file in Excel
   - File → Salva con nome → CSV
   - Carica il CSV su Google Drive

3. 🔒 Verifica permessi:
   - Il file potrebbe essere protetto da password
   - Controlla di avere i permessi di lettura

4. 📱 Prova formati alternativi:
   - Salva come .xls (formato Excel 97-2003)
   - Usa "Esporta" invece di "Salva con nome"

Link al file: ${file.webViewLink ?? 'N/A'}
""";
  }

  /// Estrae contenuto da file Google Workspace
  Future<String> _extractGoogleWorkspaceContent(DriveFile file) async {
    try {
      String exportMimeType;
      String fileType;
      
      switch (file.mimeType) {
        case 'application/vnd.google-apps.document':
          exportMimeType = 'text/plain';
          fileType = 'Google Docs';
          break;
        case 'application/vnd.google-apps.spreadsheet':
          exportMimeType = 'text/csv';
          fileType = 'Google Sheets';
          break;
        case 'application/vnd.google-apps.presentation':
          exportMimeType = 'text/plain';
          fileType = 'Google Slides';
          break;
        default:
          return _getFileMetadata(file);
      }
      
      
      final bytes = await _driveService.exportGoogleFile(file.id, file.mimeType!);
      
      if (bytes == null || bytes.isEmpty) {
        return _getFileMetadata(file);
      }
      
      String content;
      try {
        content = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        return _getFileMetadata(file);
      }
      
      // Se è un CSV da Google Sheets, formattalo meglio
      if (fileType == 'Google Sheets' && exportMimeType == 'text/csv') {
        content = _formatCsvContent(content, file.name);
      }
      
      if (content.length > maxTextLength) {
        content = content.substring(0, maxTextLength) + '\n\n[... contenuto troncato ...]';
      }
      
      return """
📄 ${file.name}
Tipo: $fileType
Ultima modifica: ${file.modifiedTime}
---
CONTENUTO:

$content

---
Fine del file: ${file.name}
""";
    } catch (e) {
      return _getFileMetadata(file);
    }
  }
  
  /// Estrae contenuto strutturato da Google Workspace
  Future<StructuredContent> _extractGoogleWorkspaceStructuredContent(DriveFile file) async {
    try {
      String exportMimeType;
      String fileType;

      switch (file.mimeType) {
        case 'application/vnd.google-apps.document':
          exportMimeType = 'text/plain';
          fileType = 'Google Docs';
          break;
        case 'application/vnd.google-apps.spreadsheet':
          exportMimeType = 'text/csv';
          fileType = 'Google Sheets';
          break;
        case 'application/vnd.google-apps.presentation':
          exportMimeType = 'text/plain';
          fileType = 'Google Slides';
          break;
        default:
          return StructuredContent(
            type: 'text',
            text: _getFileMetadata(file),
            title: file.name,
          );
      }


      final bytes = await _driveService.exportGoogleFile(file.id, file.mimeType!);

      if (bytes == null || bytes.isEmpty) {
        return StructuredContent(
          type: 'text',
          text: _getFileMetadata(file),
          title: file.name,
        );
      }

      String content;
      try {
        content = utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        return StructuredContent(
          type: 'text',
          text: _getFileMetadata(file),
          title: file.name,
        );
      }

      // Se è un CSV da Google Sheets, crealo come tabella strutturata
      if (fileType == 'Google Sheets' && exportMimeType == 'text/csv') {
        return _parseCSVToStructuredContent(content, file.name);
      }

      if (content.length > maxTextLength) {
        content = content.substring(0, maxTextLength) + '\n\n[... contenuto troncato ...]';
      }

      return StructuredContent(
        type: 'text',
        text: content,
        title: file.name,
      );
    } catch (e) {
      return StructuredContent(
        type: 'text',
        text: _getFileMetadata(file),
        title: file.name,
      );
    }
  }

  Future<StructuredContent> _extractExcelStructuredContent(DriveFile file) async {
    try {
      final bytes = await _driveService.downloadFile(file.id);
      if (bytes == null || bytes.isEmpty) {
        return StructuredContent(
          type: 'text',
          text: _getFileMetadata(file, reason: 'File Excel vuoto o non accessibile'),
          title: file.name,
        );
      }

      final excel = excel_lib.Excel.decodeBytes(Uint8List.fromList(bytes));

      if (excel.tables.isEmpty) {
        return StructuredContent(
          type: 'text',
          text: 'File Excel senza fogli dati',
          title: file.name,
        );
      }

      final firstSheet = excel.tables.values.first;
      if (firstSheet == null || firstSheet.rows.isEmpty) {
        return StructuredContent(
          type: 'text',
          text: 'Foglio Excel vuoto',
          title: file.name,
        );
      }

      List<String>? headers;
      List<List<String>> tableData = [];

      for (int i = 0; i < firstSheet.rows.length && i < maxExcelRows; i++) {
        final row = firstSheet.rows[i];
        final rowData = row.map((cell) =>
          cell?.value != null ? _formatCellValue(cell!.value) : ''
        ).toList();

        if (rowData.every((cell) => cell.isEmpty)) continue;

        if (headers == null) {
          headers = rowData;
        } else {
          tableData.add(rowData);
        }
      }

      return StructuredContent(
        type: 'table',
        tableData: tableData,
        headers: headers,
        title: file.name,
      );
    } catch (e) {
      return StructuredContent(
        type: 'text',
        text: _getExcelErrorMessage(file, e.toString()),
        title: file.name,
      );
    }
  }

  StructuredContent _parseCSVToStructuredContent(String csvContent, String fileName) {
    try {
      final lines = csvContent.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        return StructuredContent(
          type: 'text',
          text: 'File CSV vuoto',
          title: fileName,
        );
      }

      List<String>? headers;
      List<List<String>> tableData = [];

      for (int i = 0; i < lines.length && i < maxExcelRows; i++) {
        final line = lines[i];
        final rowData = _parseCSVLine(line);

        if (headers == null) {
          headers = rowData;
        } else {
          tableData.add(rowData);
        }
      }

      return StructuredContent(
        type: 'table',
        tableData: tableData,
        headers: headers,
        title: fileName,
      );
    } catch (e) {
      return StructuredContent(
        type: 'text',
        text: 'Errore nel parsing CSV: $e',
        title: fileName,
      );
    }
  }

  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    String currentCell = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(currentCell.trim());
        currentCell = '';
      } else {
        currentCell += char;
      }
    }

    result.add(currentCell.trim());
    return result;
  }

  String _formatCsvContent(String csvContent, String fileName) {
    try {
      final lines = csvContent.split('\n');
      if (lines.isEmpty) return csvContent;
      
      final buffer = StringBuffer();
      buffer.writeln('Dati CSV da: $fileName\n');
      
      if (lines.isNotEmpty) {
        buffer.writeln('COLONNE: ${lines[0]}');
        buffer.writeln('-' * 50);
      }
      
      for (int i = 1; i < lines.length && i <= maxExcelRows; i++) {
        if (lines[i].trim().isNotEmpty) {
          buffer.writeln('Riga $i: ${lines[i]}');
        }
      }
      
      if (lines.length > maxExcelRows) {
        buffer.writeln('\n[... CSV troncato dopo $maxExcelRows righe ...]');
      }
      
      return buffer.toString();
    } catch (e) {
      return csvContent;
    }
  }
  
  // ... resto dei metodi esistenti ...
  
  Future<String> _extractTextContent(DriveFile file) async {
    try {
      final bytes = await _driveService.downloadFile(file.id);
      if (bytes == null || bytes.isEmpty) {
        return _getFileMetadata(file, reason: 'File vuoto o non accessibile');
      }
      
      String content = utf8.decode(bytes, allowMalformed: true);
      content = _cleanContent(content);
      
      if (content.length > maxTextLength) {
        content = content.substring(0, maxTextLength) + '\n\n[... contenuto troncato ...]';
      }
      
      return """
📄 ${file.name}
Tipo: ${file.fileTypeDescription}
Dimensione: ${file.size ?? 'N/A'}
---
CONTENUTO:

$content

---
Fine del file: ${file.name}
""";
    } catch (e) {
      return _getFileMetadata(file, reason: 'Errore lettura: ${e.toString()}');
    }
  }
  
  // Gli altri metodi rimangono invariati...
  
  String _cleanContent(String content) {
    content = content.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    content = content.replaceAll('\r\n', '\n');
    content = content.replaceAll('\r', '\n');
    content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    content = content.replaceAll(RegExp(r' {3,}'), '  ');
    return content.trim();
  }
  
  String _getFileMetadata(DriveFile file, {String? reason}) {
    final buffer = StringBuffer();
    buffer.writeln('📎 ${file.name}');
    buffer.writeln('Tipo: ${file.fileTypeDescription}');
    if (file.size != null) buffer.writeln('Dimensione: ${file.size}');
    if (file.modifiedTime != null) {
      buffer.writeln('Ultima modifica: ${_formatDate(file.modifiedTime!)}');
    }
    if (reason != null) buffer.writeln('\n⚠️ $reason');
    if (file.webViewLink != null) buffer.writeln('\nLink: ${file.webViewLink}');
    return buffer.toString();
  }
  
  Future<String> _extractPdfMetadata(DriveFile file) async {
    return """
📕 ${file.name}
Tipo: PDF Document
Dimensione: ${file.size ?? 'N/A'}
Ultima modifica: ${file.modifiedTime}

[PDF: Considera l'uso di una libreria PDF per estrarre il testo]

Link: ${file.webViewLink ?? 'N/A'}
""";
  }
  
  Future<String> _extractWordMetadata(DriveFile file) async {
    return """
📝 ${file.name}
Tipo: Microsoft Word
Dimensione: ${file.size ?? 'N/A'}
Ultima modifica: ${file.modifiedTime}

[Word: Considera la conversione in Google Docs per accesso al contenuto]

Link: ${file.webViewLink ?? 'N/A'}
""";
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  Future<String> extractMultipleFiles(List<DriveFile> files) async {
    if (files.isEmpty) return '';
    
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('=== CONTESTO DAI FILE GOOGLE DRIVE ===\n');
    
    int totalSize = 0;
    const int maxTotalSize = 200000;
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      
      if (totalSize > maxTotalSize) {
        buffer.writeln('\n--- File ${i + 1}/${files.length} (solo riferimento) ---');
        buffer.writeln(_getFileMetadata(file, reason: 'Limite contesto raggiunto'));
        continue;
      }
      
      buffer.writeln('\n--- File ${i + 1}/${files.length} ---');
      
      final content = await extractContent(file);
      
      if (totalSize + content.length > maxTotalSize) {
        final remainingSpace = maxTotalSize - totalSize;
        if (remainingSpace > 1000) {
          buffer.writeln(content.substring(0, remainingSpace));
          buffer.writeln('\n[... contenuto troncato per limiti di contesto ...]');
        } else {
          buffer.writeln(_getFileMetadata(file, reason: 'Limite contesto raggiunto'));
        }
        totalSize = maxTotalSize;
      } else {
        buffer.writeln(content);
        totalSize += content.length;
      }
    }
    
    buffer.writeln('\n=== FINE CONTESTO ===');
    
    buffer.writeln('\n📌 SOMMARIO FILE:');
    for (final file in files) {
      buffer.writeln('  • ${file.name} (${file.fileTypeDescription})');
    }
    
    return buffer.toString();
  }
}

extension on excel_lib.Sheet {
  get maxCols => null;
}