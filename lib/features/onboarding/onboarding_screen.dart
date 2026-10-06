import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_actions.dart';
import '../../shared/widgets/kredi_brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _items = <_OnboardingItem>[
    _OnboardingItem(
      title: 'Compra hoy. Paga a tu ritmo.',
      subtitle: 'Elige productos y combos con tu línea Kredi+ y revisa todo antes de confirmar.',
      kind: _OnboardingVisualKind.buy,
    ),
    _OnboardingItem(
      title: 'Tus cuotas, siempre claras.',
      subtitle: 'Consulta montos, fechas y pagos pendientes sin perderte entre pantallas.',
      kind: _OnboardingVisualKind.pay,
    ),
    _OnboardingItem(
      title: 'Avanza y desbloquea más.',
      subtitle: 'Sube de nivel y amplía tus beneficios, desde 2 hasta un máximo de 12 cuotas.',
      kind: _OnboardingVisualKind.grow,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kredi_onboarding_v1_done', true);
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_page >= _items.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 18, 2),
              child: Row(
                children: [
                  const KrediBrand(height: 34),
                  const Spacer(),
                  TextButton(onPressed: _finish, child: const Text('Omitir')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _items.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _OnboardingPage(item: _items[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: KrediMotion.standard,
                    width: index == _page ? 24 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _page ? KrediColors.orangeDeep : KrediColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: KrediActionButton(
                  icon: _page == _items.length - 1 ? KrediIcons.check : KrediIcons.forward,
                  label: _page == _items.length - 1 ? 'Comenzar' : 'Continuar',
                  onPressed: _next,
                  expanded: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item});
  final _OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(0.0, constraints.maxWidth - 44);
        final heroWidth = math.min(430.0, availableWidth).toDouble();
        final heroHeight = math.min(330.0, heroWidth / 1.28).toDouble();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  width: heroWidth,
                  height: heroHeight,
                  child: _OnboardingHero(kind: item.kind),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.45,
                  color: KrediColors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.42,
                  color: KrediColors.secondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _OnboardingVisualKind { buy, pay, grow }

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.kind});
  final _OnboardingVisualKind kind;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(math.min(32.0, width * .075).toDouble()),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF6E9), Color(0xFFFFE3BC)],
            ),
            border: Border.all(color: const Color(0xFFFFD59B)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -width * .11,
                top: -height * .19,
                child: Container(
                  width: width * .44,
                  height: width * .44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x32FC5A35),
                  ),
                ),
              ),
              Positioned(
                left: -width * .08,
                bottom: -height * .20,
                child: Container(
                  width: width * .43,
                  height: width * .43,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x38FD9C24),
                  ),
                ),
              ),
              Positioned.fill(child: _visual()),
              Positioned(
                left: width * .055,
                top: height * .06,
                child: _MiniBrandBadge(compact: width < 330),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _visual() => switch (kind) {
        _OnboardingVisualKind.buy => const _BuyVisual(),
        _OnboardingVisualKind.pay => const _PayVisual(),
        _OnboardingVisualKind.grow => const _GrowVisual(),
      };
}

class _MiniBrandBadge extends StatelessWidget {
  const _MiniBrandBadge({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white),
        ),
        child: KrediBrand(height: compact ? 18 : 21, compact: true),
      );
}

class _BuyVisual extends StatelessWidget {
  const _BuyVisual();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final compact = w < 330;
        final cardLeft = w * .135;
        final cardTop = h * .315;
        final cardWidth = w * .56;
        final cardHeight = h * .45;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: cardLeft,
              top: cardTop,
              width: cardWidth,
              height: cardHeight,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 18,
                  compact ? 12 : 16,
                  compact ? 14 : 18,
                  compact ? 12 : 15,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [KrediColors.orange, KrediColors.coral],
                  ),
                  borderRadius: BorderRadius.circular(compact ? 22 : 27),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220B0B0C),
                      blurRadius: 22,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 7 : 8,
                        vertical: compact ? 5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: KrediBrand(height: compact ? 15 : 17, compact: true),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tu línea Kredi+',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 11 : 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'US\$ 60',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 25 : 31,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.8,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 7 : 9),
                    Container(
                      height: compact ? 5 : 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: .78,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: w * .065,
              top: h * .37,
              width: w * .255,
              height: h * .39,
              child: _ProductStack(compact: compact),
            ),
            Positioned(
              right: w * .055,
              top: h * .075,
              child: _HeroChip(
                icon: KrediIcons.credit,
                text: '0% inicial',
                compact: compact,
              ),
            ),
            Positioned(
              left: w * .07,
              bottom: h * .065,
              child: _HeroChip(
                icon: KrediIcons.combos,
                text: 'Productos y combos',
                compact: compact,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductStack extends StatelessWidget {
  const _ProductStack({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: 0,
              top: h * .08,
              width: w * .74,
              height: h * .73,
              child: const _OnboardingProductTile(accent: Color(0xFFFF8650)),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              width: w * .68,
              height: h * .62,
              child: const _OnboardingProductTile(accent: Color(0xFFFFE0A9)),
            ),
            Positioned(
              left: w * .08,
              top: 0,
              width: w * .72,
              height: h * .7,
              child: const _OnboardingProductTile(accent: Color(0xFFFFB66D)),
            ),
          ],
        );
      },
    );
  }
}

