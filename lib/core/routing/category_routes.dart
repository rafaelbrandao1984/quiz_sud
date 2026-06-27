/// Slugs ASCII para rotas — evita % encoding quebrado no go_router (web).
class CategoryRoutes {
  CategoryRoutes._();

  static const Map<String, String> slugToTitle = {
    'obras_padrao': 'Obras Padrão',
    'historia_igreja': 'História da Igreja',
    'historia_brasil': 'História da Igreja no Brasil',
    'desafio_geral': 'Desafio Geral',
  };

  static String slugForTitle(String title) {
    return switch (title) {
      'Obras Padrão' => 'obras_padrao',
      'História da Igreja' => 'historia_igreja',
      'História da Igreja no Brasil' => 'historia_brasil',
      'Desafio Geral' => 'desafio_geral',
      _ => 'desafio_geral',
    };
  }

  static String titleForSlug(String? slug) {
    if (slug == null || slug.isEmpty) return 'Desafio Geral';
    return slugToTitle[slug] ?? 'Desafio Geral';
  }

  static String soloPath(String title) => '/quiz/${slugForTitle(title)}';

  static String trilhaPath(String title) => '/trilha/${slugForTitle(title)}';

  /// Converte segmentos legados (encoded ou corrompidos) para slug.
  static String? resolveLegacySlug(String segment) {
    if (slugToTitle.containsKey(segment)) return segment;

    var decoded = segment;
    try {
      decoded = Uri.decodeComponent(segment);
    } catch (_) {
      // Fallback para quando o decode falha devido a caracteres não-ASCII misturados com % (ex: Obras%20Padrão)
      decoded = segment.replaceAll('%20', ' ');
    }

    if (slugToTitle.containsKey(decoded)) return decoded;

    final title = titleForSlug(slugForTitle(decoded));
    if (decoded == title) return slugForTitle(title);

    final lower = decoded.toLowerCase();
    if (lower.contains('obras') && lower.contains('padr')) return 'obras_padrao';
    if (lower.contains('brasil')) return 'historia_brasil';
    if (lower.contains('hist')) return 'historia_igreja';
    if (lower.contains('desafio') || lower.contains('geral')) {
      return 'desafio_geral';
    }
    return null;
  }
}

/// Extrai PIN de sala de URLs legadas sem depender de decodeComponent.
String? extractRoomIdFromLocation(String location) {
  final match = RegExp(r'roomId=(\d{6})').firstMatch(location);
  return match?.group(1);
}

String? redirectLegacyPath(String path) {
  for (final prefix in const ['/quiz/', '/trilha/']) {
    if (!path.startsWith(prefix)) continue;
    final segment = path.substring(prefix.length).split('/').first;
    if (segment.isEmpty) continue;
    if (CategoryRoutes.slugToTitle.containsKey(segment)) continue;
    final resolved = CategoryRoutes.resolveLegacySlug(segment);
    if (resolved != null) return '$prefix$resolved';
  }
  return null;
}
