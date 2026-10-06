import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_scope.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/kredi_fintech.dart';
import '../../core/icons/kredi_icons.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final contactFormKey = GlobalKey<FormState>();
  final locationFormKey = GlobalKey<FormState>();

  late final TextEditingController phone;
  late final TextEditingController address;
  late final TextEditingController email;
  final code = TextEditingController();
  final communityManual = TextEditingController();

  String? stateValue;
  String? municipalityValue;
  String? parishValue;
  String? communityValue;

  bool savingContact = false;
  bool savingLocation = false;
  bool savingEmail = false;
  bool emailCodeSent = false;
  bool initialized = false;

  String? contactMessage;
  String? locationMessage;
  String? emailMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final user = AppScope.of(context).auth.user!;
    phone = TextEditingController(text: _editablePhone(user.phone));
    address = TextEditingController(
      text: (user.raw['address'] ?? '').toString(),
    );
    email = TextEditingController(text: user.email);
    stateValue = _value(user.raw['state']);
    municipalityValue = _value(user.raw['municipality']);
    parishValue = _value(user.raw['parish']);
    communityValue = _value(user.raw['community']);
    communityManual.text = communityValue ?? '';
    initialized = true;
  }


  String _editablePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0058')) digits = digits.substring(4);
    if (digits.startsWith('58') && digits.length >= 12) digits = digits.substring(2);
    if (digits.length == 10 && RegExp(r'^(412|414|416|424|426)').hasMatch(digits)) {
      digits = '0$digits';
    }
    return digits.length > 11 ? digits.substring(digits.length - 11) : digits;
  }

  @override
  void dispose() {
    if (initialized) {
      phone.dispose();
      address.dispose();
      email.dispose();
    }
    code.dispose();
    communityManual.dispose();
    super.dispose();
  }

  Future<void> saveContact() async {
    if (savingContact) return;
    if (!(contactFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      savingContact = true;
      contactMessage = null;
    });
    try {
      final scope = AppScope.of(context);
      await scope.api.updateProfileContact(phone: phone.text);
      await scope.auth.refreshProfile();
      if (!mounted) return;
      phone.text = _editablePhone(scope.auth.user?.phone ?? phone.text.trim());
      setState(
        () => contactMessage = 'Tu teléfono se actualizó correctamente.',
      );
    } catch (e) {
      if (mounted) setState(() => contactMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => savingContact = false);
    }
  }

  Future<void> saveLocation() async {
    if (savingLocation) return;
    if (!(locationFormKey.currentState?.validate() ?? false)) return;

    final manual = communityManual.text.trim();
    final community = manual.isNotEmpty
        ? manual
        : (communityValue ?? '').trim();
    if ([
          stateValue,
          municipalityValue,
          parishValue,
        ].any((e) => e == null || e.trim().isEmpty) ||
        community.isEmpty) {
      setState(
        () => locationMessage =
            'Completa la comunidad o sector y la dirección para guardar.',
      );
      return;
    }

    setState(() {
      savingLocation = true;
      locationMessage = null;
    });
    try {
      final scope = AppScope.of(context);
      await scope.api.updateProfileLocation(
        state: stateValue!,
        municipality: municipalityValue!,
        parish: parishValue!,
        community: community,
        address: address.text,
      );
      await scope.auth.refreshProfile();
      if (!mounted) return;
      setState(() {
        communityValue = community;
        communityManual.text = community;
        locationMessage = 'Tu dirección se actualizó correctamente.';
      });
    } catch (e) {
      if (mounted) setState(() => locationMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => savingLocation = false);
    }
  }

  Future<void> requestEmail() async {
    final value = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      setState(() => emailMessage = 'Ingresa un correo electrónico válido.');
      return;
    }
    setState(() {
      savingEmail = true;
      emailMessage = null;
    });
    try {
      final response = await AppScope.of(context).api.requestEmailChange(value);
      if (mounted) {
        setState(() {
          emailCodeSent = true;
          emailMessage =
              (response['message'] ??
                      'Enviamos un código al nuevo correo. Escríbelo para confirmar el cambio.')
                  .toString();
        });
      }
    } catch (e) {
      if (mounted) setState(() => emailMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => savingEmail = false);
    }
  }

  Future<void> confirmEmail() async {
    final digits = code.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      setState(() => emailMessage = 'Ingresa el código de 6 dígitos.');
      return;
    }
    setState(() {
      savingEmail = true;
      emailMessage = null;
    });
    try {
      final scope = AppScope.of(context);
      await scope.api.confirmEmailChange(newEmail: email.text, code: digits);
      await scope.auth.refreshProfile();
      if (!mounted) return;
      email.text = scope.auth.user?.email ?? email.text.trim();
      setState(() {
        emailCodeSent = false;
        code.clear();
        emailMessage = 'Correo actualizado y verificado.';
      });
    } catch (e) {
      if (mounted) setState(() => emailMessage = _cleanError(e));
    } finally {
      if (mounted) setState(() => savingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = AppScope.of(context).auth.user!;
    final document = _cleanDisplay(
      (user.raw['documentNumberMasked'] ??
              user.raw['documentNumber'] ??
              '')
          .toString(),
    );
    final birthDate = _cleanDisplay((user.raw['birthDate'] ?? '').toString());
    final state = _cleanDisplay(stateValue ?? '');
    final municipality = _cleanDisplay(municipalityValue ?? '');
    final parish = _cleanDisplay(parishValue ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const KrediScreenTitle(
              'Tus datos',
              subtitle: 'Consulta tu información y actualiza solo los datos permitidos.',
            ),
            const SizedBox(height: 20),

            const _ProfileSectionTitle(
              icon: KrediIcons.person,
              title: 'Datos personales',
            ),
            const SizedBox(height: 10),
            KrediOutlineCard(
              child: Column(
                children: [
                  _ProfileInfoRow(
                    icon: KrediIcons.person,
                    label: 'Nombre',
                    value: _cleanDisplay(user.fullName),
                  ),
                  const Divider(height: 22),
                  _ProfileInfoRow(
                    icon: KrediIcons.username,
                    label: 'Usuario',
                    value: _cleanDisplay(user.username),
                  ),
                  const Divider(height: 22),
                  _ProfileInfoRow(
                    icon: KrediIcons.identity,
                    label: 'Documento',
                    value: document,
                  ),
                  const Divider(height: 22),
                  _ProfileInfoRow(
                    icon: KrediIcons.calendar,
                    label: 'Nacimiento',
                    value: birthDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Form(
              key: contactFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: phone,
                    enabled: !savingContact,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Teléfono de contacto',
                      hintText: '04141234567',
                      prefixIcon: Icon(KrediIcons.phone),
                      counterText: '',
                      errorMaxLines: 3,
                    ),
                    validator: (value) {
                      final digits = (value ?? '').trim();
                      return RegExp(r'^0(412|414|416|424|426)\d{7}$')
                              .hasMatch(digits)
                          ? null
                          : 'Ingresa 11 números, por ejemplo 04141234567.';
                    },
                    onFieldSubmitted: (_) {
                      if (!savingContact) saveContact();
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KrediActionButton(
                      icon: KrediIcons.save,
                      label: 'Guardar teléfono',
                      onPressed: saveContact,
                      busy: savingContact,
                    ),
                  ),
                ],
              ),
            ),
            if (contactMessage != null) ...[
              const SizedBox(height: 10),
              _messageCard(contactMessage!),
            ],

            const SizedBox(height: 28),
            const _ProfileSectionTitle(
              icon: KrediIcons.location,
              title: 'Ubicación',
            ),
            const SizedBox(height: 10),
            KrediOutlineCard(
              child: Column(
                children: [
                  _ProfileInfoRow(
                    icon: KrediIcons.map,
                    label: 'Estado',
                    value: state,
                  ),
                  const Divider(height: 22),
                  _ProfileInfoRow(
                    icon: KrediIcons.city,
                    label: 'Municipio',
                    value: municipality,
                  ),
                  const Divider(height: 22),
                  _ProfileInfoRow(
                    icon: KrediIcons.location,
                    label: 'Parroquia',
                    value: parish,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Estado, municipio y parroquia quedan vinculados a tu registro.',
              style: TextStyle(
                color: KrediColors.secondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Form(
              key: locationFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: communityManual,
                    enabled: !savingLocation,
                    maxLength: 180,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Comunidad o sector',
                      prefixIcon: Icon(KrediIcons.community),
                      counterText: '',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Ingresa tu comunidad o sector.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: address,
                    enabled: !savingLocation,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      hintText: 'Calle, casa o edificio y punto de referencia',
                      prefixIcon: Icon(KrediIcons.address),
                      errorMaxLines: 3,
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Ingresa tu dirección.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: KrediActionButton(
                      icon: KrediIcons.save,
                      label: 'Guardar dirección',
                      onPressed: saveLocation,
                      busy: savingLocation,
                    ),
                  ),
                ],
              ),
            ),
            if (locationMessage != null) ...[
              const SizedBox(height: 10),
              _messageCard(locationMessage!),
            ],

            const SizedBox(height: 28),
            const _ProfileSectionTitle(
              icon: KrediIcons.email,
              title: 'Contacto',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(KrediIcons.email),
              ),
              onChanged: (_) {
                if (emailCodeSent) {
                  setState(() {
                    emailCodeSent = false;
                    code.clear();
                    emailMessage = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            if (emailCodeSent) ...[
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Código de 6 dígitos',
                  prefixIcon: Icon(KrediIcons.verified),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              KrediActionButton(
                icon: KrediIcons.verified,
                label: 'Confirmar nuevo correo',
                onPressed: confirmEmail,
                busy: savingEmail,
                expanded: true,
              ),
              TextButton(
                onPressed: savingEmail ? null : requestEmail,
                child: const Text('Reenviar código'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: savingEmail ? null : requestEmail,
                icon: const Icon(KrediIcons.email),
                label: Text(
                  savingEmail ? 'Enviando…' : 'Verificar y cambiar correo',
                ),
              ),
            if (emailMessage != null) ...[
              const SizedBox(height: 10),
              _messageCard(emailMessage!),
            ],
            const SizedBox(height: 16),
            const KrediOutlineCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(KrediIcons.lock, size: 21),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Contraseña, PIN y biometría se gestionan desde Seguridad.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cleanDisplay(String value) {
    final clean = value.trim();
    final normalized = clean.toLowerCase();
    if (clean.isEmpty ||
        const {'none', 'null', 'undefined', 'n/a', 'nan'}.contains(normalized) ||
        RegExp(r'^(none|null)(\s+(none|null))*$', caseSensitive: false)
            .hasMatch(clean)) {
      return 'No disponible';
    }
    return clean;
  }

  Widget _messageCard(String value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: KrediColors.softCream,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: KrediColors.border),
    ),
    child: Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
    ),
  );

  static String? _value(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _cleanError(Object e) => e
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '')
      .replaceFirst('FormatException: ', '');
}


class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 21, color: KrediColors.coral),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 21, color: KrediColors.coral),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: KrediColors.secondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