class _OnboardingProductTile extends StatelessWidget {
  const _OnboardingProductTile({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD8A3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120B0B0C),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE3D8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      );
}

class _PayVisual extends StatelessWidget {
  const _PayVisual();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final compact = w < 330;
        return Stack(
          children: [
            Positioned(
              left: w * .14,
              right: w * .14,
              top: h * .29,
              bottom: h * .15,
              child: Container(
                padding: EdgeInsets.all(compact ? 17 : 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 23 : 28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140B0B0C),
                      blurRadius: 22,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          KrediIcons.calendar,
                          color: KrediColors.orangeDeep,
                          size: compact ? 29 : 34,
                        ),
                        SizedBox(width: compact ? 9 : 12),
                        const Expanded(child: _FakeLine(widthFactor: .74)),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    const Row(
                      children: [
                        Expanded(child: _FakeLine(widthFactor: .9)),
                        SizedBox(width: 10),
                        _AmountBadge(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: w * .07,
              bottom: h * .065,
              child: _HeroChip(
                icon: KrediIcons.success,
                text: 'Al día',
                compact: compact,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GrowVisual extends StatelessWidget {
  const _GrowVisual();

  static const _installments = [2, 4, 6, 8, 10, 12];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final compact = w < 330;
        return Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _OnboardingMountainsPainter())),
            Positioned(
              right: w * .07,
              top: h * .18,
              child: Container(
                width: compact ? 60 : 72,
                height: compact ? 60 : 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD59B)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120B0B0C),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '12',
                      style: TextStyle(
                        fontSize: compact ? 24 : 28,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: KrediColors.orangeDeep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'cuotas',
                      style: TextStyle(
                        fontSize: compact ? 8.5 : 9.5,
                        fontWeight: FontWeight.w800,
                        color: KrediColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: w * .07,
              right: w * .07,
              bottom: h * .055,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 11,
                  vertical: compact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFFFD8A3)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x100B0B0C),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(_installments.length, (index) {
                    final value = _installments[index];
                    final last = index == _installments.length - 1;
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: compact ? 26 : 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: last ? KrediColors.orange : KrediColors.softOrange,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '$value',
                                style: TextStyle(
                                  fontSize: compact ? 10 : 11,
                                  fontWeight: FontWeight.w900,
                                  color: KrediColors.black,
                                ),
                              ),
                            ),
                          ),
                          if (!last)
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 3),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: compact ? 12 : 14,
                                color: KrediColors.orangeDeep,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text, this.compact = false});
  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(maxWidth: compact ? 150 : 190),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 11,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFFFD8A3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100B0B0C),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 14 : 16, color: KrediColors.orangeDeep),
            SizedBox(width: compact ? 5 : 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w800,
                    color: KrediColors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _FakeLine extends StatelessWidget {
  const _FakeLine({required this.widthFactor});
  final double widthFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: 11,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE2BA),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      );
}

class _AmountBadge extends StatelessWidget {
  const _AmountBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: KrediColors.softOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'US\$',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: KrediColors.orangeDeep,
          ),
        ),
      );
}

class _OnboardingMountainsPainter extends CustomPainter {
  const _OnboardingMountainsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final low = Paint()..color = const Color(0xFFFFD9AA);
    final mid = Paint()..color = const Color(0xFFFFB876);
    final high = Paint()..color = const Color(0xFFFF8446);

    Path mountain(double left, double peakX, double peakY, double right) => Path()
      ..moveTo(left, size.height * .82)
      ..lineTo(peakX, peakY)
      ..lineTo(right, size.height * .82)
      ..close();

    canvas.drawPath(
      mountain(-10, size.width * .28, size.height * .35, size.width * .57),
      low,
    );
    canvas.drawPath(
      mountain(size.width * .24, size.width * .58, size.height * .19, size.width * .9),
      mid,
    );
    canvas.drawPath(
      mountain(size.width * .55, size.width * .82, size.height * .38, size.width + 18),
      high,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingItem {
  const _OnboardingItem({required this.title, required this.subtitle, required this.kind});
  final String title;
  final String subtitle;
  final _OnboardingVisualKind kind;
}
