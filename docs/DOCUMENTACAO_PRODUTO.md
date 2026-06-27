# Liahona Quiz — Documentação do Produto

> **Atualização Jun/2026:** Modos atuais: Solo, Trilha adaptativa, Arena Relâmpago (multijogador padrão), Duelo 1v1, Campeonato por turnos (legado). Auth: Firebase Anonymous. Cloud Functions para Relâmpago/Duelo. Estatísticas locais. Analytics GA4.

## 1. Visão geral

O **Liahona Quiz** é um aplicativo educacional interativo desenvolvido em **Flutter**, voltado ao estudo de temas relacionados à Igreja de Jesus Cristo dos Santos dos Últimos Dias. O produto combina quiz individual, modo estudo com embasamento histórico e **campeonatos multijogador em tempo real**, sincronizados via **Firebase Firestore**.

O público-alvo inclui membros, famílias e grupos de estudo que desejam testar e aprofundar conhecimentos sobre escrituras, história da Igreja e contexto brasileiro — de forma solo ou competitiva entre amigos.

---

## 2. Proposta de valor

| Necessidade | Como o app atende |
|-------------|-------------------|
| Estudar por tema | Categorias temáticas com perguntas do Firestore |
| Aprender com erros | Modo Estudo: gabarito + embasamento antes de avançar |
| Variar o conteúdo | Sorteio aleatório por partida, sem esgotar o banco |
| Jogar em grupo | Salas com PIN, até 10 jogadores, sincronização ao vivo |
| Competição justa | Mesmas perguntas para todos; turnos rotativos por jogador |

---

## 3. Modos de jogo

### 3.1 Modo Solo — Categorias temáticas

O usuário escolhe uma categoria na Home e inicia uma partida individual.

**Categorias disponíveis:**

- **Obras Padrão** — Bíblia, Livro de Mórmon, Doutrina e Convênios e Pérola de Grande Valor
- **História da Igreja** — Restauração, pioneiros e jornada para o oeste
- **História da Igreja no Brasil** — Missionários, pioneiros e templos nacionais
- **Desafio Geral** — Mix aleatório de todas as categorias

**Regras da partida solo:**

- **15 perguntas** sorteadas aleatoriamente por sessão
- **60 segundos** por pergunta
- Após responder (ou estourar o tempo), o gabarito e o **embasamento** são exibidos
- O usuário avança manualmente com **"Próxima Pergunta"**
- Ao final, tela de resultados com desempenho e opção de jogar novamente

### 3.2 Modo Estudo (integrado ao solo e visível no multijogador)

Não é um menu separado: é a **mecânica de pausa pedagógica** após cada resposta.

- Cronômetro para ao responder ou no timeout
- Alternativas reveladas (verde = correta, vermelho = erro)
- Card **"Entenda o Gabarito"** com texto de `embasamento` vindo do Firestore
- Avanço só quando o jogador (ou o jogador da rodada, no campeonato) decidir prosseguir

### 3.3 Modo Campeonato (Multijogador)

Salas virtuais com PIN de 6 dígitos, sincronizadas em tempo real.

**Fluxo resumido:**

1. Host cria sala e configura categoria, perguntas e tempo
2. Host informa nome e recebe o PIN
3. Outros jogadores entram com PIN + nome
4. Todos aguardam no **lobby** até o host iniciar
5. Host sorteia o baralho da partida (uma vez) e grava no Firestore
6. Jogo em formato **campeonato por turnos**

**Formato campeonato:**

- Em cada rodada, **um único jogador** responde
- Todos veem a **mesma pergunta**
- Apenas o jogador da vez pode clicar nas alternativas
- Após responder, todos veem gabarito e embasamento
- O jogador da vez clica em **"Passar para Próxima Rodada"**
- A liderança da rodada **rotaciona** entre os jogadores
- Ranking ao vivo e cronômetro global da partida

---

## 4. Configuração de salas (campeonato)

Ao criar uma sala, o host define:

| Parâmetro | Opções | Máximo |
|-----------|--------|--------|
| Categoria | 4 temas (incl. Desafio Geral) | — |
| Perguntas | 10, 20, 30, 40, 50 | **50** |
| Tempo total | 15, 30, 45, 60 minutos | **60 min** |
| Jogadores | — | **10** |

