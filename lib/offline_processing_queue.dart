import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

class OfflineProcessingResult {
  final int processed;
  final int remaining;
  final bool isOnline;

  const OfflineProcessingResult({
    required this.processed,
    required this.remaining,
    required this.isOnline,
  });
}

class OfflineProcessingQueue {
  static const String _queueFileName = 'offline_processing_queue.json';
  static const String _queueFolderName = 'offline_processing_files';

  bool _isProcessing = false;

  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<int> pendingCount() async {
    final items = await _readQueue();
    return items.length;
  }

  Future<void> enqueueAudio(String filePath) {
    return _enqueue(type: 'audio', filePath: filePath);
  }

  Future<void> enqueueReceipt(String filePath) {
    return _enqueue(type: 'receipt', filePath: filePath);
  }

  Future<OfflineProcessingResult> processPending(
      DatabaseService dbService) async {
    final online = await hasInternet();
    if (!online) {
      return OfflineProcessingResult(
        processed: 0,
        remaining: await pendingCount(),
        isOnline: false,
      );
    }

    if (_isProcessing) {
      return OfflineProcessingResult(
        processed: 0,
        remaining: await pendingCount(),
        isOnline: true,
      );
    }

    _isProcessing = true;
    int processed = 0;

    try {
      final items = await _readQueue();
      final remaining = <Map<String, dynamic>>[];

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final path = item['path'] as String?;
        final type = item['type'] as String?;

        if (path == null || type == null || !File(path).existsSync()) {
          continue;
        }

        final result = type == 'audio'
            ? await dbService.uploadAndAnalyzeAudio(path)
            : await dbService.uploadAndAnalyzeReceipt(path);

        if (result == 'Success') {
          processed++;
          final f = File(path);
          if (f.existsSync()) await f.delete();
        } else if (result == 'Connection Failed' || result == 'Quota Full') {
          remaining.add(item);
          remaining.addAll(items.skip(index + 1));
          break;
        } else {
          remaining.add(item);
        }
      }

      await _writeQueue(remaining);

      return OfflineProcessingResult(
        processed: processed,
        remaining: remaining.length,
        isOnline: true,
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _enqueue({
    required String type,
    required String filePath,
  }) async {
    final source = File(filePath);
    if (!source.existsSync()) return;

    final queueDir = await _queueDirectory();
    final extension = _extensionFor(filePath, type);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final queuedPath = '${queueDir.path}${Platform.pathSeparator}$id$extension';

    await source.copy(queuedPath);

    final items = await _readQueue();
    items.add({
      'id': id,
      'type': type,
      'path': queuedPath,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writeQueue(items);
  }

  Future<Directory> _queueDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final queueDir =
        Directory('${appDir.path}${Platform.pathSeparator}$_queueFolderName');
    if (!queueDir.existsSync()) {
      await queueDir.create(recursive: true);
    }
    return queueDir;
  }

  Future<File> _queueFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}${Platform.pathSeparator}$_queueFileName');
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final file = await _queueFile();
    if (!file.existsSync()) return [];

    try {
      final raw = await file.readAsString();
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {
      return [];
    }

    return [];
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> items) async {
    final file = await _queueFile();
    await file.writeAsString(json.encode(items));
  }

  String _extensionFor(String filePath, String type) {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < filePath.length - 1) {
      return filePath.substring(dotIndex);
    }
    return type == 'audio' ? '.m4a' : '.jpg';
  }
}
