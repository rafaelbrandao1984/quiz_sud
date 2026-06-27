// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  final projectId = args.isNotEmpty ? args[0] : 'liahona-quiz';
  print('Iniciando script de automação para o projeto GCP (Vertex AI): $projectId');

  Future<String> getGcloudAccessToken() async {
    final tokenResult = await Process.run('gcloud', [
      'auth',
      'print-access-token',
    ]);
    if (tokenResult.exitCode != 0) {
      throw Exception('Erro ao obter token de acesso do gcloud: ${tokenResult.stderr}');
    }
    return (tokenResult.stdout as String).trim();
  }

  // 1. Obter token de acesso do gcloud para o Firestore e Vertex AI
  print('Obtendo token de acesso ativo do gcloud...');
  String accessToken;
  try {
    accessToken = await getGcloudAccessToken();
    print('Token de acesso obtido com sucesso!');
  } catch (e) {
    print(e);
    print(
      'Verifique se você fez login executando: gcloud auth application-default login',
    );
    exit(1);
  }

  // Lista dos 34 subtemas para gerar 1020 perguntas de alta qualidade
  final List<Map<String, String>> subThemes = [
    // Obras Padrão (obras_padrao)
    {
      'categoria': 'obras_padrao',
      'subtema': 'Velho Testamento: Gênesis, Criação, Moisés e Abraão.'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Velho Testamento: Profetas, Reis e Salmos.'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Novo Testamento: Evangelhos, Vida e Parábolas de Jesus.'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Novo Testamento: Atos dos Apóstolos e Epístolas.'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Livro de Mórmon: 1 Néfi a Omni (História de Leí a Mosias).'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Livro de Mórmon: Mosias a Alma (Reinado dos Juízes e guerras).'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Livro de Mórmon: Helamã a 3 Néfi (Sinais e a vinda de Jesus Cristo).'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Livro de Mórmon: 4 Néfi a Morôni (Destruição e promessa final).'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Doutrina e Convênios: Revelações iniciais e organização (Seções 1 a 35).'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Doutrina e Convênios: Estabelecimento em Ohio e Missouri (Seções 36 a 80).'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Doutrina e Convênios: Nauvoo, Sacerdócio e revelações eternas (Seções 81 a 138).'
    },
    {
      'categoria': 'obras_padrao',
      'subtema': 'Pérola de Grande Valor: Regras de Fé, Livro de Moisés e Abraão.'
    },

    // História da Igreja (historia_igreja)
    {
      'categoria': 'historia_igreja',
      'subtema': 'Infância de Joseph Smith, Primeira Visão e visitas de Morôni.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Obtenção das placas, tradução e as 3 e 8 testemunhas do Livro de Mórmon.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Kirtland: Edificação do templo, visões do véu e crise bancária.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Missouri: Perseguições, Far West, Ordem de Extermínio e Prisão de Liberty.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Nauvoo: Fundação da cidade, Sociedade de Socorro e ordenanças do templo.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Martírio de Joseph e Hyrum Smith na Prisão de Carthage.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Sucessão da Presidência, Brigham Young e preparação para o oeste.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Travessia pioneira, acampamento de Winter Quarters e chegada ao Vale do Lago Salgado.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Colonização de Utah, companhias de carrinhos de mão e expansão ocidental.'
    },
    {
      'categoria': 'historia_igreja',
      'subtema': 'Manifesto de 1890, templos modernos, pioneiros globais e era da tecnologia.'
    },

    // História no Brasil (historia_brasil)
    {
      'categoria': 'historia_brasil',
      'subtema': 'A chegada em Joinville, pioneiros de ascendência alemã (1928-1935).'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Abertura do trabalho em português e a Missão Sul-Americana.'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Início do trabalho no Rio de Janeiro, São Paulo e Paraná (décadas de 1930 e 1940).'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Período da Segunda Guerra Mundial, repatriação de missionários e liderança local.'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Criação da Missão Brasileira em 1959 e dedicação da capela da Rua Dr. Satamini.'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Consolidação, organização da primeira Estaca em São Paulo (1966).'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Dedicação do Templo de São Paulo (1978) - o primeiro da América do Sul.'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Expansão para o Nordeste, Norte e Centro-Oeste (décadas de 1980 e 1990).'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Abertura de novos templos regionais (Porto Alegre, Recife, Campinas, Curitiba).'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Líderes gerais brasileiros (Setentas e presidências auxiliares).'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Estatísticas atuais, estacas, missões e templos em construção no Brasil hoje.'
    },
    {
      'categoria': 'historia_brasil',
      'subtema': 'Programas educacionais (Seminário, Instituto e BYU-Pathway) no Brasil.'
    },
  ];

  final client = HttpClient();
  
  // Endpoint REST do Vertex AI usando a região padrão us-central1
  final geminiUri = Uri.parse(
    'https://us-central1-aiplatform.googleapis.com/v1/projects/$projectId/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent',
  );

  int totalGenerated = 0;

  final List<Map<String, String>> failedBatches = [];
  try {
    for (int i = 0; i < subThemes.length; i++) {
      final theme = subThemes[i];
      print('\n================================================================');
      print('[Lote ${i + 1}/${subThemes.length}] Inserindo subtema: "${theme['subtema']}"');
      print('================================================================');

      bool batchSuccess = false;
      int batchTry = 1;
      const maxBatchTries = 3;

      while (batchTry <= maxBatchTries && !batchSuccess) {
        if (batchTry > 1) {
          print('  [Retentativa] Nova tentativa para o Lote ${i + 1} (Tentativa $batchTry/$maxBatchTries) em 10 segundos...');
          await Future.delayed(const Duration(seconds: 10));
        }

        try {
          final prompt = '''
Você é um historiador e teólogo especialista em A Igreja de Jesus Cristo dos Santos dos Últimos Dias.
Você DEVE retornar o texto formatado estritamente em UTF-8 nativo, mantendo todos os acentos e cedilhas corretamente.

Gere uma lista de 30 perguntas de múltipla escolha inéditas para um jogo de perguntas e respostas (Quiz).
O tema específico deste lote é: "${theme['subtema']}"
A categoria a ser definida em todas as perguntas é: "${theme['categoria']}"

Cada pergunta deve possuir exatamente:
- Um texto curto e claro (campo "pergunta").
- Um array com exatamente 4 opções de alternativas plausíveis (campo "alternativas").
- Um número representando o índice da resposta correta no array de 0 a 3 (campo "resposta_correta").
- O campo "categoria" com o valor exato: "${theme['categoria']}".
- Um campo chamado "embasamento" contendo uma breve explicação histórica ou citação da escritura que justifica a resposta correta, servindo como material de estudo para o usuário.

Retorne estritamente um array JSON contendo objetos no seguinte formato:
[
  {
    "pergunta": "...",
    "alternativas": ["...", "...", "...", "..."],
    "resposta_correta": 0,
    "categoria": "${theme['categoria']}",
    "embasamento": "..."
  }
]
Não inclua blocos de formatação markdown (como ```json) ou qualquer outro texto explicativo. Retorne apenas o JSON puro.
''';

          final geminiPayload = {
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.8,
            }
          };

          // 1. Chamando o Gemini via Vertex AI com lógica de re-tentativa HTTP
          http.Response? geminiRes;
          int retries = 5;
          while (retries > 0) {
            try {
              geminiRes = await http.post(
                geminiUri,
                headers: {
                  'Content-Type': 'application/json; charset=utf-8',
                  'Authorization': 'Bearer $accessToken',
                },
                body: utf8.encode(jsonEncode(geminiPayload)),
              );

              if (geminiRes.statusCode == 200) {
                break;
              } else if (geminiRes.statusCode == 401) {
                print('  [AVISO] Token de acesso expirado (401). Renovando...');
                accessToken = await getGcloudAccessToken();
                print('  Token renovado com sucesso! Tentando novamente...');
                retries--;
              } else if (geminiRes.statusCode == 503 || geminiRes.statusCode == 429) {
                int waitSeconds = 15;
                try {
                  final errJson = jsonDecode(utf8.decode(geminiRes.bodyBytes));
                  final details = errJson['error']?['details'] as List?;
                  if (details != null) {
                    for (final detail in details) {
                      if (detail['@type'] == '[type.googleapis.com/google.rpc.RetryInfo](https://type.googleapis.com/google.rpc.RetryInfo)') {
                        final delayStr = detail['retryDelay'] as String?;
                        if (delayStr != null && delayStr.endsWith('s')) {
                          final parsedSec = int.tryParse(delayStr.substring(0, delayStr.length - 1));
                          if (parsedSec != null) {
                            waitSeconds = parsedSec + 2;
                          }
                        }
                      }
                    }
                  }
                } catch (_) {}

                print('  [AVISO] Vertex AI retornou status ${geminiRes.statusCode}. Aguardando $waitSeconds segundos antes de tentar novamente... (Tentativas restantes: ${retries - 1})');
                await Future.delayed(Duration(seconds: waitSeconds));
                retries--;
              } else {
                break;
              }
            } catch (e) {
              print('  [AVISO] Erro na requisição do Vertex AI: $e. Tentando novamente em 15 segundos...');
              await Future.delayed(const Duration(seconds: 15));
              retries--;
            }
          }

          if (geminiRes == null || geminiRes.statusCode != 200) {
            final errorMsg = geminiRes != null ? utf8.decode(geminiRes.bodyBytes) : 'Sem resposta';
            throw Exception('Erro persistente na chamada do Gemini via Vertex AI (Status ${geminiRes?.statusCode}): $errorMsg');
          }

          final responseText = utf8.decode(geminiRes.bodyBytes);
          if (responseText.isEmpty) {
            throw Exception('Resposta vazia da API do Gemini.');
          }

          final Map<String, dynamic> geminiJson = jsonDecode(responseText);
          final candidates = geminiJson['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            throw Exception('Nenhuma resposta de conteúdo do Gemini.');
          }

          final candidate = candidates.first as Map;
          final content = candidate['content'] as Map?;
          final parts = content?['parts'] as List?;
          if (parts == null || parts.isEmpty) {
            throw Exception('Parte vazia na resposta do Gemini.');
          }

          final String textOutput = parts.first['text'] as String;
          
          // Sanitização defensiva do JSON (Removendo formatação Markdown indesejada)
          String cleanText = textOutput.trim();
          if (cleanText.startsWith('```')) {
            final firstNewline = cleanText.indexOf('\n');
            if (firstNewline != -1) {
              cleanText = cleanText.substring(firstNewline + 1);
            }
            if (cleanText.endsWith('```')) {
              cleanText = cleanText.substring(0, cleanText.length - 3);
            }
            cleanText = cleanText.trim();
          }

          List questionsList;
          try {
            questionsList = jsonDecode(cleanText) as List;
            // Validar que cada objeto possui as chaves necessárias e tentar autocorrigir erros de LLM
            for (final q in questionsList) {
              if (q is! Map) {
                throw const FormatException('O item gerado não é um objeto/mapa JSON.');
              }
              if (!q.containsKey('pergunta') || q['pergunta'] == null) {
                throw const FormatException('Faltando chave "pergunta".');
              }
              if (!q.containsKey('alternativas') || q['alternativas'] is! List || (q['alternativas'] as List).length != 4) {
                throw const FormatException('Chave "alternativas" ausente ou inválida (deve conter 4 itens).');
              }
              
              // Se "resposta_correta" não está presente, tenta encontrar variações comuns (como "essel_correta")
              if (!q.containsKey('resposta_correta')) {
                String? foundCorrectKey;
                for (final k in q.keys) {
                  final kStr = k.toString().toLowerCase();
                  if (kStr.contains('correta') || kStr.contains('correct') || kStr.contains('resposta') || kStr.contains('essel')) {
                    foundCorrectKey = k.toString();
                    break;
                  }
                }
                if (foundCorrectKey != null) {
                  q['resposta_correta'] = q[foundCorrectKey];
                } else {
                  throw const FormatException('Faltando chave "resposta_correta".');
                }
              }
              
              if (q['resposta_correta'] == null) {
                throw const FormatException('Chave "resposta_correta" é nula.');
              }
              
              // Converter resposta_correta para int seguro
              final respRaw = q['resposta_correta'];
              int? respInt;
              if (respRaw is int) {
                respInt = respRaw;
              } else if (respRaw is String) {
                respInt = int.tryParse(respRaw);
              }
              if (respInt == null || respInt < 0 || respInt > 3) {
                throw FormatException('Valor de "resposta_correta" inválido: $respRaw');
              }
              q['resposta_correta'] = respInt;
              
              if (!q.containsKey('categoria') || q['categoria'] == null) {
                q['categoria'] = theme['categoria'];
              }
            }
          } catch (e) {
            throw FormatException('Erro na estrutura/decodificação do JSON gerado: $e. Texto gerado original: $cleanText');
          }

          print('Sucesso! Geradas ${questionsList.length} perguntas válidas pelo Gemini.');

          // 2. Injetando em paralelo no Firestore
          print('Gravando perguntas no Cloud Firestore...');
          final List<Future<void>> uploadFutures = [];

          for (final q in questionsList) {
            final docId = _generateDocumentId(q['pergunta']);
            final encodedDocId = Uri.encodeComponent(docId);
            final docUri = Uri.parse(
              '[https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/perguntas/$encodedDocId](https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/perguntas/$encodedDocId)',
            );

            final Map<String, dynamic> firestoreDoc = {
              'fields': {
                'pergunta': {'stringValue': q['pergunta']},
                'alternativas': {
                  'arrayValue': {
                    'values': (q['alternativas'] as List)
                        .map((alt) => {'stringValue': alt})
                        .toList(), // Corrigido: parêntese fechado corretamente aqui antes do .toList()
                  },
                },
                'resposta_correta': {
                  'integerValue': q['resposta_correta'].toString(),
                },
                'categoria': {'stringValue': q['categoria']},
                'embasamento': {'stringValue': q['embasamento'] ?? 'Embasamento histórico não disponível para esta questão.'},
              },
            };

            uploadFutures.add(() async {
              try {
                final patchReq = await client.patchUrl(docUri);
                patchReq.headers.set('Authorization', 'Bearer $accessToken');
                patchReq.headers.set('Content-Type', 'application/json; charset=utf-8');

                final bodyBytes = utf8.encode(jsonEncode(firestoreDoc));
                patchReq.headers.set('Content-Length', bodyBytes.length.toString());
                patchReq.add(bodyBytes);

                final patchRes = await patchReq.close();
                if (patchRes.statusCode == 200 || patchRes.statusCode == 201) {
                  print('  [OK] Gravado: "$docId"');
                } else {
                  final errText = await patchRes.transform(utf8.decoder).join();
                  print('  [ERRO] Falha ao gravar "$docId" (${patchRes.statusCode}): $errText');
                }
              } catch (e) {
                print('  [ERRO] Falha na requisição de "$docId": $e');
              }
            }());
          }

          await Future.wait(uploadFutures);
          totalGenerated += questionsList.length;
          print('Lote concluído. Total acumulado: $totalGenerated perguntas.');
          batchSuccess = true;
        } catch (e) {
          print('  [AVISO] Falha ao processar o Lote ${i + 1} (Tentativa $batchTry de $maxBatchTries): $e');
          batchTry++;
        }
      }

      if (!batchSuccess) {
        print('  [ERRO CRÍTICO] O Lote ${i + 1} ("${theme['subtema']}") falhou definitivamente após $maxBatchTries tentativas.');
        failedBatches.add(theme);
      }

      // Delay de 10 segundos entre os lotes para evitar Rate Limit
      if (i < subThemes.length - 1) {
        print('Aguardando 10 segundos antes do próximo lote...');
        await Future.delayed(const Duration(seconds: 10));
      }
    }

    print('\n================================================================');
    print('PROCESSO DE INGESTÃO CONCLUÍDO!');
    print('Total de perguntas gravadas/atualizadas no Firestore: $totalGenerated');
    if (failedBatches.isNotEmpty) {
      print('Atenção: Os seguintes ${failedBatches.length} subtemas falharam e não foram inseridos:');
      for (final f in failedBatches) {
        print(' - [${f['categoria']}] ${f['subtema']}');
      }
    } else {
      print('Todos os lotes foram inseridos com sucesso!');
    }
    print('================================================================');
  } catch (e) {
    print('Ocorreu um erro geral inesperado fora do loop principal: $e');
  } finally {
    client.close();
  }
}

/// Transforma uma string em um slug amigável para URLs.
String _slugify(String text) {
  var slug = text.toLowerCase();

  // Dicionário de remoção de acentos em português
  final accentMap = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  accentMap.forEach((key, value) {
    slug = slug.replaceAll(key, value);
  });

  // Remove caracteres especiais, mantendo apenas letras, números, espaços, hífens, sublinhados e pontos
  slug = slug.replaceAll(RegExp(r'[^a-z0-9\s_.-]'), '');

  // Substitui espaços múltiplos por hífens
  slug = slug.trim().replaceAll(RegExp(r'\s+'), '-');

  // Remove hífen residual no final, se houver
  if (slug.endsWith('-')) {
    slug = slug.substring(0, slug.length - 1);
  }

  return slug;
}

/// Gera um ID de documento amigável e limpo com base no texto da pergunta.
String _generateDocumentId(String question) {
  var slug = _slugify(question);

  // Limita o tamanho do ID para evitar URLs gigantescas
  if (slug.length > 80) {
    slug = slug.substring(0, 80);
  }

  // Se por algum motivo o ID ficar vazio, usa um fallback numérico hash
  if (slug.isEmpty) {
    slug = 'pergunta-${question.hashCode}';
  }

  return slug;
}