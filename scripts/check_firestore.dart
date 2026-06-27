// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  final projectId = args.isNotEmpty ? args[0] : 'liahona-quiz';
  print('Lendo dados do Firestore para o projeto: $projectId');

  // Obter token
  final tokenResult = await Process.run('gcloud', ['auth', 'print-access-token']);
  if (tokenResult.exitCode != 0) {
    print('Erro gcloud: ${tokenResult.stderr}');
    exit(1);
  }
  final accessToken = (tokenResult.stdout as String).trim();

  // Listar documentos
  final uri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/perguntas?pageSize=5',
  );

  final res = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  if (res.statusCode != 200) {
    print('Erro Firestore: ${res.statusCode} ${res.body}');
    exit(1);
  }

  final data = jsonDecode(utf8.decode(res.bodyBytes));
  final documents = data['documents'] as List?;
  if (documents == null || documents.isEmpty) {
    print('Nenhum documento encontrado.');
    return;
  }

  for (final doc in documents) {
    final fields = doc['fields'] as Map;
    final pergunta = fields['pergunta']?['stringValue'];
    print('Documento ID: ${doc['name'].split('/').last}');
    print('Pergunta: $pergunta');
    print('---');
  }
}
