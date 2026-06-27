// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  final projectId = args.isNotEmpty ? args[0] : 'liahona-quiz';
  print('Iniciando limpeza total da coleção "perguntas" no projeto: $projectId');

  // Obter token
  final tokenResult = await Process.run('gcloud', ['auth', 'print-access-token']);
  if (tokenResult.exitCode != 0) {
    print('Erro gcloud: ${tokenResult.stderr}');
    exit(1);
  }
  final accessToken = (tokenResult.stdout as String).trim();

  // Listar todos os documentos
  final listUri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/perguntas?pageSize=300',
  );

  int totalDeleted = 0;
  while (true) {
    print('Buscando documentos para deletar (página de até 300)...');
    final res = await http.get(
      listUri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (res.statusCode != 200) {
      print('Erro ao obter documentos: ${res.statusCode} ${res.body}');
      exit(1);
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final documents = data['documents'] as List?;
    if (documents == null || documents.isEmpty) {
      break;
    }

    print('Encontrados ${documents.length} documentos nesta página. Excluindo em paralelo...');

    final List<Future<void>> deleteFutures = [];
    for (final doc in documents) {
      final name = doc['name'] as String;
      final deleteUri = Uri.parse('https://firestore.googleapis.com/v1/$name');
      
      deleteFutures.add(() async {
        try {
          final delRes = await http.delete(
            deleteUri,
            headers: {'Authorization': 'Bearer $accessToken'},
          );

          if (delRes.statusCode == 200 || delRes.statusCode == 204) {
            print('  Deletado: ${name.split('/').last}');
          } else {
            print('  Falha ao deletar ${name.split('/').last}: ${delRes.statusCode}');
          }
        } catch (e) {
          print('  Erro ao deletar ${name.split('/').last}: $e');
        }
      }());
    }

    await Future.wait(deleteFutures);
    totalDeleted += documents.length;
    
    // Pequeno delay para evitar sobrecarga antes da próxima listagem
    await Future.delayed(const Duration(milliseconds: 500));
  }

  print('\nLimpeza concluída com sucesso! Total de documentos deletados: $totalDeleted');
}
