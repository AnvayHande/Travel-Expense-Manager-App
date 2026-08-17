import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class FileHelper {
  /// Saves the file locally and returns its path.
  /// On Web, this triggers a file download in the browser and returns 'web-downloaded'.
  static Future<String> saveFile(String fileName, Uint8List bytes, {String mimeType = 'application/octet-stream'}) async {
    if (kIsWeb) {
      final base64Data = base64Encode(bytes);
      final url = 'data:$mimeType;base64,$base64Data';
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
        
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      
      return 'web-downloaded';
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }
}