**Exemplo de rodadas:** com sala cheia (10 jogadores) e 50 perguntas, cada jogador participa de **5 rodadas** (50 ÷ 10 = 5).

O lobby exibe PIN, jogadores conectados (`2/10`), categoria, quantidade de perguntas, tempo e rodadas estimadas por jogador.

---

## 5. Seleção de perguntas (aleatoriedade)

As perguntas **não** seguem a ordem do banco de dados. O sistema usa **sorteio com limite por partida**:

1. Busca um pool no Firestore (categoria filtrada ou até 100 docs no Desafio Geral)
2. Embaralha com `shuffle()`
3. Seleciona apenas `N` perguntas (`take(limit)`)

**Modo solo:** novo sorteio a cada partida (até 15 perguntas).

**Multijogador:** o host sorteia **uma vez** ao iniciar; os IDs são salvos em `questionIds` na sala. Todos os jogadores carregam a **mesma lista na mesma ordem** via `fetchQuestionsByIds()`.

Isso evita repetir sempre as mesmas perguntas na mesma ordem e **não consome** todo o banco em uma única partida.

---

## 6. Experiência do usuário (telas principais)

### Home

- Cabeçalho com identidade **Liahona Quiz**
- Card **Modo Multijogador**: Criar Sala / Entrar em Sala
- Banner **Reentrar** quando há sala ativa na sessão
- Grade de categorias para modo solo
- Layout responsivo (grade no desktop/tablet, lista no mobile)

### Lobby (sala em espera)

- Lista de jogadores em tempo real
- Configurações da partida
- Host: botão **Iniciar Campeonato**
- Demais jogadores: aguardam sincronização automática quando o jogo começa

### Tela de jogo

- Barra de progresso
- Cronômetro da pergunta (60 s) e, no multijogador, **tempo restante da partida**
- Ranking ao vivo (multijogador)
- Indicador de quem é o jogador da rodada
- Card da pergunta e quatro alternativas
- Painel de embasamento após a resposta

### Resultados

- Mensagem por desempenho
- Estatísticas (categoria, acertos)
- No multijogador: **ranking final** de todos os jogadores
- Voltar ao início ou jogar novamente (solo)

---

## 7. Arquitetura técnica

```
lib/
├── main.dart                    # Entrada, Firebase, Riverpod
├── core/
│   ├── routing/app_router.dart  # GoRouter (/ e /quiz/:category)
│   └── theme/app_theme.dart     # Tema azul + dourado
└── features/
    ├── home/presentation/       # HomeScreen, categorias, salas
    └── quiz/
        ├── domain/              # QuizRoom, RoomSettings
        ├── data/                # Repositórios Firestore
        └── presentation/        # QuizScreen, diálogos
```

### Stack tecnológica

| Camada | Tecnologia |
|--------|------------|
| UI | Flutter (Material 3) |
| Estado | flutter_riverpod |
| Navegação | go_router |
| Backend | Firebase Firestore |
| Plataformas | Web, desktop (Linux/Windows), mobile |

### Padrão de código

- **Feature-first**: home e quiz em módulos separados
- **Repository pattern**: `QuizRepository`, `MultiplayerRepository`
- **Domain models**: `QuizQuestion`, `QuizRoom`, `QuizPlayer`, `RoomSettings`
- **Providers Riverpod**: repositórios, sala atual (`currentRoomProvider`), sessão do jogador

---

## 8. Modelo de dados (Firestore)

### Coleção `perguntas`

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `pergunta` | string | Enunciado |
| `alternativas` | array | 4 opções |
| `resposta_correta` | int | Índice 0–3 |
| `embasamento` | string | Explicação pedagógica |
| `categoria` | string | `obras_padrao`, `historia_igreja`, `historia_brasil` |

### Coleção `salas`

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `roomId` | string | PIN de 6 dígitos |
| `hostId` | string | ID do criador |
| `players` | array | `{ id, name, score }` |
| `status` | string | `waiting`, `playing`, `finished` |
| `categoryTitle` | string | Categoria configurada |
| `questionCount` | int | Total de perguntas da partida |
| `questionIds` | array | IDs sorteados (sincronização) |
| `maxTimeSeconds` | int | Duração máxima da partida |
| `startTime` | timestamp | Início do campeonato |
| `currentQuestionIndex` | int | Pergunta atual |
| `currentPlayerTurnIndex` | int | Índice do jogador da rodada |
| `allAnswersCollected` | bool | Rodada concluída |
| `currentTurnAnswerIndex` | int | Resposta sincronizada (-1 = timeout) |
| `answeredPlayerIds` | array | Controle interno de respostas |
| `createdAt` | timestamp | Criação da sala |

