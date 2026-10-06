import 'package:flutter/material.dart';
export 'kredi_actions.dart';
import '../../core/theme/kredi_theme.dart';
import 'kredi_brand.dart';
import '../../core/icons/kredi_icons.dart';

class KrediResponsive extends StatelessWidget {
  const KrediResponsive({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KrediMetrics.contentMaxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}

class KrediSectionHeader extends StatelessWidget {
  const KrediSectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: KrediColors.black,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: KrediColors.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 10), trailing!],
    ],
  );
}

class KrediSoftCard extends StatelessWidget {
  const KrediSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = Colors.white,
    this.borderColor = KrediColors.border,
    this.radius = KrediMetrics.cardRadius,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class KrediIconTile extends StatelessWidget {
  const KrediIconTile({
    super.key,
    required this.icon,
    this.accent = KrediColors.orange,
    this.size = 42,
    this.iconSize = 22,
  });
  final IconData icon;
  final Color accent;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: Icon(icon, color: accent, size: iconSize),
    ),
  );
}

class KrediListAction extends StatelessWidget {
  const KrediListAction({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accent = KrediColors.orange,
    this.badge,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final String? badge;

  @override
  Widget build(BuildContext context) => KrediSoftCard(
    padding: EdgeInsets.zero,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          KrediIconTile(icon: icon, accent: accent, size: 40, iconSize: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: KrediColors.black,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: KrediColors.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 92),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    badge!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          const Icon(
            KrediIcons.chevron,
            color: KrediColors.navySoft,
            size: 21,
          ),
        ],
      ),
    ),
  );
}

class KrediMetricCard extends StatelessWidget {
  const KrediMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = KrediColors.orange,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => KrediSoftCard(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KrediIconTile(icon: icon, accent: accent, size: 36, iconSize: 18),
        const Spacer(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: KrediColors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: KrediColors.secondary,
          ),
        ),
      ],
    ),
  );
}

class KrediActionCard extends StatelessWidget {
  const KrediActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.accent = KrediColors.orange,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => KrediSoftCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Row(
      children: [
        KrediIconTile(icon: icon, accent: accent, size: 40, iconSize: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: KrediColors.black,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: KrediColors.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class KrediAuthBackground extends StatelessWidget {
  const KrediAuthBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFFFCFCFD))),
      Positioned(
        left: -95,
        bottom: -105,
        child: Container(
          width: 330,
          height: 330,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: KrediColors.orange.withValues(alpha: .075),
          ),
        ),
      ),
      Positioned(
        right: -70,
        top: 80,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF102B4E).withValues(alpha: .025),
          ),
        ),
      ),
      Positioned.fill(child: child),
    ],
  );
}

class KrediLoginBrand extends StatelessWidget {
  const KrediLoginBrand({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      KrediBrand(height: 50),
      SizedBox(height: 8),
      Text(
        'Compra, cumple y sigue subiendo.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: KrediColors.navySoft,
        ),
      ),
    ],
  );
}

class KrediAuthField extends StatelessWidget {
  const KrediAuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(KrediMetrics.authFieldRadius),
      border: Border.all(color: KrediColors.fieldBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      maxLines: 1,
      cursorColor: KrediColors.orange,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: KrediColors.orange, size: 23),
        suffixIcon: trailing,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
      ),
    ),
  );
}
