import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../app_scope.dart';
import '../../core/location/venezuela_locations.dart';
import '../../core/theme/kredi_theme.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/kredi_select.dart';
import '../../shared/widgets/kredi_ui.dart';
import 'registration_verification_screen.dart';
import '../../core/icons/kredi_icons.dart';
import '../../core/input/kredi_input_formatters.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{
    for (final key in [
      'username',
      'firstName',
      'middleName',
      'lastName',
      'secondLastName',
      'nationalId',
      'email',
      'phone',
      'birthDate',
      'address',
      'password',
      'pin',
    ])
      key: TextEditingController(),
  };

  int step = 0;
  String employment = 'PUBLIC_EMPLOYEE';
  String? state;
  String? municipality;
  String? parish;
  String? community;
  List<String> municipalities = const [];
  List<String> parishes = const [];
  List<String> communities = const [];
  bool loadingMunicipalities = false;
  bool loadingParishes = false;
  bool loadingCommunities = false;
  bool accepted = false;
  bool busy = false;
  DateTime? birthDate;

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          onPressed: busy
              ? null
              : () {
                  if (step > 0) {
                    setState(() => step--);
                  } else {
                    Navigator.pop(context);
                  }
                },
          icon: const Icon(KrediIcons.back),
        ),
      ),
      body: KrediAuthBackground(
        child: SafeArea(
          top: false,
          bottom: true,
          child: KrediResponsive(
            child: Form(
              key: form,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomInset),
                children: [
                  _Progress(step: step),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 190),
                    child: switch (step) {
                      0 => _personalStep(),
                      1 => _locationStep(),
                      _ => _securityStep(),
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 56,
                    child: KrediActionButton(
                      icon: step < 2 ? KrediIcons.forward : KrediIcons.confirm,
                      label: step < 2 ? 'Continuar' : 'Crear mi cuenta',
                      onPressed: step < 2 ? _next : _submit,
                      busy: busy,
                      expanded: true,
                    ),
                  ),
                  if (step == 2) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Luego verificarás tu identidad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: KrediColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _personalStep() => KrediSoftCard(
    key: const ValueKey('personal'),
    radius: 22,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KrediSectionHeader('Tus datos'),
        const SizedBox(height: 14),
        _field('username', 'Nombre de usuario', KrediIcons.person),
        _gap,
        _responsivePair(
          _field('firstName', 'Primer nombre', KrediIcons.identity),
          _field(
            'middleName',
            'Segundo nombre',
            KrediIcons.identity,
            optional: true,
          ),
        ),
        _gap,
        _responsivePair(
          _field('lastName', 'Primer apellido', KrediIcons.identity),
          _field(
            'secondLastName',
            'Segundo apellido',
            KrediIcons.identity,
            optional: true,
          ),
        ),
        _gap,
        _field(
          'nationalId',
          'Cédula de identidad',
          KrediIcons.card,
          keyboardType: TextInputType.number,
          hintText: '12345678',
          prefixText: 'V-',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          validator: (value) {
            final digits = (value ?? '').trim();
            return digits.length >= 6 ? null : 'Ingresa tu cédula';
          },
        ),
        _gap,
        _field(
          'email',
          'Correo electrónico',
          KrediIcons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _gap,
        _field(
          'phone',
          'Teléfono',
          KrediIcons.phone,
          keyboardType: TextInputType.number,
          hintText: '04141234567',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          validator: (value) {
            final digits = (value ?? '').trim();
            return digits.length == 11 ? null : 'Ingresa 11 números';
          },
        ),
        _gap,
        TextFormField(
          controller: controllers['birthDate'],
          enabled: !busy,
          keyboardType: TextInputType.number,
          inputFormatters: const [KrediDateInputFormatter()],
          onChanged: _onBirthDateChanged,
          decoration: InputDecoration(
            labelText: 'Fecha de nacimiento',
            hintText: 'DD/MM/AAAA',
            prefixIcon: const Icon(KrediIcons.calendar),
            suffixIcon: IconButton(
              tooltip: 'Abrir calendario',
              onPressed: busy ? null : _pickBirthDate,
              icon: const Icon(KrediIcons.calendar),
            ),
          ),
          validator: _validateBirthDate,
        ),
      ],
    ),
  );

  Widget _locationStep() => KrediSoftCard(
    key: const ValueKey('location'),
    radius: 22,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KrediSectionHeader('Ubicación'),
        const SizedBox(height: 14),
        KrediSelectField<String>(
          label: 'Tipo de empleo',
          icon: KrediIcons.work,
          value: employment,
          options: const [
            KrediSelectOption('PUBLIC_EMPLOYEE', 'Empleado público'),
            KrediSelectOption('PRIVATE_EMPLOYEE', 'Empleado privado'),
            KrediSelectOption('SELF_EMPLOYED', 'Trabajador independiente'),
            KrediSelectOption('OTHER', 'Otro'),
          ],
          onChanged: (value) => setState(() => employment = value),
        ),
        _gap,
        KrediSelectField<String>(
          label: 'Estado',
          icon: KrediIcons.map,
          value: state,
          options: VenezuelaLocations.instance.states
              .map((e) => KrediSelectOption(e, e))
              .toList(),
          onChanged: _selectState,
          searchHint: 'Buscar estado',
        ),
        _gap,
        KrediSelectField<String>(
          label: 'Municipio',
          icon: KrediIcons.city,
          value: municipality,
          loading: loadingMunicipalities,
          enabled: state != null && state!.isNotEmpty,
          hint: state == null
              ? 'Primero elige un estado'
              : 'Seleccionar municipio',
          options: municipalities.map((e) => KrediSelectOption(e, e)).toList(),
          onChanged: _selectMunicipality,
          searchHint: 'Buscar municipio',
          emptyMessage: 'No se pudieron cargar los municipios.',
        ),
        _gap,
        KrediSelectField<String>(
          label: 'Parroquia',
          icon: KrediIcons.location,
          value: parish,
          loading: loadingParishes,
          enabled: municipality != null && municipality!.isNotEmpty,
          hint: municipality == null
              ? 'Primero elige un municipio'
              : 'Seleccionar parroquia',
          options: parishes.map((e) => KrediSelectOption(e, e)).toList(),
          onChanged: _selectParish,
          searchHint: 'Buscar parroquia',
          emptyMessage: 'No se pudieron cargar las parroquias.',
        ),
        _gap,
        KrediSelectField<String>(
          label: 'Comunidad',
          icon: KrediIcons.community,
          value: community,
          loading: loadingCommunities,
          enabled: parish != null && parish!.isNotEmpty,
          hint: parish == null
              ? 'Primero elige una parroquia'
              : 'Seleccionar comunidad',
          options: communities.map((e) => KrediSelectOption(e, e)).toList(),
          onChanged: (value) => setState(() => community = value),
          searchHint: 'Buscar comunidad',
        ),
        _gap,
        _field(
          'address',
          'Dirección',
          KrediIcons.address,
          maxLines: 2,
          hintText: 'Calle, sector, edificio/casa y referencia',
        ),
      ],
    ),
  );

  Widget _securityStep() => KrediSoftCard(
    key: const ValueKey('security'),
    radius: 22,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KrediSectionHeader('Seguridad'),
        const SizedBox(height: 14),
        TextFormField(
          controller: controllers['password'],
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: Icon(KrediIcons.lock),
          ),
          validator: (value) =>
              value != null && value.length >= 8 ? null : 'Mínimo 8 caracteres',
        ),
        _gap,
        TextFormField(
          controller: controllers['pin'],
          keyboardType: TextInputType.number,
          obscureText: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'PIN de 6 dígitos',
            prefixIcon: Icon(KrediIcons.pin),
          ),
          validator: (value) =>
              value != null && value.length == 6 ? null : 'PIN de 6 dígitos',
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          value: accepted,
          onChanged: busy
              ? null
              : (value) => setState(() => accepted = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: KrediColors.orange,
          title: const Text(
            'Acepto los términos y la privacidad',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : _showPrivacySummary,
            icon: const Icon(KrediIcons.privacy, size: 18),
            label: const Text('Ver términos y privacidad'),
          ),
        ),
      ],
    ),
  );

  static const _gap = SizedBox(height: 11);

  Future<void> _showPrivacySummary() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacidad y modelo de pagos',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Tus líneas Kredi+ son líneas de compra.\n'
              '• Kredi+ no almacena ni transfiere dinero.\n'
              '• Los pagos se realizan por medios externos.\n'
              '• Solo registramos los datos necesarios para validar pagos.\n'
              '• Nunca pedimos claves de tu banco.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _responsivePair(Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth < 360) {
        return Column(children: [a, _gap, b]);
      }
      return Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      );
    },
  );

  Widget _field(
    String key,
    String label,
    IconData icon, {
    bool optional = false,
    TextInputType? keyboardType,
    String? hintText,
    String? prefixText,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controllers[key],
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixText: prefixText,
      floatingLabelBehavior: prefixText == null
          ? FloatingLabelBehavior.auto
          : FloatingLabelBehavior.always,
      prefixIcon: Icon(icon),
    ),
    validator: validator ??
        (optional
            ? null
            : (value) => value == null || value.trim().isEmpty
                ? 'Campo requerido'
                : null),
  );

  void _onBirthDateChanged(String value) {
    if (value.length != 10) {
      if (birthDate != null) setState(() => birthDate = null);
      return;
    }
    try {
      final parsed = DateFormat('dd/MM/yyyy').parseStrict(value);
      final now = DateTime.now();
      final latest = DateTime(now.year - 12, now.month, now.day);
      if (parsed.isBefore(DateTime(1920)) || parsed.isAfter(latest)) {
        if (birthDate != null) setState(() => birthDate = null);
        return;
      }
      setState(() => birthDate = parsed);
    } catch (_) {
      if (birthDate != null) setState(() => birthDate = null);
    }
  }

  String? _validateBirthDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu fecha';
    if (value.length != 10 || birthDate == null) return 'Usa DD/MM/AAAA';
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('es', 'VE'),
      initialDate: birthDate ?? DateTime(now.year - 25, now.month, now.day),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 12, now.month, now.day),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );
    if (selected == null) return;
    setState(() {
      birthDate = selected;
      controllers['birthDate']!.text = DateFormat(
        'dd/MM/yyyy',
        'es',
      ).format(selected);
    });
  }

  Future<void> _selectState(String value) async {
    setState(() {
      state = value;
      municipality = null;
      parish = null;
      community = null;
      municipalities = const [];
      parishes = const [];
      communities = const [];
      loadingMunicipalities = true;
    });
    final loaded = await VenezuelaLocations.instance.municipalities(value);
    if (!mounted) return;
    setState(() {
      municipalities = loaded;
      loadingMunicipalities = false;
    });
  }

  Future<void> _selectMunicipality(String value) async {
    final s = state;
    if (s == null) return;
    setState(() {
      municipality = value;
      parish = null;
      community = null;
      parishes = const [];
      communities = const [];
      loadingParishes = true;
    });
    final loaded = await VenezuelaLocations.instance.parishes(s, value);
    if (!mounted) return;
    setState(() {
      parishes = loaded;
      loadingParishes = false;
    });
  }

  Future<void> _selectParish(String value) async {
    final s = state;
    final m = municipality;
    if (s == null || m == null) return;
    setState(() {
      parish = value;
      community = null;
      communities = const [];
      loadingCommunities = true;
    });
    try {
      final rows = await AppScope.of(
        context,
      ).api.registrationCommunities(state: s, municipality: m, parish: value);
      final values =
          rows
              .map((e) => (e['name'] ?? e['community'] ?? '').toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (values.isEmpty) values.add('Sin comunidad registrada');
      if (!mounted) return;
      setState(() {
        communities = values;
        community = values.length == 1 ? values.first : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        communities = ['Sin comunidad registrada'];
        community = 'Sin comunidad registrada';
      });
    } finally {
      if (mounted) setState(() => loadingCommunities = false);
    }
  }

  void _next() {
    if (form.currentState?.validate() != true) return;
    if (step == 1 &&
        (state == null ||
            municipality == null ||
            parish == null ||
            community == null)) {
      showKrediMessage(
        context,
        'Completa Estado, Municipio, Parroquia y Comunidad.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => step++);
  }

  Future<void> _submit() async {
    if (form.currentState?.validate() != true) return;
    if (!accepted) {
      showKrediMessage(
        context,
        'Debes aceptar los términos y la política de privacidad.',
      );
      return;
    }
    final birth = birthDate;
    if (birth == null ||
        state == null ||
        municipality == null ||
        parish == null ||
        community == null) {
      showKrediMessage(context, 'Revisa tus datos antes de continuar.');
      return;
    }
    setState(() => busy = true);
    final auth = AppScope.of(context).auth;
    final ok = await auth.register({
      'username': controllers['username']!.text.trim(),
      'firstName': controllers['firstName']!.text.trim(),
      'middleName': controllers['middleName']!.text.trim(),
      'lastName': controllers['lastName']!.text.trim(),
      'secondLastName': controllers['secondLastName']!.text.trim(),
      'nationalId': 'V-${controllers['nationalId']!.text.trim()}',
      'email': controllers['email']!.text.trim(),
      'phone': controllers['phone']!.text.trim(),
      'birthDate': DateFormat('yyyy-MM-dd').format(birth),
      'employmentType': employment,
      'state': state,
      'municipality': municipality,
      'parish': parish,
      'community': community,
      'address': controllers['address']!.text.trim(),
      'password': controllers['password']!.text,
      'pin': controllers['pin']!.text,
      'acceptedTerms': true,
      'termsVersion': '2026-09-13',
      'privacyVersion': '2026-09-13-control-cuotas',
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) {
      showKrediMessage(
        context,
        auth.error ?? 'No fue posible crear la cuenta.',
      );
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RegistrationVerificationScreen()),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(child: _bar(active: i <= step)),
            if (i < 2) const SizedBox(width: 6),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _label('1 · Datos', step == 0)),
          Expanded(child: _label('2 · Ubicación', step == 1)),
          Expanded(
            child: _label('3 · Seguridad', step == 2, align: TextAlign.right),
          ),
        ],
      ),
    ],
  );

  Widget _label(
    String value,
    bool active, {
    TextAlign align = TextAlign.center,
  }) => Text(
    value,
    textAlign: align,
    style: TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: active ? KrediColors.orange : KrediColors.secondary,
    ),
  );

  Widget _bar({required bool active}) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    height: 5,
    decoration: BoxDecoration(
      color: active ? KrediColors.orange : KrediColors.border,
      borderRadius: BorderRadius.circular(99),
    ),
  );
}
