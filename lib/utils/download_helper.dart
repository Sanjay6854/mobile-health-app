import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart'; // For mobile
import 'package:url_launcher/url_launcher.dart'; // For web

Future<void> downloadPrescription(String base64String) async {
  try {
    Uint8List bytes = base64Decode(base64String);
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/prescription.pdf";
    File file = File(filePath);

    await file.writeAsBytes(bytes);

    if (kIsWeb) {
      // 🌐 Web: Open PDF in a new browser tab
      final encodedBytes = base64Encode(bytes);
      final blobUrl = "data:application/pdf;base64,$encodedBytes";
      await launch(blobUrl);
    } else {
      // 📱 Mobile: Open using `open_file`
      OpenFile.open(filePath);
    }
  } catch (e) {
    print("Error saving file: $e");
  }
}
