// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() async {
  const tokenKey = 'cbd15974-8efd-4555-af5d-dc2a22a8e96e';
  const libraryId = '770018';
  const videoId = 'eb03f081-1264-475b-9ae5-db3752cc635c';
  final expires =
      (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 10800;

  final hashInput = '$tokenKey$videoId$expires';
  final token = sha256.convert(utf8.encode(hashInput)).toString();

  final embedUrl =
      'https://iframe.mediadelivery.net/embed/$libraryId/$videoId?token=$token&expires=$expires';

  print('Testing Embed URL: $embedUrl');
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(embedUrl));
    final res = await req.close();
    print('Embed Status: ${res.statusCode} ${res.reasonPhrase}');
    final body = await utf8.decodeStream(res);
    print(
      'Embed Body preview: ${body.substring(0, body.length > 250 ? 250 : body.length)}',
    );
  } catch (e) {
    print('Embed Error: $e');
  }
}
