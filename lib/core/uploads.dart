import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

/// Envio de arquivos (foto, PDF, áudio) direto para o Cloudinary.
class Uploads {
  static bool get enabled => AppConfig.cloudinaryCloud.isNotEmpty;

  static String typeFor(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (const ['m4a', 'aac', 'mp3', 'wav', 'ogg', 'opus', '3gp'].contains(ext)) return 'audio';
    if (const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'].contains(ext)) return 'image';
    return 'file';
  }

  static Future<Attachment> upload(Uint8List bytes, String name, {String folder = 'meupet', int seconds = 0}) async {
    if (!enabled) throw Exception('Envio de arquivos ainda não configurado.');
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloud}/auto/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(minutes: 2)));
    if (res.statusCode != 200) {
      String msg = 'código ${res.statusCode}';
      try {
        msg = (jsonDecode(res.body)['error']?['message'] ?? msg).toString();
      } catch (_) {}
      throw Exception('Não foi possível enviar o arquivo ($msg).');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return Attachment(url: j['secure_url'] as String, type: typeFor(name), name: name, seconds: seconds);
  }
}
