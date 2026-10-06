import 'package:flutter/material.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_brand.dart';

/// Splash de marca Kredi+.
///
/// Se muestra la identidad completa, no el isotipo aislado dentro de otra
/// tarjeta. El objetivo es una entrada limpia y reconocible antes del login.
class KrediSplashScreen extends StatefulWidget {
  const KrediSplashScreen({super.key});

  @override
  State<KrediSplashScreen> createState() => _KrediSplashScreenState();
}

class _KrediSplashScreenState extends State<KrediSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scale = Tween<double>(
      begin: .94,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned(
              right: -86,
              top: 90,
              child: _SoftCircle(size: 210, color: KrediColors.softOrange),
            ),
            const Positioned(
              left: -110,
              bottom: 70,
              child: _SoftCircle(size: 250, color: Color(0xFFFFF1E8)),
            ),
            Center(
              child: FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 42),
                    child: KrediBrand(height: 58),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
