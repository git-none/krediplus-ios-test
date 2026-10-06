import 'package:flutter/material.dart';

class KrediBrand extends StatelessWidget {
  const KrediBrand({super.key, this.height = 54, this.compact = false});

  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) => Image.asset(
    compact ? 'assets/brand/kredi_mark.png' : 'assets/brand/kredi_wordmark.png',
    height: height,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
  );
}
