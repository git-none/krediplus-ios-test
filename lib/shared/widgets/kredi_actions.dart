import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/kredi_theme.dart';

/// Botones de acción Kredi+ para beneficiarios.
///
/// Regla de UX: una acción importante siempre combina un icono reconocible
/// con una etiqueta corta. Los botones mantienen un objetivo táctil amplio y
/// estados de carga/deshabilitado previsibles en toda la aplicación.
enum KrediActionTone { primary, dark, secondary, soft, danger, text }

class KrediActionButton extends StatelessWidget {
  const KrediActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = KrediActionTone.primary,
    this.busy = false,
    this.expanded = false,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final KrediActionTone tone;
  final bool busy;
  final bool expanded;
  final String? semanticLabel;

  VoidCallback? get _effectiveCallback {
    if (busy || onPressed == null) return null;
    return () {
      HapticFeedback.selectionClick();
      onPressed!.call();
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tone == KrediActionTone.danger
                  ? Colors.white
                  : KrediColors.black,
            ),
          )
        else
          Icon(icon, size: 20),
        const SizedBox(width: 9),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );

    final button = switch (tone) {
      KrediActionTone.primary => FilledButton(
          onPressed: _effectiveCallback,
          child: content,
        ),
      KrediActionTone.dark => FilledButton(
          onPressed: _effectiveCallback,
          style: FilledButton.styleFrom(
            backgroundColor: KrediColors.orangeDeep,
            foregroundColor: KrediColors.black,
          ),
          child: content,
        ),
      KrediActionTone.secondary => OutlinedButton(
          onPressed: _effectiveCallback,
          child: content,
        ),
      KrediActionTone.soft => FilledButton(
          onPressed: _effectiveCallback,
          style: FilledButton.styleFrom(
            backgroundColor: KrediColors.softOrange,
            foregroundColor: KrediColors.black,
          ),
          child: content,
        ),
      KrediActionTone.danger => FilledButton(
          onPressed: _effectiveCallback,
          style: FilledButton.styleFrom(
            backgroundColor: KrediColors.danger,
            foregroundColor: Colors.white,
          ),
          child: content,
        ),
      KrediActionTone.text => TextButton(
          onPressed: _effectiveCallback,
          child: content,
        ),
    };

    final wrapped = Semantics(
      button: true,
      enabled: _effectiveCallback != null,
      label: semanticLabel ?? label,
      child: button,
    );

    return expanded
        ? SizedBox(width: double.infinity, child: wrapped)
        : wrapped;
  }
}

/// Botón solo-icono para acciones compactas (volver, actualizar, copiar...).
/// Siempre exige tooltip para que el significado no dependa solo del dibujo.
class KrediIconButton extends StatelessWidget {
  const KrediIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = KrediActionTone.text,
    this.size = KrediMetrics.touchTarget,
    this.iconSize = 22,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final KrediActionTone tone;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = _iconColors(tone, enabled);
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: colors.$1,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onPressed!.call();
                  }
                : null,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: iconSize, color: colors.$2),
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _iconColors(KrediActionTone tone, bool enabled) {
    if (!enabled) {
      return (Colors.transparent, const Color(0xFF9A9DA2));
    }
    return switch (tone) {
      KrediActionTone.primary => (KrediColors.coral, Colors.white),
      KrediActionTone.dark => (KrediColors.orangeDeep, KrediColors.black),
      KrediActionTone.secondary => (Colors.white, KrediColors.orangeDeep),
      KrediActionTone.soft => (KrediColors.softOrange, KrediColors.black),
      KrediActionTone.danger => (KrediColors.softError, KrediColors.danger),
      KrediActionTone.text => (Colors.transparent, KrediColors.orangeDeep),
    };
  }
}