---

## 9. Fluxos principais

### Criar sala (host)

```
Home → Configurar Campeonato → Informar nome → Firestore cria sala
     → Navega para lobby → Compartilha PIN → Iniciar Campeonato
```

### Entrar na sala (convidado)

```
Home → Entrar em Sala → PIN + nome → joinRoom() → Lobby
     → Aguarda host → Jogo sincronizado automaticamente
```

### Rodada do campeonato

```
Jogador da vez responde → Gabarito visível para todos
                       → Jogador da vez: "Passar para Próxima Rodada"
                       → advanceTurn(): próxima pergunta + próximo jogador
```

### Partida solo

```
Categoria → Carrega 15 perguntas sorteadas → Responde / timeout
          → Embasamento → Próxima Pergunta → Resultados
```

---

## 10. Sincronização em tempo real

O multijogador usa **streams** do Firestore (`streamRoom` / `currentRoomProvider`):

- Entrada e saída de jogadores no lobby
- Início da partida (`status: playing`)
- Índice da pergunta atual
- Turno do jogador
- Pontuação
- Resposta da rodada (`currentTurnAnswerIndex`)
- Encerramento (`status: finished`)

Todos os clientes reagem às mudanças sem polling manual.

---

## 11. Regras de negócio importantes

1. **Sala cheia:** máximo de 10 jogadores; `joinRoom` rejeita novos entrantes
2. **Uma resposta por rodada:** só o jogador em `currentPlayerTurnIndex` interage
3. **Mesmas perguntas:** `questionIds` definidos no `startGame` pelo host
4. **Tempo global:** partida encerra quando `startTime + maxTimeSeconds` esgota
5. **Tempo por pergunta:** 60 segundos; timeout só afeta o jogador da vez
6. **Pontuação:** +1 acerto por resposta correta, sincronizada no array `players`

---

## 12. Identidade visual

- **Primária:** azul escuro `#0F2942` (tom institucional sóbrio)
- **Secundária:** dourado `#D4AF37`
- **Superfície:** fundo azul-acinzentado claro
- Cards com bordas arredondadas, barras de progresso e cronômetros circulares
- Categorias com cores distintas (dourado, azul aço, verde, roxo no Desafio Geral)

---

## 13. Scripts e manutenção do banco

Na pasta `scripts/` existem utilitários para popular o Firestore (`populate_quiz.dart`), incluindo geração de perguntas com embasamento via IA. O banco pode crescer sem alterar a lógica do app — cada partida consome apenas um subconjunto sorteado.

---

## 14. Limitações conhecidas e evoluções possíveis

**Hoje:**

- Modo multijogador “Entrar em Sala” / “Criar Sala” na UI de amigos ainda é placeholder em parte do card superior (fluxo principal já funcional via botões do card)
- Não há histórico persistente de “perguntas já vistas” por usuário (sorteio puro por partida)
- Autenticação Firebase Auth não integrada (IDs de jogador gerados por sessão)

**Evoluções sugeridas:**

- Login com conta para ranking global
- Histórico de partidas e estatísticas por categoria
- Salas privadas com senha além do PIN
- Modo espectador
- Notificações quando o host inicia o campeonato

---

## 15. Como executar o projeto

```bash
# Dependências
flutter pub get

# Executar (web, desktop ou mobile)
flutter run

# Análise estática
dart analyze lib/
```

Requisitos: Flutter SDK ^3.12.2, projeto Firebase configurado (`firebase_options.dart`, Firestore com coleções `perguntas` e `salas`).

---

## 16. Glossário

| Termo | Significado |
|-------|-------------|
| **Embasamento** | Texto explicativo após a resposta |
| **Rodada** | Uma pergunta respondida por um jogador no campeonato |
| **PIN / roomId** | Código de 6 dígitos da sala |
| **Host** | Jogador que criou a sala e inicia o campeonato |
| **Turno** | Momento em que um jogador específico pode responder |
| **Desafio Geral** | Categoria mista com perguntas de todos os temas |

---

*Documento gerado para o produto Liahona Quiz — versão 1.0.0*
