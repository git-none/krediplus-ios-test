import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_brand.dart';
import '../../shared/widgets/kredi_fintech.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'registration_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  int step = 0;
  bool obscure = true;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (username.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu usuario o correo.')),
      );
      return;
    }
    setState(() => step = 1);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Row(
                  children: [
                    if (step == 1)
                      IconButton(
                        onPressed: auth.busy
                            ? null
                            : () => setState(() => step = 0),
                        icon: const Icon(KrediIcons.back, size: 28),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: auth.busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  initialIdentifier: username.text.trim(),
                                ),
                              ),
                            ),
                      icon: const Icon(KrediIcons.help, size: 18),
                      label: const Text('Ayuda'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: KrediMetrics.contentMaxWidth,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      child: step == 0
                          ? _identifierStep(auth)
                          : _passwordStep(auth),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identifierStep(dynamic auth) {
    return Column(
      key: const ValueKey('identifier'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Center(child: KrediBrand(height: 46)),
        const SizedBox(height: 26),
        const KrediScreenTitle(
          'Entra a Kredi+',
          subtitle: 'Usa el correo o usuario de tu cuenta.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: username,
          autofocus: true,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => auth.clearError(),
          onSubmitted: (_) => _continue(),
          decoration: const InputDecoration(
            hintText: 'tumail@ejemplo.com',
            prefixIcon: Icon(KrediIcons.username),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 56,
          child: KrediActionButton(
            icon: KrediIcons.forward,
            label: 'Continuar',
            onPressed: _continue,
            busy: auth.busy,
            expanded: true,
            tone: KrediActionTone.dark,
          ),
        ),
        const SizedBox(height: 24),
        KrediOutlineCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(KrediIcons.welcome, color: KrediColors.coral),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¿Primera vez en Kredi+?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: auth.busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _passwordStep(dynamic auth) {
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const KrediScreenTitle('Inicia sesión en Kredi+'),
        const SizedBox(height: 8),
        Text(
          username.text.trim(),
          style: const TextStyle(
            fontSize: 14,
            color: KrediColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: password,
          autofocus: true,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          onChanged: (_) => auth.clearError(),
          onSubmitted: (_) => _submit(auth),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(KrediIcons.lock),
            suffixIcon: IconButton(
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure
                    ? KrediIcons.visibility
                    : KrediIcons.visibilityOff,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: auth.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForgotPasswordScreen(
                        initialIdentifier: username.text.trim(),
                      ),
                    ),
                  ),
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                color: KrediColors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (auth.error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KrediColors.softError,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFC8B7)),
            ),
            child: Text(
              auth.error!,
              style: const TextStyle(
                color: Color(0xFF8A2E18),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          child: KrediActionButton(
            icon: KrediIcons.lock,
            label: 'Ingresar',
            onPressed: () => _submit(auth),
            busy: auth.busy,
            expanded: true,
            tone: KrediActionTone.dark,
          ),
        ),
      ],
    );
  }

  Future<void> _submit(dynamic auth) async {
    FocusScope.of(context).unfocus();
    await auth.login(username.text, password.text);
    if (!mounted) return;
    if (auth.hasPendingRegistration) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RegistrationVerificationScreen(),
        ),
      );
    }
  }
}
