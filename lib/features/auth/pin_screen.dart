import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_scope.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_actions.dart';
import '../../shared/widgets/kredi_brand.dart';
import 'forgot_pin_screen.dart';
import '../../core/icons/kredi_icons.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final pin = TextEditingController();
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  @override
  void dispose() {
    focus.dispose();
    pin.dispose();
    super.dispose();
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Volver',
                    onPressed: auth.busy ? null : auth.cancelPin,
                    icon: const Icon(KrediIcons.back, size: 28),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: KrediBrand(height: 38)),
                        const SizedBox(height: 44),
                        const Text(
                          'Ingresa tu PIN',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: KrediColors.black,
                            fontSize: 20,
                            height: 1.08,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Escribe los 6 dígitos de acceso asociados a tu cuenta.',
                          style: TextStyle(
                            color: KrediColors.secondary,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (auth.pendingIdentifier.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            auth.pendingIdentifier,
                            style: const TextStyle(
                              color: KrediColors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 34),
                        _PinSlots(
                          value: pin.text,
                          focusNode: focus,
                          controller: pin,
                          enabled: !auth.busy,
                          onChanged: (value) {
                            auth.clearError();
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            if (value.length == 6 && !auth.busy) {
                              auth.verifyPin(value);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: auth.busy
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ForgotPinScreen(
                                        initialIdentifier:
                                            auth.pendingIdentifier,
                                      ),
                                    ),
                                  ),
                            child: const Text('¿Olvidaste tu PIN?'),
                          ),
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3EF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              auth.error!,
                              style: const TextStyle(
                                color: Color(0xFF8A2D19),
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        KrediActionButton(
                          icon: KrediIcons.lock,
                          label: 'Continuar',
                          onPressed: pin.text.length != 6
                              ? null
                              : () => auth.verifyPin(pin.text),
                          busy: auth.busy,
                          expanded: true,
                        ),
                      ],
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
}

class _PinSlots extends StatelessWidget {
  const _PinSlots({
    required this.value,
    required this.focusNode,
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String value;
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? focusNode.requestFocus : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final available = (constraints.maxWidth - gap * 5) / 6;
              final width = available.clamp(40.0, 50.0).toDouble();
              const height = 56.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final filled = index < value.length;
                  final active =
                      index == value.length &&
                      value.length < 6 &&
                      focusNode.hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active
                            ? KrediColors.orangeDeep
                            : filled
                            ? const Color(0xFFB7BBC2)
                            : const Color(0xFFD9DCE1),
                        width: active ? 1.8 : 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 100),
                      child: filled
                          ? const Text(
                              '•',
                              key: ValueKey('filled'),
                              style: TextStyle(
                                color: KrediColors.black,
                                fontSize: 20,
                                height: .9,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : const SizedBox(key: ValueKey('empty')),
                    ),
                  );
                }),
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.001,
              child: TextField(
                focusNode: focusNode,
                controller: controller,
                enabled: enabled,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
