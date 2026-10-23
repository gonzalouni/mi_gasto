import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';

class BackupService {
  static Future<File> createBackupFile() async {
    final data = await DatabaseHelper.instance.exportAll();
    const encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(data);
    final dir = await getTemporaryDirectory();
    final name =
        'mi_gasto_respaldo_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';
    final file = File(p.join(dir.path, name));
    await file.writeAsString(json);
    return file;
  }

  static Future<void> restoreFromFile(String path) async {
    final content = await File(path).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El archivo de respaldo no es válido.');
    }
    final version = decoded['version'];
    if (version is! int ||
        version < 1 ||
        version > DatabaseHelper.backupVersion) {
      throw FormatException('Versión de respaldo no soportada: $version');
    }
    if (decoded['accounts'] is! List ||
        decoded['categories'] is! List ||
        decoded['transactions'] is! List) {
      throw const FormatException('El archivo de respaldo está incompleto.');
    }
    await DatabaseHelper.instance.importAll(decoded);
  }
}
