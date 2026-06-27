import 'package:go_router/go_router.dart';

/// Rota do quiz multijogador — categoria vem do Firestore, não da URL.
String multiplayerQuizLocation(String roomId) {
  return '/sala/$roomId';
}

/// Link de convite para entrar na sala (Arena ou Duelo).
String multiplayerJoinPath(String roomId, {required bool isDuel}) {
  return isDuel ? '/duelo/$roomId' : '/join/$roomId';
}

String multiplayerJoinUrl(String roomId, {required bool isDuel}) {
  return Uri.base.replace(path: multiplayerJoinPath(roomId, isDuel: isDuel)).toString();
}

void goToMultiplayerRoom(
  GoRouter router,
  String roomId, {
  String? categoryTitle,
}) {
  router.go(multiplayerQuizLocation(roomId));
}
