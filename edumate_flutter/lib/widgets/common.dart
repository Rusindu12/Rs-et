import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EduCard extends StatelessWidget {
  const EduCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: const Color(0xff35356B).withValues(alpha: 0.055),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      );
}

class GradientPanel extends StatelessWidget {
  const GradientPanel({required this.child, super.key, this.colors});

  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors ?? const [Color(0xff7770FF), Color(0xff6258E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: EduColors.purple.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      );
}

class MascotBadge extends StatelessWidget {
  const MascotBadge({super.key, this.size = 58, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Icon(Icons.smart_toy_rounded, color: color, size: size * 0.56),
      );
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({required this.value, super.key, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 8,
          backgroundColor: (color ?? EduColors.purple).withValues(alpha: 0.13),
          valueColor: AlwaysStoppedAnimation<Color>(color ?? EduColors.purple),
        ),
      );
}
