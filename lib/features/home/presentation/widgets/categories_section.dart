import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/category_routes.dart';
import '../../../quiz/data/learning_profile_repository.dart';

/// Seção Responsiva de Categorias.
/// Adapta a exibição em grade de 3 colunas para telas grandes ou lista vertical para celulares.
class CategoriesSection extends StatelessWidget {
  const CategoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Definição estática das categorias de estudo + Desafio Geral
    final categories = [
      CategoryItem(
        title: 'Obras Padrão',
        subtitle:
            'Bíblia, Livro de Mórmon, Doutrina e Convênios e Pérola de Grande Valor.',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFD4AF37), // Dourado
        totalQuestions: 4,
        progress: 0.75,
      ),
      CategoryItem(
        title: 'História da Igreja',
        subtitle:
            'Dos eventos da Restauração em Nova York à jornada pioneira rumo ao oeste.',
        icon: Icons.explore_rounded,
        color: const Color(0xFF2E6B9E), // Azul Aço Suave
        totalQuestions: 4,
        progress: 0.50,
      ),
      CategoryItem(
        title: 'História da Igreja no Brasil',
        subtitle:
            'A chegada dos primeiros missionários em Santa Catarina, pioneiros e os templos nacionais.',
        icon: Icons.public_rounded,
        color: const Color(0xFF1B6A47), // Verde Nobre
        totalQuestions: 4,
        progress: 0.25,
      ),
      CategoryItem(
        title: 'Desafio Geral',
        subtitle:
            'Um mix imprevisível de Obras Padrão, História da Igreja e História no Brasil.',
        icon: Icons.shuffle_rounded,
        color: const Color(0xFF5E35B1), // Roxo profundo
        totalQuestions: 15,
        progress: 0.0,
      ),
    ];

    // Se o layout for largo (Desktop / Tablet paisagem), usa GridView
    if (size.width > 680) {
      final crossAxisCount = size.width > 1000 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 4 ? 1.45 : 1.55,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return InteractiveCategoryCard(category: categories[index]);
        },
      );
    }

    // Se for tela compacta (Móvel), renderiza como grade compacta de 2 colunas
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.32,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return InteractiveCategoryCard(
          category: categories[index],
          isCompact: true,
        );
      },
    );
  }
}

/// Modelo de Dados para representar as Categorias
class CategoryItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int totalQuestions;
  final double progress;

  CategoryItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.totalQuestions,
    required this.progress,
  });
}

/// Card de Categoria Interativo.
/// Abre a trilha adaptativa; toque longo abre o quiz clássico.
class InteractiveCategoryCard extends ConsumerStatefulWidget {
  final CategoryItem category;
  final bool isCompact;

  const InteractiveCategoryCard({
    super.key,
    required this.category,
    this.isCompact = false,
  });

  @override
  ConsumerState<InteractiveCategoryCard> createState() =>
      _InteractiveCategoryCardState();
}

class _InteractiveCategoryCardState extends ConsumerState<InteractiveCategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(learningProfileRepositoryProvider);

    final levelLabel = profileAsync.maybeWhen(
      data: (repo) {
        final profile = repo.getProfile(widget.category.title);
        return profile.diagnosticCompleted ? profile.levelLabel : null;
      },
      orElse: () => null,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: InkWell(
          onTap: () => context.go(CategoryRoutes.trilhaPath(widget.category.title)),
          onLongPress: () => context.go(CategoryRoutes.soloPath(widget.category.title)),
          borderRadius: BorderRadius.circular(widget.isCompact ? 16 : 20),
          child: Card(
            elevation: _isHovered ? 6 : 2,
            shadowColor: widget.category.color.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.isCompact ? 16 : 20),
              side: BorderSide(
                color: _isHovered ? widget.category.color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.isCompact ? 12.0 : 16.0),
              child: widget.isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.category.color.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                widget.category.icon,
                                color: widget.category.color,
                                size: 20,
                              ),
                            ),
                            if (levelLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  levelLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.category.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ícone + Badge Superior
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.category.color.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    widget.category.icon,
                                    color: widget.category.color,
                                    size: 22,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: levelLabel != null
                                        ? theme.colorScheme.secondary
                                            .withValues(alpha: 0.15)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    levelLabel ?? 'Trilha',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Título da Categoria
                            Text(
                              widget.category.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Descrição
                            Text(
                              widget.category.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          levelLabel != null
                              ? 'Trilha adaptativa • toque longo para clássico'
                              : 'Diagnóstico de 5 perguntas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary.withValues(alpha: 0.55),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
