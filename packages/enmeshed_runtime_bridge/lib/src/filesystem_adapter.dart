import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class FilesystemAdapter {
  Future<Directory> getDirectoryForStorage(String storageName) async => switch (storageName) {
    'data' || 'app' => await getApplicationDocumentsDirectory(),
    'temp' => await getTemporaryDirectory(),
    'cal' => await getApplicationSupportDirectory(),
    _ => throw Exception('Unknown storage name: $storageName'),
  };

  Future<String> readFile(String path, String storageName) async {
    final directory = await getDirectoryForStorage(storageName);

    final file = File('${directory.path}/$path');
    final content = await file.readAsString();
    return content;
  }

  Future<Uint8List> readFileAsBinary(String path, String storageName) async {
    final directory = await getDirectoryForStorage(storageName);

    final file = File('${directory.path}/$path');
    final content = await file.readAsBytes();
    return content;
  }

  Future<void> writeFile(String path, String storageName, String content, [bool append = false]) async {
    final directory = await getDirectoryForStorage(storageName);

    final file = await File('${directory.path}/$path').create(recursive: true);
    await file.writeAsString(content, mode: append ? FileMode.append : FileMode.write);
  }

  Future<void> deleteFile(String path, String storageName) async {
    final directory = await getDirectoryForStorage(storageName);

    final file = File('${directory.path}/$path');
    await file.delete();
  }

  Future<List<String>> listFiles(String path, String storageName) async {
    final directory = await getDirectoryForStorage(storageName);

    final files = await Directory('${directory.path}/$path').list().toList();
    return files.map((e) => e.path).toList();
  }

  Future<bool> existsFile(String path, String storageName) async {
    final directory = await getDirectoryForStorage(storageName);

    final file = File('${directory.path}/$path');
    return await file.exists();
  }
}
