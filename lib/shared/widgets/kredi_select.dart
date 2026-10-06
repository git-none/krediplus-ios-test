import 'package:flutter/material.dart';
import '../../core/theme/kredi_theme.dart';
import '../../core/icons/kredi_icons.dart';

class KrediSelectOption<T> {
  const KrediSelectOption(this.value, this.label, {this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

class KrediSelectField<T> extends StatelessWidget {
  const KrediSelectField({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.onChanged,
    this.value,
    this.enabled = true,
    this.loading = false,
    this.hint = 'Seleccionar',
    this.searchHint = 'Buscar',
    this.emptyMessage = 'No hay opciones disponibles.',
  });

  final String label;
  final IconData icon;
  final List<KrediSelectOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool loading;
  final String hint;
  final String searchHint;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    KrediSelectOption<T>? selected;
    for (final option in options) {
      if (option.value == value) {
        selected = option;
        break;
      }
    }

    final display = selected?.label ?? hint;
    final foreground = enabled ? KrediColors.black : const Color(0xFF9A9EA6);
    final secondary = enabled ? KrediColors.secondary : const Color(0xFFA8ABB1);

    return Semantics(
      button: enabled && !loading,
      label: '$label. $display',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !loading ? () => _open(context) : null,
          borderRadius: BorderRadius.circular(KrediMetrics.fieldRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(KrediMetrics.fieldRadius),
              border: Border.all(
                color: enabled ? KrediColors.border : const Color(0xFFECEEF1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(icon, size: 22, color: foreground),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: selected == null
                              ? FontWeight.w600
                              : FontWeight.w600,
                          color: selected == null ? secondary : foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(KrediIcons.expand, size: 21, color: secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .28),
      builder: (sheetContext) => _SelectSheet<T>(
        title: label,
        options: options,
        selected: value,
        searchHint: searchHint,
        emptyMessage: emptyMessage,
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchHint,
    required this.emptyMessage,
  });

  final String title;
  final List<KrediSelectOption<T>> options;
  final T? selected;
  final String searchHint;
  final String emptyMessage;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  final query = TextEditingController();
  final focusNode = FocusNode();

  @override
  void dispose() {
    query.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = query.text.trim().toLowerCase();
    final filtered = widget.options.where((option) {
      return needle.isEmpty ||
          option.label.toLowerCase().contains(needle) ||
          (option.subtitle?.toLowerCase().contains(needle) ?? false);
    }).toList();

    final viewInsets = MediaQuery.viewInsetsOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: .82,
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: KrediColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(KrediIcons.close),
                    ),
                  ],
                ),
              ),
              if (widget.options.length > 7)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: TextField(
                    controller: query,
                    focusNode: focusNode,
                    onChanged: (_) => setState(() {}),
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(KrediIcons.search),
                      suffixIcon: query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                query.clear();
                                setState(() {});
                              },
                              icon: const Icon(KrediIcons.close, size: 19),
                            ),
                    ),
                  ),
                ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            widget.emptyMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: KrediColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final option = filtered[index];
                          final selected = option.value == widget.selected;
                          return ListTile(
                            minVerticalPadding: 12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            title: Text(
                              option.label,
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w600,
                              ),
                            ),
                            subtitle: option.subtitle == null
                                ? null
                                : Text(option.subtitle!),
                            trailing: selected
                                ? const Icon(
                                    KrediIcons.success,
                                    color: KrediColors.orange,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, option.value),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
