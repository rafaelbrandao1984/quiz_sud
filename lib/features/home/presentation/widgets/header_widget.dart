import 'package:flutter/material.dart';

/// Cabeçalho Imersivo com Gradiente e Elementos Estéticos.
class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: 24,
        bottom: 48,
        left: size.width > 800 ? size.width * 0.15 : 20.0,
        right: size.width > 800 ? size.width * 0.15 : 20.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            const Color(0xFF1B3C5F), // Tom médio para dar profundidade
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo/Badge estético
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.5,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.explore,
                      color: theme.colorScheme.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Liahona Quiz',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              // Indicador/Avatar Fictício de Perfil
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars, color: Color(0xFFD4AF37), size: 16),
                    SizedBox(width: 4),
                    Text(
                      '350 PTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Saudação principal
          Text(
            'Descubra e Aprenda',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desafie seus conhecimentos sobre escrituras, pioneiros e a Restauração.',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
