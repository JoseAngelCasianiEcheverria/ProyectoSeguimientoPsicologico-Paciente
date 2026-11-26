import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'design_system.dart';
import 'paciente_auth.dart';
import 'paciente_inicio.dart';
import 'paciente_login.dart';
import 'widgets.dart';

/// Vista 2: Registro de Paciente.
class PacienteRegistroPage extends StatefulWidget {
  const PacienteRegistroPage({super.key, this.auth});

  final PacienteAuth? auth;

  @override
  State<PacienteRegistroPage> createState() =>
      _PacienteRegistroPageState();
}

class _PacienteRegistroPageState extends State<PacienteRegistroPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _document = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _companionName = TextEditingController();
  final _companionDocument = TextEditingController();
  final _companionEmail = TextEditingController();
  bool _needsCompanion = true;
  bool _showPassword = false;
  bool _acceptedTerms = false;
  String? _relationship;

  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _companionName.dispose();
    _companionDocument.dispose();
    _companionEmail.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Este campo es obligatorio' : null;

  String? _validEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu correo';
    if (!value.contains('@') || !value.contains('.')) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  /// Regla que anuncia la fila de ayuda bajo el campo de contraseña.
  static bool _isStrongEnough(String value) {
    final hasLetter = RegExp('[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp('[0-9]').hasMatch(value);
    return value.length >= 8 && hasLetter && hasDigit;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Crea una contraseña';
    if (password.length < 8) return 'Usa al menos 8 caracteres';
    if (!_isStrongEnough(password)) return 'Combina letras y números';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acepta los términos para continuar.')),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);

    final resultado = await _auth.registrarPaciente(
      nombre: _name.text,
      correo: _email.text,
      contrasena: _password.text,
      documento: _document.text,
      telefono: _phone.text,
      requiereAcompanante: _needsCompanion,
      acompananteNombre: _needsCompanion ? _companionName.text : null,
      acompananteParentesco: _needsCompanion ? _relationship : null,
      acompananteDocumento: _needsCompanion ? _companionDocument.text : null,
      acompananteEmail: _needsCompanion ? _companionEmail.text : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!resultado.exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado.mensaje ?? 'No pudimos crear la cuenta.')),
      );
      return;
    }

    if (resultado.requiereConfirmacion) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada. Revisa tu correo para confirmarla.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PacienteLoginPage()),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PacienteInicioPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 16),
                          if (!AppConfig.isConfigured) _buildConnectionNotice(),
                          if (!AppConfig.isConfigured) const SizedBox(height: 16),
                          const SizedBox(height: 10),
                          const Text(
                            'Registro de Paciente',
                            style: AppText.display,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Comienza tu proceso terapéutico con '
                            'confidencialidad y registro clínico estructurado.',
                            style: AppText.body,
                          ),
                          const SizedBox(height: 22),
                          _buildPatientCard(),
                          const SizedBox(height: 14),
                          _buildCompanionToggle(),
                          if (_needsCompanion) ...[
                            const SizedBox(height: 14),
                            _buildAuthorizedCard(),
                          ],
                          const SizedBox(height: 18),
                          _buildConsent(),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: 'Completar Registro de Paciente',
                            icon: Icons.check_rounded,
                            onPressed: _submitting ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sin conexión a la base de datos.',
              style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const AppBackButton(),
        const SizedBox(width: 12),
        const Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: StepBadge(label: 'Paso 1 de 2: Datos de Cuenta'),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientCard() {
    return FormCard(
      children: [
        const SectionHeader(
          title: 'Información del Paciente',
          icon: Icons.person_outline_rounded,
        ),
        LabeledField(
          label: 'Nombre completo',
          controller: _name,
          hint: 'Ej. Juan Camilo Jurado Sanmiento',
          icon: Icons.badge_outlined,
          validator: _required,
          capitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        LabeledField(
          label: 'Documento de identidad',
          note: ' (Tarjeta / Cédula / DNI)',
          controller: _document,
          hint: '10458034',
          icon: Icons.fingerprint_rounded,
          validator: _required,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        LabeledField(
          label: 'Correo electrónico',
          controller: _email,
          hint: 'paciente@correo.com',
          icon: Icons.mail_outline_rounded,
          validator: _validEmail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        LabeledField(
          label: 'Teléfono móvil',
          controller: _phone,
          hint: '+57 300 000 0000',
          icon: Icons.call_outlined,
          validator: _required,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        LabeledField(
          label: 'Crear Contraseña',
          controller: _password,
          hint: 'Mínimo 8 caracteres',
          icon: Icons.lock_outline_rounded,
          validator: _validatePassword,
          obscureText: !_showPassword,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            tooltip: _showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(
              _showPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF8A9291),
            ),
          ),
        ),
        _buildPasswordRules(),
      ],
    );
  }

  Widget _buildPasswordRules() {
    final password = _password.text;
    final isValid = _isStrongEnough(password);
    final isEmpty = password.isEmpty;
    final label = isEmpty
        ? 'Pendiente'
        : isValid
            ? 'Válida'
            : password.length < 8
                ? 'Muy corta'
                : 'Faltan números';
    final color = isEmpty
        ? AppColors.textFaint
        : isValid
            ? AppColors.brand
            : AppColors.error;

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Reglas: alfanumérico, mínimo 8 caracteres',
            style: TextStyle(color: AppColors.textSoft, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCompanionToggle() {
    return FormCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Requiere registro de acompañante?',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Habilita el envío de notificaciones y seguimiento de '
                    'citas para un tercero autorizado.',
                    style: AppText.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            appSwitch(
              value: _needsCompanion,
              onChanged: (value) => setState(() => _needsCompanion = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthorizedCard() {
    return FormCard(
      children: [
        const SectionHeader(
          title: 'Datos de la persona autorizada',
          icon: Icons.group_outlined,
        ),
        LabeledField(
          label: 'Nombre del acompañante',
          controller: _companionName,
          hint: 'Ej. Rodrigo Valenzuela Fuentes',
          validator: _required,
          capitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
        ),
        LabeledField(
          label: 'Documento de identidad',
          controller: _companionDocument,
          hint: 'Ej. 14.520.118-2',
          validator: _required,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        LabeledField(
          label: 'Correo electrónico de contacto',
          controller: _companionEmail,
          hint: 'acomp@ejemplo.com',
          validator: _validEmail,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        _RelationshipField(
          value: _relationship,
          onChanged: (value) => setState(() => _relationship = value),
        ),
      ],
    );
  }

  Widget _buildConsent() {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox.adaptive(
                value: _acceptedTerms,
                activeColor: AppColors.brand,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) =>
                    setState(() => _acceptedTerms = value ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text.rich(
                    const TextSpan(
                      style: TextStyle(
                        color: Color(0xFF4A5150),
                        fontSize: 12,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: 'Acepto los '),
                        TextSpan(
                          text: 'Términos y Condiciones',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ', el Consentimiento Informado para '
                              'Telemedicina y el registro de expediente '
                              'clínico.',
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

class _RelationshipField extends StatefulWidget {
  const _RelationshipField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_RelationshipField> createState() => _RelationshipFieldState();
}

class _RelationshipFieldState extends State<_RelationshipField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 7),
          child: Text('Relación con el paciente', style: AppText.label),
        ),
        DropdownButtonFormField<String>(
          initialValue: widget.value,
          isExpanded: true,
          validator: (value) =>
              value == null ? 'Selecciona una relación' : null,
          decoration: appInputDecoration(
            hint: 'Selecciona el tipo de vínculo',
          ),
          items: const [
            DropdownMenuItem(
              value: 'Familiar directo',
              child: Text('Familiar directo'),
            ),
            DropdownMenuItem(value: 'Tutor legal', child: Text('Tutor legal')),
            DropdownMenuItem(
              value: 'Pareja / Cónyuge',
              child: Text('Pareja / Cónyuge'),
            ),
            DropdownMenuItem(
              value: 'Otro acompañante autorizado',
              child: Text(
                'Otro acompañante autorizado',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}