import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'design_system.dart';
import 'paciente_auth.dart';
import 'paciente_inicio.dart';
import 'paciente_registro.dart';
import 'widgets.dart';

/// Vista 18 adaptada a paciente: acceso al portal del paciente.
///
/// La marca es el archivo del proyecto, como en la cabecera del directorio de
/// especialistas. El botón de Google y el de soporte solo conservan el aspecto.
class PacienteLoginPage extends StatefulWidget {
  const PacienteLoginPage({super.key, this.auth});

  final PacienteAuth? auth;

  @override
  State<PacienteLoginPage> createState() => _PacienteLoginPageState();
}

class _PacienteLoginPageState extends State<PacienteLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  bool _submitting = false;

  /// El diseño llega con la casilla marcada.
  bool _rememberDevice = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu correo';
    if (!value.contains('@') || !value.contains('.')) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  /// Credenciales válidas: entra al dashboard del paciente.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;
    setState(() => _submitting = true);

    final resultado = await _auth.iniciarSesion(
      _email.text,
      _password.text,
    );

    if (!mounted) return;

    if (!resultado.exito) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resultado.textoParaUsuario)),
      );
      return;
    }

    if (await _auth.rolActual() != 'PACIENTE') {
      await _auth.cerrarSesion();
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta cuenta no tiene acceso al portal de pacientes.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PacienteInicioPage(auth: widget.auth),
      ),
    );
  }

  void _openRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PacienteRegistroPage()),
    );
  }

  /// Aviso de que el flujo todavía no existe, en vez de un botón muerto.
  void _pending(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrand(),
                  const SizedBox(height: 26),
                  if (!AppConfig.isConfigured) ...[
                    _buildConnectionNotice(),
                    const SizedBox(height: 18),
                  ],
                  _buildFormCard(),
                  const SizedBox(height: 18),
                  _buildSupport(),
                  const SizedBox(height: 14),
                  _buildRegisterCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Aviso cuando no hay conexion a la base de datos.
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
              'Sin conexion a la base de datos.',
              style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  // --- Marca --------------------------------------------------------------

  Widget _buildBrand() {
    return Column(
      children: [
        const BrandLogo(size: 64, radius: 16),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_border_rounded,
                size: 15,
                color: AppColors.brand,
              ),
              const SizedBox(width: 8),
              Text(
                'PORTAL PACIENTE',
                style: AppText.wordmark.copyWith(
                  color: AppColors.ink,
                  fontSize: 14,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Mindjora',
          textAlign: TextAlign.center,
          style: AppText.display.copyWith(color: AppColors.ink, fontSize: 30),
        ),
        const SizedBox(height: 8),
        Text(
          'Tu espacio seguro para el bienestar emocional',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 15.5),
        ),
      ],
    );
  }

  // --- Formulario ---------------------------------------------------------

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: 'Correo electrónico',
              controller: _email,
              hint: 'ejemplo@gmail.com',
              icon: Icons.badge_outlined,
              validator: _validEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            LabeledField(
              label: 'Contraseña',
              controller: _password,
              hint: '•••••••••••••',
              icon: Icons.lock_outline_rounded,
              validator: (value) => (value == null || value.length < 8)
                  ? 'Usa al menos 8 caracteres'
                  : null,
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              labelAction: InkWell(
                onTap: () => _pending('Te enviamos un enlace para recuperar el acceso.'),
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: AppText.body.copyWith(
                    color: AppColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
            const SizedBox(height: 20),
            _buildRememberRow(),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Iniciar Sesión como Paciente',
              icon: Icons.arrow_forward_rounded,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: 26),
            const _ContinueDivider(),
            const SizedBox(height: 22),
            _buildGoogleButton(),
          ],
        ),
      ),
    );
  }

  /// Entrada con Google. Es el único botón con marca ajena, así que no sale de
  /// [SoftButton] (que solo admite iconos de Material).
  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () =>
            _pending('El acceso con Google todavía no está disponible.'),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GoogleMark(size: 18),
            SizedBox(width: 10),
            Text(
              'Google',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  /// Casilla de «Recordar sesión»; el diseño la trae marcada en verde.
  Widget _buildRememberRow() {
    void toggle() => setState(() => _rememberDevice = !_rememberDevice);

    return InkWell(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // `checkColor` transparente: el dibujo muestra el cuadro verde
            // macizo, sin la paloma de Material.
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _rememberDevice,
                onChanged: (_) => toggle(),
                checkColor: Colors.transparent,
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.brand
                      : Colors.white,
                ),
                side: const BorderSide(color: AppColors.border, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Recordar sesión en este dispositivo',
                style: AppText.body.copyWith(
                  color: AppColors.inkSoft,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Acceso y alta ------------------------------------------------------

  /// Fila de soporte, fuera de la tarjeta.
  Widget _buildSupport() {
    return Row(
      children: [
        Icon(Icons.headset_mic_outlined, size: 22, color: AppColors.inkSoft),
        const SizedBox(width: 14),
        Expanded(
          child: InkWell(
            onTap: () => _pending('El canal de soporte todavía no está disponible.'),
            child: Text(
              '¿Problemas para acceder a tu sesión? Contactar soporte',
              style: AppText.body.copyWith(
                color: AppColors.inkSoft,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            '¿Aún no tienes cuenta?',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _openRegistration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Regístrate como Paciente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.ink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Separador con texto: «O continúa con».
class _ContinueDivider extends StatelessWidget {
  const _ContinueDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(height: 1, thickness: 1, color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'O continúa con',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
          ),
        ),
        Expanded(child: Divider(height: 1, thickness: 1, color: AppColors.border)),
      ],
    );
  }
}

/// «G» de Google con los cuatro colores de la marca.
///
/// Aproximación pintada a mano: el proyecto no trae el archivo oficial y una
/// «G» suelta en un color no se lee como el botón de Google. Se sustituye por
/// el asset en cuanto exista.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.19;
    final center = Offset(w / 2, w / 2);
    final ring = Rect.fromCircle(center: center, radius: w * 0.29);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Anillos en sentido horario desde las 12: azul arriba y a la derecha,
    // rojo abajo a la derecha, amarillo abajo a la izquierda, verde a la izquierda.
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(ring, start, sweep, false, strokePaint..color = color);
    }

    arc(blue, -1.5708, 2.0); // 270° → 385°: de las 12 a la barra
    arc(red, 0.43, 0.62); // bajo la barra hasta abajo
    arc(yellow, 1.05, 0.9);
    arc(green, 1.95, 2.19); // izquierda hasta volver a las 12

    // Trazo horizontal de la «G», del centro al borde derecho del anillo.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(center.dx - w * 0.02, center.dy - stroke / 2, center.dx + w * 0.29, center.dy + stroke / 2),
        Radius.circular(stroke / 2),
      ),
      Paint()..color = blue,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}