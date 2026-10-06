import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
export 'kredi_actions.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';

class KrediPressable extends StatefulWidget {
  const KrediPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.pressedScale = .985,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;
  final double pressedScale;
  final bool haptic;

  @override
  State<KrediPressable> createState() => _KrediPressableState();
}

class _KrediPressableState extends State<KrediPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTap: widget.enabled
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: _pressed ? KrediMotion.press : KrediMotion.standard,
        curve: KrediMotion.enter,
        child: widget.child,
      ),
    );
  }
}

class KrediPage extends StatelessWidget {
  const KrediPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 28),
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? KrediColors.background,
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class KrediScreenTitle extends StatelessWidget {
  const KrediScreenTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: const TextStyle(
            fontSize: 20,
            height: 1.12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: KrediColors.black,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: KrediColors.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (trailing == null) return heading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 12),
            Flexible(child: trailing!),
          ],
        );
      },
    );
  }
}

class KrediSectionRow extends StatelessWidget {
  const KrediSectionRow({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
      style: const TextStyle(
        fontSize: 19,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: KrediColors.black,
      ),
    );
    if (action == null) return titleWidget;

    final actionWidget = InkWell(
      onTap: onAction,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Text(
          action!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: onAction == null
                ? TextDecoration.none
                : TextDecoration.underline,
            decorationThickness: 1.2,
            color: onAction == null ? KrediColors.secondary : KrediColors.orangeDeep,
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleWidget,
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerRight, child: actionWidget),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleWidget),
            const SizedBox(width: 10),
            Flexible(child: actionWidget),
          ],
        );
      },
    );
  }
}

class KrediPill extends StatelessWidget {
  const KrediPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.leading,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? leading;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KrediColors.softOrange : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? KrediColors.orange : KrediColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null)
                leading!
              else
                Icon(
                  icon,
                  size: 21,
                  color: selected ? KrediColors.orangeDeep : KrediColors.black,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? KrediColors.orangeDeep : KrediColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KrediSearchField extends StatelessWidget {
  const KrediSearchField({
    super.key,
    this.controller,
    this.hint = 'Buscar',
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onTap: onTap,
      onSubmitted: onSubmitted,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(KrediIcons.search, size: 25),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: KrediColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: KrediColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(26),
          borderSide: const BorderSide(color: KrediColors.orange, width: 1.6),
        ),
      ),
    );
  }
}

class KrediOutlineCard extends StatelessWidget {
  const KrediOutlineCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.radius = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: KrediColors.border),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return KrediPressable(
      onTap: onTap!,
      child: content,
    );
  }
}

class KrediMenuRow extends StatelessWidget {
  const KrediMenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor = KrediColors.black,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: title,
      child: KrediPressable(
        onTap: onTap ?? () {},
        enabled: onTap != null,
        pressedScale: .992,
        child: ListTile(
          minLeadingWidth: 44,
          minVerticalPadding: 10,
          contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          leading: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: Icon(
                icon,
                color: iconColor == KrediColors.black ? KrediColors.coral : iconColor,
                size: 23,
              ),
            ),
          ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: KrediColors.black,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: KrediColors.secondary,
                      height: 1.35,
                    ),
                  ),
                ),
          trailing: trailing ??
              const SizedBox(
                width: 30,
                child: Center(
                  child: Icon(KrediIcons.chevron, color: KrediColors.orangeDeep),
                ),
              ),
          onTap: null,
        ),
      ),
    );
  }
}

class KrediQuickAction extends StatelessWidget {
  const KrediQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: KrediOutlineCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      radius: 18,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(icon, size: 24, color: KrediColors.coral),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class KrediCreditRing extends StatelessWidget {
  const KrediCreditRing({
    super.key,
    required this.amount,
    required this.caption,
    this.progress = 1,
    this.size = 280,
  });

  final String amount;
  final String caption;
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safe = progress.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 56,
              color: KrediColors.border,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: safe,
              strokeWidth: 56,
              strokeCap: StrokeCap.round,
              color: KrediColors.orange,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(62),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: size - 128),
                  child: Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: size - 126),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 23,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KrediEmptyState extends StatelessWidget {
  const KrediEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: const BoxDecoration(
                color: KrediColors.softOrange,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 62, color: KrediColors.coral),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: KrediColors.secondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: KrediColors.orangeDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class KrediCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const KrediCompactAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.centerTitle = true,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      centerTitle: centerTitle,
      leading: onBack == null
          ? null
          : IconButton(
              onPressed: onBack,
              icon: const Icon(KrediIcons.back, size: 27),
              tooltip: 'Volver',
            ),
      title: Text(title),
      actions: [?trailing, const SizedBox(width: 10)],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }
}
