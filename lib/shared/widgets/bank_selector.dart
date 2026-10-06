import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/utils/json_read.dart';
import '../../core/icons/kredi_icons.dart';

class BankSelector extends StatefulWidget {
  const BankSelector({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final TextEditingController controller;
  final bool enabled;
  @override
  State<BankSelector> createState() => _BankSelectorState();
}

class _BankSelectorState extends State<BankSelector> {
  Future<List<Map<String, dynamic>>>? _future;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).api.banks();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _future = AppScope.of(context).api.banks()),
              icon: const Icon(KrediIcons.refresh),
              label: const Text('No se cargaron los bancos. Reintentar'),
            );
          }
          final rows = snapshot.data ?? const [];
          return DropdownButtonFormField<String>(
            initialValue:
                rows.any(
                  (row) => jString(row, ['code']) == widget.controller.text,
                )
                ? widget.controller.text
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: snapshot.connectionState == ConnectionState.done
                  ? 'Banco de origen'
                  : 'Cargando bancos…',
            ),
            items: [
              for (final row in rows)
                DropdownMenuItem(
                  value: jString(row, ['code']),
                  child: Text(
                    '${jString(row, ['code'])} · ${jString(row, ['name'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.enabled && rows.isNotEmpty
                ? (value) => widget.controller.text = value ?? ''
                : null,
          );
        },
      );
}
