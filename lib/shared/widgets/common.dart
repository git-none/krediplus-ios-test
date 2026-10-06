import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/kredi_theme.dart';
import 'kredi_ui.dart';
import '../../core/icons/kredi_icons.dart';

class KrediSectionTitle extends StatelessWidget {
  const KrediSectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) =>
      KrediSectionHeader(title, subtitle: subtitle);
}

class KrediEmpty extends StatelessWidget {
  const KrediEmpty(
    this.title,
    this.message, {
    super.key,
    this.icon = KrediIcons.inbox,
  });
  final String title;
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => KrediSoftCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          KrediIconTile(
            icon: icon,
            accent: KrediColors.orange,
            size: 48,
            iconSize: 25,
          ),
          const SizedBox(height: 11),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: KrediColors.black,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KrediColors.secondary, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class KrediJsonCard extends StatelessWidget {
  const KrediJsonCard({
    super.key,
    required this.data,
    this.titleKeys = const [
      'name',
      'title',
      'commercialName',
      'fullName',
      'invoiceNumber',
      'description',
    ],
    this.subtitleKeys = const ['status', 'email', 'category', 'createdAt'],
  });
  final Map<String, dynamic> data;
  final List<String> titleKeys;
  final List<String> subtitleKeys;

  String _pick(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final title = _pick(titleKeys, 'Registro #${data['id'] ?? ''}');
    final subtitle = _pick(subtitleKeys, 'Detalle Kredi+');
    return KrediSoftCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: const KrediIconTile(
          icon: KrediIcons.document,
          accent: KrediColors.orange,
          size: 40,
          iconSize: 20,
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: KrediColors.secondary),
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [KrediDetailView(data: data, compact: true)],
      ),
    );
  }
}

class KrediDetailView extends StatelessWidget {
  const KrediDetailView({super.key, required this.data, this.compact = false});
  final Map<String, dynamic> data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList();
    final visible = compact ? entries.take(8).toList() : entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _DetailRow(
            label: _humanize(visible[i].key),
            value: _displayValue(visible[i].value),
          ),
          if (i != visible.length - 1) const Divider(height: 14),
        ],
        if (compact && entries.length > visible.length) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              'Datos técnicos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KrediColors.secondary,
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(data),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: KrediColors.navySoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _humanize(String key) {
    const replacements = {
      'id': 'ID',
      'fullName': 'Nombre completo',
      'commercialName': 'Nombre comercial',
      'legalName': 'Razón social',
      'accountStatus': 'Estado de cuenta',
      'verificationStatus': 'Verificación',
      'createdAt': 'Creado',
      'updatedAt': 'Actualizado',
      'amountUsd': 'Monto USD',
      'amountBs': 'Monto Bs.',
      'priceUsd': 'Precio USD',
      'priceBs': 'Precio Bs.',
      'dueDate': 'Vencimiento',
      'invoiceNumber': 'Factura',
      'referenceNumber': 'Referencia',
      'phone': 'Teléfono',
      'email': 'Correo',
      'status': 'Estado',
      'username': 'Usuario',
      'description': 'Descripción',
      'category': 'Categoría',
    };
    if (replacements.containsKey(key)) return replacements[key]!;
    final spaced = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll('_', ' ');
    return spaced.isEmpty
        ? key
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  static String _displayValue(dynamic value) {
    if (value is bool) return value ? 'Sí' : 'No';
    if (value is List) {
      return value.isEmpty
          ? 'Sin registros'
          : '${value.length} elemento${value.length == 1 ? '' : 's'}';
    }
    if (value is Map) {
      return value.isEmpty
          ? 'Sin información'
          : '${value.length} campo${value.length == 1 ? '' : 's'}';
    }
    return value.toString();
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 110,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: KrediColors.secondary,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: KrediColors.black,
          ),
        ),
      ),
    ],
  );
}

void showKrediMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
