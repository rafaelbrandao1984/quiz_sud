import 'package:flutter/material.dart';

/// Botão de alternativa estilizado de forma dinâmica.
class AlternativeButton extends StatefulWidget {
  final String alternativeText;
  final int index;
  final bool isSelected;
  final bool isAnswered;
  final bool isEnabled;
  final int correctIndex;
  final VoidCallback onTap;

  const AlternativeButton({
    super.key,
    required this.alternativeText,
    required this.index,
    required this.isSelected,
    required this.isAnswered,
    this.isEnabled = true,
    required this.correctIndex,
    required this.onTap,
  });

  @override
  State<AlternativeButton> createState() => _AlternativeButtonState();
}

class _AlternativeButtonState extends State<AlternativeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = String.fromCharCode(65 + widget.index); // A, B, C, D

    // Estilos padrão do botão
    Color backgroundColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    Color textColor = theme.colorScheme.primary;
    Color prefixBgColor = theme.colorScheme.primary.withValues(alpha: 0.08);
    Color prefixTextColor = theme.colorScheme.primary;

    // Alteração dinâmica se a pergunta já foi respondida
    if (widget.isAnswered) {
      if (widget.index == widget.correctIndex) {
        // Correta destaca-se em verde
        backgroundColor = const Color(0xFFE8F5E9);
        borderColor = Colors.green.shade600;
        textColor = Colors.green.shade800;
        prefixBgColor = Colors.green.shade600;
        prefixTextColor = Colors.white;
      } else if (widget.isSelected) {
        // Selecionada incorretamente destaca-se em vermelho
        backgroundColor = const Color(0xFFFFEBEE);
        borderColor = Colors.red.shade600;
        textColor = Colors.red.shade800;
        prefixBgColor = Colors.red.shade600;
        prefixTextColor = Colors.white;
      } else {
        // Outras ficam desbotadas
        backgroundColor = Colors.white.withValues(alpha: 0.6);
        borderColor = Colors.grey.shade200;
        textColor = Colors.black38;
        prefixBgColor = Colors.grey.shade100;
        prefixTextColor = Colors.black38;
      }
    } else if (!widget.isEnabled) {
      backgroundColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade200;
      textColor = Colors.black38;
      prefixBgColor = Colors.grey.shade100;
      prefixTextColor = Colors.black38;
    } else if (_isHovered) {
      // Hover ativo pré-seleção
      borderColor = theme.colorScheme.secondary;
      backgroundColor = theme.colorScheme.secondary.withValues(alpha: 0.05);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && !widget.isAnswered && widget.isEnabled ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: InkWell(
          onTap: widget.isAnswered || !widget.isEnabled ? null : widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isHovered && !widget.isAnswered && widget.isEnabled
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.15,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Círculo com a letra A, B, C, D
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: prefixBgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    prefix,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: prefixTextColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Texto da alternativa
                Expanded(
                  child: Text(
                    widget.alternativeText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                // Ícones de confirmação no fim do botão
                if (widget.isAnswered)
                  if (widget.index == widget.correctIndex)
                    const Icon(Icons.check_circle_rounded, color: Colors.green)
                  else if (widget.isSelected)
                    const Icon(Icons.cancel_rounded, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
