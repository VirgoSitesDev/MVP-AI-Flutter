import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelGenerator {
  /// Generates an Excel file from table data
  /// Returns the Excel file as bytes (Uint8List)
  static Uint8List? generateExcel({
    required List<String> headers,
    required List<List<String>> data,
    String sheetName = 'Sheet1',
  }) {
    try {
      // Create a new Excel document
      final excel = Excel.createExcel();

      // Get or create the default sheet
      final Sheet? defaultSheet = excel.sheets[excel.getDefaultSheet()];
      if (defaultSheet != null) {
        excel.delete(excel.getDefaultSheet()!);
      }

      excel.copy(sheetName, sheetName);
      final Sheet sheet = excel[sheetName];

      // Add headers
      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: col,
          rowIndex: 0,
        ));
        cell.value = TextCellValue(headers[col]);

        // Style headers: bold and background color
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
          fontColorHex: ExcelColor.white,
        );
      }

      // Add data rows
      for (int row = 0; row < data.length; row++) {
        final rowData = data[row];
        for (int col = 0; col < rowData.length; col++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: col,
            rowIndex: row + 1, // +1 because row 0 is headers
          ));

          // Try to parse as number, otherwise use as text
          final String value = rowData[col];
          final double? numValue = double.tryParse(value);

          if (numValue != null) {
            cell.value = DoubleCellValue(numValue);
          } else {
            cell.value = TextCellValue(value);
          }
        }
      }

      // Auto-fit columns (set reasonable width)
      for (int col = 0; col < headers.length; col++) {
        sheet.setColumnWidth(col, 20);
      }

      // Encode to bytes
      final List<int>? bytes = excel.encode();
      if (bytes == null) {
        print('[ExcelGenerator] Error: Failed to encode Excel file');
        return null;
      }

      print('[ExcelGenerator] Generated Excel: ${headers.length} columns, ${data.length} rows, ${bytes.length} bytes');
      return Uint8List.fromList(bytes);
    } catch (e) {
      print('[ExcelGenerator] Error generating Excel: $e');
      return null;
    }
  }

  /// Generates Excel from CSV content
  static Uint8List? generateExcelFromCSV(String csvContent, {String sheetName = 'Sheet1'}) {
    try {
      final lines = csvContent.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        return null;
      }

      // Parse headers
      final headers = _parseCSVLine(lines[0]);

      // Parse data
      final data = <List<String>>[];
      for (int i = 1; i < lines.length; i++) {
        final row = _parseCSVLine(lines[i]);
        if (row.isNotEmpty) {
          data.add(row);
        }
      }

      return generateExcel(
        headers: headers,
        data: data,
        sheetName: sheetName,
      );
    } catch (e) {
      print('[ExcelGenerator] Error generating Excel from CSV: $e');
      return null;
    }
  }

  /// Parse a CSV line with quote handling
  static List<String> _parseCSVLine(String line) {
    final List<String> result = [];
    final StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(currentField.toString().trim());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }

    result.add(currentField.toString().trim());
    return result;
  }
}
