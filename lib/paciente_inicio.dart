import 'dart:async';

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_agenda.dart';
import 'paciente_chats.dart';
import 'paciente_auth.dart';
import 'paciente_diario.dart';
import 'paciente_notificaciones.dart';
import 'paciente_perfil.dart';
import 'paciente_sala.dart';
import 'paciente_tests.dart';
import 'widgets.dart';

/// La captura es maqueta: las acciones se conectan cuando exista su flujo.
void _noop() {}

/// Vista 5: Dashboard Principal del Paciente.
///
/// Pantalla de maquetación: el selector de ánimo es lo único que mantiene
/// estado, porque «En calma» viene seleccionado en el dibujo. La navegación
/// inferior, la campana, «Entrar a Sala Virtual», «Detalles de la cita» y la
/// batería psicométrica ya abren su vista; el resto de acciones (tareas y
/// acompañante) todavía no tiene flujo y solo conservan el
/// aspecto del botón.
///
/// El tema inicial puede recibirse con [initialDarkMode]; la pantalla no
/// muestra controles de tema ni un acceso directo al perfil.
class PacienteInicioPage extends StatefulWidget {
  const PacienteInicioPage({
    super.key,
    this.auth,
    this.initialDarkMode = false,
  });

  /// Servicio de autenticacion del paciente. Si es `null` se crea uno por
  /// defecto: la pantalla carga la ficha propia del paciente autenticado.
  final PacienteAuth? auth;

  /// Arranca la vista en modo oscuro. Útil para la revisión visual y para
  /// abrir el panel desde una ruta que ya sabe la preferencia.
  final bool initialDarkMode;

  @override
  State<PacienteInicioPage> createState() => _PacienteInicioPageState();
}

class _PacienteInicioPageState extends State<PacienteInicioPage> {
  /// «En calma» es el ánimo que muestra la captura de diseño.
  static const int _initialMood = 1;

  bool _dark = false;
  int _mood = _initialMood;

  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  /// `true` mientras se decide el modo (demo o real) y se cargan los datos.
  bool _cargando = true;

  /// `true` si la sesión activa es la cuenta que ve los mockups.
  bool _demo = false;

  ({
    String nombre,
    String correo,
    bool requiereAcompanante,
    String documento,
    String telefono,
    String direccion,
  })?
  _datos;
  Map<String, dynamic>? _cita;
  List<Map<String, dynamic>> _tareas = const [];
  List<Map<String, dynamic>> _evaluaciones = const [];
  Map<String, dynamic>? _acompanante;
  Map<int, ({String nombre, String? avatarUrl})> _directorio = const {};
  StreamSubscription<Map<String, dynamic>>? _mensajesSubscription;
  int _mensajesNuevos = 0;

  @override
  void initState() {
    super.initState();
    _dark = widget.initialDarkMode;
    _cargarDatos();
  }

  @override
  void dispose() {
    unawaited(_mensajesSubscription?.cancel());
    super.dispose();
  }

  /// En modo demo no se consulta nada: la pantalla muestra los mockups.
  /// En modo real se leen los datos propios del paciente autenticado.
  Future<void> _cargarDatos() async {
    try {
      final esDemo = await _auth.esCuentaDemo();
      if (!mounted) return;
      if (esDemo) {
        setState(() {
          _demo = true;
          _cargando = false;
        });
        return;
      }

      final resultados = await Future.wait<Object?>([
        _auth.datosPaciente(),
        _auth.citaSiguiente(),
        _auth.tareasPropias(),
        _auth.evaluacionesPropias(),
        _auth.acompanantePropio(),
        _auth.directorioPsicologos(),
      ]);
      if (!mounted) return;
      setState(() {
        _datos =
            resultados[0]
                as ({
                  String nombre,
                  String correo,
                  bool requiereAcompanante,
                  String documento,
                  String telefono,
                  String direccion,
                })?;
        _cita = resultados[1] as Map<String, dynamic>?;
        _tareas = (resultados[2] as List<Map<String, dynamic>>?) ?? const [];
        _evaluaciones =
            (resultados[3] as List<Map<String, dynamic>>?) ?? const [];
        _acompanante = resultados[4] as Map<String, dynamic>?;
        _directorio =
            resultados[5] as Map<int, ({String nombre, String? avatarUrl})>;
        _cargando = false;
      });
      _escucharMensajes();
    } catch (_) {
      // Sin sesión o sin configuración de base no hay datos propios: se queda
      // el modo real y cada bloque muestra su aviso.
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// «Agenda» abre el directorio de especialistas, «Diario» el diario emocional y
  /// «Perfil» el perfil del paciente.
  /// «Inicio» es esta misma pantalla:
  /// el toque va, pero la vista no cambia.
  void _openTab(int index) {
    final Widget? page = switch (index) {
      1 => PacienteAgendaPage(auth: _auth),
      2 => const PacienteDiarioPage(),
      3 => const PacientePerfilPage(),
      _ => null,
    };
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// «Entrar a Sala Virtual» y «Detalles de la cita» abren la antesala de la
  /// consulta.
  void _openRoom() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PacienteSalaPage(auth: _auth)),
    );
  }

  /// La campana de la cabecera abre el centro de notificaciones.
  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PacienteNotificacionesPage(auth: _auth),
      ),
    );
  }

  void _openChats() {
    _markChatMessagesSeen();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PacienteChatsPage(
          auth: _auth,
          onMessagesSeen: _markChatMessagesSeen,
        ),
      ),
    );
  }

  void _markChatMessagesSeen() {
    if (_mensajesNuevos > 0) setState(() => _mensajesNuevos = 0);
  }

  void _escucharMensajes() {
    if (_mensajesSubscription != null) return;
    _mensajesSubscription = _auth.mensajesEntrantes().listen(
      (mensaje) {
        if (!mounted) return;
        setState(() => _mensajesNuevos++);

        final id = int.tryParse('${mensaje['id_psicologo'] ?? ''}');
        final nombre = id == null ? null : _directorio[id]?.nombre;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Nuevo mensaje de ${nombre?.isNotEmpty == true ? nombre : 'tu psicólogo'}.',
              ),
              action: SnackBarAction(label: 'Ver chats', onPressed: _openChats),
            ),
          );
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('No se pudo mantener la conexión de chats.'),
            ),
          );
      },
    );
  }

  /// «Batería psicométrica periódica» abre los tests pre-consulta.
  void _openTests({String? testInicial}) {
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                PacienteTestsPage(auth: _auth, testInicial: testInicial),
          ),
        )
        .then((_) => _cargarDatos());
  }

  /// Una tarea «Completar test X» abre ese cuestionario. El resto de tareas
  /// no tiene flujo y se deja como texto.
  void _abrirTarea(String descripcion) {
    const prefijo = 'Completar test ';
    if (!descripcion.startsWith(prefijo)) return;
    final nombre = descripcion.substring(prefijo.length).trim();
    if (nombre.isEmpty) return;
    _openTests(testInicial: nombre);
  }

  @override
  Widget build(BuildContext context) {
    // Se resuelve desde el estado, no desde el contexto: este build está por
    // encima del `Theme` que envuelve la pantalla.
    final t = _dark ? PanelTokens.dark() : PanelTokens.light();

    if (_cargando) {
      return Theme(
        data: _dark ? AppTheme.dark() : AppTheme.light(),
        child: const Scaffold(
          body: SafeArea(child: Center(child: CircularProgressIndicator())),
        ),
      );
    }

    return Theme(
      data: _dark ? AppTheme.dark() : AppTheme.light(),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                // Deslizar hacia abajo vuelve a consultar la base. El
                // `AlwaysScrollable` hace el gesto posible aunque el
                // contenido quepa en pantalla.
                child: RefreshIndicator(
                  onRefresh: _cargarDatos,
                  color: AppColors.brand,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(t),
                        const SizedBox(height: 20),
                        _buildGreeting(t),
                        const SizedBox(height: 16),
                        _buildPerfilIncompleto(t),
                        _buildMoodPicker(t),
                        const SizedBox(height: 16),
                        _buildDbNotice(t),
                        const SizedBox(height: 14),
                        _buildAppointment(t),
                        const SizedBox(height: 30),
                        _buildEvaluations(t),
                        const SizedBox(height: 30),
                        _buildTasks(t),
                        const SizedBox(height: 16),
                        _buildCompanion(t),
                      ],
                    ),
                  ),
                ),
              ),
              PanelBottomNav(
                selectedIndex: 0,
                backgroundColor: t.navBar,
                borderColor: t.cardBorder,
                selectedColor: t.brand,
                idleColor: t.textFaint,
                onTabSelected: _openTab,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Cabecera ----------------------------------------------------------

  Widget _buildHeader(PanelTokens t) {
    return Row(
      children: [
        // La marca es el archivo del proyecto, como en el login y en el
        // directorio de especialistas.
        const BrandLogo(size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MINDJORA',
                style: TextStyle(
                  color: t.brand,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Inicio',
                style: AppText.wordmark.copyWith(
                  color: t.textStrong,
                  fontSize: 18,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        SquareIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: _mensajesNuevos == 0 ? 'Chats' : 'Chats, mensajes nuevos',
          onPressed: _openChats,
          backgroundColor: t.card,
          foregroundColor: t.textStrong,
          borderColor: t.cardBorder,
          badge: _mensajesNuevos > 0,
          badgeColor: t.brand,
        ),
        const SizedBox(width: 9),
        SquareIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notificaciones',
          onPressed: _openNotifications,
          backgroundColor: t.card,
          foregroundColor: t.textStrong,
          borderColor: t.cardBorder,
          badge: true,
        ),
      ],
    );
  }

  Widget _buildGreeting(PanelTokens t) {
    final nombre = _datos?.nombre.trim();
    final hayNombre = nombre != null && nombre.isNotEmpty;
    final saludo = hayNombre
        ? 'Hola, ${nombre.split(RegExp(r'\s+')).take(2).join(' ')}'
        // Sin nombre no se inventa uno: la captura es solo de la cuenta demo.
        : (_demo ? 'Hola, Karen Lucía' : 'Hola');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saludo,
                style: AppText.greeting.copyWith(
                  color: t.textStrong,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¿Cómo te sientes en este momento?',
                style: AppText.body.copyWith(fontSize: 14, color: t.textBody),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Datos de contacto --------------------------------------------------

  /// En cuentas reales, aviso hasta que haya telefono y direccion. La cuenta
  /// demo es un mockup y no se toca.
  Widget _buildPerfilIncompleto(PanelTokens t) {
    if (_demo || _datos == null) return const SizedBox.shrink();
    final telefono = _datos!.telefono.trim();
    final direccion = _datos!.direccion.trim();
    if (telefono.isNotEmpty && direccion.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final faltan = <String>[
      if (telefono.isEmpty) 'teléfono',
      if (direccion.isEmpty) 'dirección',
    ].join(' y ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: t.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 20, color: t.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Completar información',
                    style: AppText.wordmark.copyWith(
                      color: t.textStrong,
                      fontSize: 16,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu $faltan para que podamos contactarte.',
              style: AppText.body.copyWith(color: t.textBody, fontSize: 13),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Completar información',
              icon: Icons.edit_outlined,
              onPressed: _abrirCompletarInformacion,
              backgroundColor: t.brandFill,
              minHeight: 46,
            ),
          ],
        ),
      ),
    );
  }

  /// Hoja con los dos campos que faltan. Se guarda directo en `usuario`; la
  /// columna `direccion` la crea la migracion 20261123.
  void _abrirCompletarInformacion() {
    final formKey = GlobalKey<FormState>();
    final telefono = TextEditingController(text: _datos?.telefono ?? '');
    final direccion = TextEditingController(text: _datos?.direccion ?? '');
    final t = _dark ? PanelTokens.dark() : PanelTokens.light();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Completar información',
                  style: AppText.wordmark.copyWith(
                    color: t.textStrong,
                    fontSize: 18,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Agrega tu teléfono y tu dirección.',
                  style: AppText.body.copyWith(color: t.textBody, fontSize: 13),
                ),
                const SizedBox(height: 18),
                LabeledField(
                  label: 'Teléfono',
                  controller: telefono,
                  hint: '300 123 4567',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ingresa tu teléfono'
                      : null,
                ),
                const SizedBox(height: 16),
                LabeledField(
                  label: 'Dirección',
                  controller: direccion,
                  hint: 'Calle, número, ciudad',
                  icon: Icons.location_on_outlined,
                  keyboardType: TextInputType.streetAddress,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Ingresa tu dirección'
                      : null,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Guardar',
                  icon: Icons.save_outlined,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final ok = await _auth.actualizarContacto(
                      telefono: telefono.text,
                      direccion: direccion.text,
                    );
                    if (!mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              _auth.errorContacto ??
                                  'No se pudo guardar tu información.',
                            ),
                          ),
                        );
                      return;
                    }
                    final datos = _datos;
                    if (datos != null) {
                      setState(() {
                        _datos = (
                          nombre: datos.nombre,
                          correo: datos.correo,
                          requiereAcompanante: datos.requiereAcompanante,
                          documento: datos.documento,
                          telefono: telefono.text.trim(),
                          direccion: direccion.text.trim(),
                        );
                      });
                    }
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                  },
                  backgroundColor: t.brandFill,
                  minHeight: 50,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Estado de ánimo ----------------------------------------------------

  /// Guarda el ánimo elegido en `seguimiento_diario` (modo real). En demo
  /// solo mueve la selección, como en la captura.
  Future<void> _guardarAnimo(int nivel) async {
    if (_demo) return;
    final ok = await _auth.guardarSeguimiento(
      nivelAnimo: nivel + 1,
      comentarios: null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Ánimo guardado.'
                : (_auth.errorSeguimiento ?? 'No se pudo guardar tu ánimo.'),
          ),
        ),
      );
  }

  /// Los cinco niveles dentro de una tarjeta con borde; solo el elegido se
  /// pinta, así que los que no van se quedan sin fondo.
  Widget _buildMoodPicker(PanelTokens t) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _kMoods.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _MoodChip(
                mood: _kMoods[i],
                selected: i == _mood,
                t: t,
                onTap: () {
                  setState(() => _mood = i);
                  _guardarAnimo(i);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Aviso de conexion --------------------------------------------------

  /// En modo demo es parte del mockup. En modo real solo se pinta si la ficha
  /// no llegó: nunca se muestra un «sin conexión» fijo que no sea cierto.
  Widget _buildDbNotice(PanelTokens t) {
    final texto = _demo
        ? 'Sin conexion a la base de datos.'
        : (_datos == null ? 'No se pudieron cargar tus datos.' : null);
    if (texto == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: t.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: t.textFaint, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- Cita programada ----------------------------------------------------

  Widget _buildAppointment(PanelTokens t) {
    // Modo real: sin cita no hay tarjeta que pintar, y con cita solo lo que
    // vino de la base.
    if (!_demo) {
      // Pasada la hora, la cita deja de estar programada: ni tarjeta ni aviso.
      if (_cita == null) return const SizedBox.shrink();
      return _buildAppointmentReal(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Cita Programada',
          color: t.textStrong,
          fontSize: 19,
          trailing: const _Pill(label: 'En 3 horas', dot: true),
        ),
        const SizedBox(height: 14),
        _PanelCard(
          t: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _InitialsAvatar(initials: 'YC'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cita?['motivo_consulta'] as String? ??
                              'Terapia Individual',
                          style: AppText.wordmark.copyWith(
                            color: t.textStrong,
                            fontSize: 17.5,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Dra. Yani Casiani',
                          style: AppText.body.copyWith(
                            color: t.textStrong,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Psicóloga Clínica • Enfoque TCC',
                          style: AppText.body.copyWith(
                            color: t.textBody,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAppointmentMeta(t),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Entrar a Sala Virtual',
                icon: Icons.videocam_outlined,
                onPressed: _openRoom,
                backgroundColor: t.brandFill,
                minHeight: 52,
              ),
              const SizedBox(height: 10),
              SoftButton(
                label: 'Detalles de la cita',
                icon: Icons.info_outline_rounded,
                onPressed: _openRoom,
                backgroundColor: t.accent,
                foregroundColor: t.textStrong,
                borderColor: t.accentBorder,
                minHeight: 52,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bloque crema con el horario, la duración y el test de preconsulta.
  Widget _buildAppointmentMeta(PanelTokens t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: t.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: 18, color: t.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _cita != null && _cita!['fecha_hora'] != null
                      ? '${_cita!['fecha_hora']}'
                      : 'Hoy, 18:30 hrs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: t.textStrong,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '50 min',
                style: AppText.body.copyWith(color: t.textBody, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: t.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Test pre-consulta completado correctamente',
                  style: AppText.body.copyWith(color: t.textBody, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta de cita en modo real: solo lo que devolvió `citaSiguiente`.
  /// Nombre y foto del profesional vienen del RPC del directorio.
  Widget _buildAppointmentReal(PanelTokens t) {
    final cita = _cita!;
    final fecha = _formatearFecha(cita['fecha_hora'] as String?);
    final momento = _etiquetaMomento(cita['fecha_hora'] as String?);
    final motivo = (cita['motivo_consulta'] as String?)?.trim();
    final modalidad = _etiquetaModalidad(cita['modalidad'] as String?);
    final idPsi = int.tryParse('${cita['id_psicologo'] ?? ''}');
    final psi = idPsi == null ? null : _directorio[idPsi];
    final nombrePsi = psi?.nombre ?? 'Nombre del profesional no disponible.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Cita Programada',
          color: t.textStrong,
          fontSize: 19,
          trailing: momento == null
              ? null
              : _Pill(label: momento, dot: true, t: t),
        ),
        const SizedBox(height: 14),
        _PanelCard(
          t: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FotoPerfil(
                    iniciales: inicialesDe(nombrePsi),
                    url: psi?.avatarUrl,
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (motivo == null || motivo.isEmpty)
                              ? 'Cita programada'
                              : motivo,
                          style: AppText.wordmark.copyWith(
                            color: t.textStrong,
                            fontSize: 17.5,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          nombrePsi,
                          style: AppText.body.copyWith(
                            color: psi == null ? t.textFaint : t.textStrong,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          modalidad,
                          style: AppText.body.copyWith(
                            color: t.textBody,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAppointmentMetaReal(t, fecha: fecha, cita: cita),
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'Entrar a Sala Virtual',
                icon: Icons.videocam_outlined,
                onPressed: _openRoom,
                backgroundColor: t.brandFill,
                minHeight: 52,
              ),
              const SizedBox(height: 10),
              SoftButton(
                label: 'Detalles de la cita',
                icon: Icons.info_outline_rounded,
                onPressed: _openRoom,
                backgroundColor: t.accent,
                foregroundColor: t.textStrong,
                borderColor: t.accentBorder,
                minHeight: 52,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bloque crema con la fecha real de la cita y su estado.
  Widget _buildAppointmentMetaReal(
    PanelTokens t, {
    required String? fecha,
    required Map<String, dynamic> cita,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: t.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: 18, color: t.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fecha ?? 'Fecha no disponible',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: t.textStrong,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: t.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _etiquetaEstadoCita(cita['estado_cita'] as String?),
                  style: AppText.body.copyWith(color: t.textBody, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// «17/11/2026 18:30» en hora local, o `null` si la fecha no se pudo leer.
  static String? _formatearFecha(String? iso) {
    final fecha = iso == null ? null : DateTime.tryParse(iso);
    if (fecha == null) return null;
    final local = fecha.toLocal();
    String dos(int v) => v.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }

  /// «En 3 horas» o «Hace 20 min», calculado contra el reloj del dispositivo.
  static String? _etiquetaMomento(String? iso) {
    final fecha = iso == null ? null : DateTime.tryParse(iso);
    if (fecha == null) return null;
    final minutos = fecha.toLocal().difference(DateTime.now()).inMinutes.abs();
    final texto = minutos < 60
        ? '$minutos min'
        : minutos < 60 * 24
        ? '${(minutos / 60).round()} horas'
        : '${(minutos / (60 * 24)).round()} días';
    return fecha.isBefore(DateTime.now()) ? 'Hace $texto' : 'En $texto';
  }

  /// Etiqueta visible de `cita.modalidad`, con los valores del enum de la base.
  static String _etiquetaModalidad(String? valor) => switch (valor) {
    'PRESENCIAL' => 'Presencial',
    'TELECONSULTA' => 'Teleconsulta',
    'VIDEO' => 'Videollamada',
    _ => 'Modalidad no disponible',
  };

  /// Etiqueta visible de `cita.estado_cita`. La base dice COMPLETADA y la
  /// pantalla dice «Realizada», como en el resto del portal.
  static String _etiquetaEstadoCita(String? valor) => switch (valor) {
    'PENDIENTE' => 'Por confirmar',
    'CONFIRMADA' => 'Confirmada',
    'CANCELADA' => 'Cancelada',
    'COMPLETADA' => 'Realizada',
    _ => 'Estado no disponible',
  };

  // --- Estado y evaluaciones ---------------------------------------------

  Widget _buildEvaluations(PanelTokens t) {
    if (!_demo) return _buildEvaluationsReal(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Estado y Evaluaciones',
          color: t.textStrong,
          fontSize: 19,
          trailing: Text(
            'Septiembre 2026',
            style: AppText.body.copyWith(color: t.textBody, fontSize: 13),
          ),
        ),
        const SizedBox(height: 14),
        _PanelCard(
          t: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Los resultados de tus tests son confidenciales y serán '
                'revisados por tu psicólogo.',
                style: AppText.body.copyWith(color: t.textBody),
              ),
              const SizedBox(height: 14),
              _buildBatteryRow(t),
            ],
          ),
        ),
      ],
    );
  }

  /// Evaluaciones en modo real: las que trae `evaluacionesPropias`.
  Widget _buildEvaluationsReal(PanelTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Estado y Evaluaciones',
          color: t.textStrong,
          fontSize: 19,
        ),
        const SizedBox(height: 14),
        _PanelCard(
          t: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_evaluaciones.isEmpty)
                AvisoVacio(
                  texto: 'Aún no tienes evaluaciones registradas.',
                  t: t,
                )
              else
                for (var i = 0; i < _evaluaciones.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, thickness: 1, color: t.divider),
                    ),
                  _buildEvaluationRow(t, _evaluaciones[i]),
                ],
              const SizedBox(height: 14),
              _buildBatteryRow(t),
            ],
          ),
        ),
      ],
    );
  }

  /// Fila de evaluación real sin exponer el puntaje al paciente.
  Widget _buildEvaluationRow(PanelTokens t, Map<String, dynamic> fila) {
    final test = fila['test_psicometrico'];
    final nombre = (test is Map ? test['nombre'] : null) as String?;
    final completada = evaluacionRespondidaCompleta(fila);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            (nombre == null || nombre.isEmpty) ? 'Test sin nombre' : nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(
              color: t.textStrong,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          completada ? 'Completado' : 'Pendiente',
          style: AppText.bodySmall.copyWith(
            color: completada ? t.brand : t.textBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryRow(PanelTokens t) {
    return Material(
      color: t.soft,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: InkWell(
        onTap: _openTests,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(color: t.softBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 19, color: t.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Batería psicométrica periódica',
                  style: AppText.body.copyWith(
                    color: t.textStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                label: _demo
                    ? 'En 4 días'
                    : '${_evaluaciones.length} realizadas',
                t: t,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Tareas terapéuticas ----------------------------------------------

  Widget _buildTasks(PanelTokens t) {
    if (!_demo) return _buildTasksReal(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Tareas Terapéuticas de Hoy',
          color: t.textStrong,
          fontSize: 19,
          trailing: Text(
            '1 de 2 listas',
            style: AppText.body.copyWith(color: t.textBody, fontSize: 13),
          ),
        ),
        const SizedBox(height: 14),
        _TaskCard(
          t: t,
          done: true,
          title: 'Respiración diafrágmica',
          subtitle: 'Completado • 5 min',
          trailing: Icon(Icons.done_all_rounded, size: 19, color: t.brand),
        ),
        const SizedBox(height: 12),
        _TaskCard(
          t: t,
          done: false,
          title: 'Registro de pensamiento',
          subtitle: 'Técnica ABC de reestructuración',
          trailing: SoftButton(
            label: 'Realizar',
            onPressed: _noop,
            backgroundColor: t.soft,
            foregroundColor: t.brand,
            borderColor: t.softBorder,
            minWidth: 0,
            minHeight: 38,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            fontSize: 13,
            trailing: Icon(Icons.arrow_forward_rounded, size: 17),
          ),
        ),
      ],
    );
  }

  /// Tareas en modo real; las evaluaciones con todas sus respuestas también
  /// completan la tarea aunque el indicador de la tarea esté desactualizado.
  ///
  /// El botón «Realizar» no está en modo real porque por ahora no tiene flujo:
  /// mejor no pintar un botón que no hace nada.
  Widget _buildTasksReal(PanelTokens t) {
    final pendientes = _tareas
        .where((tarea) => !_tareaCompletada(tarea))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Tareas Terapéuticas de Hoy',
          color: t.textStrong,
          fontSize: 19,
          trailing: pendientes.isEmpty
              ? null
              : Text(
                  '${pendientes.length} pendientes',
                  style: AppText.body.copyWith(color: t.textBody, fontSize: 13),
                ),
        ),
        const SizedBox(height: 14),
        if (pendientes.isEmpty)
          AvisoVacio(texto: 'No tienes tareas pendientes.', t: t)
        else
          for (var i = 0; i < pendientes.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _taskCardReal(t, pendientes[i]),
          ],
      ],
    );
  }

  /// Tarea real del panel: solo «Completar test X» se puede abrir.
  Widget _taskCardReal(PanelTokens t, Map<String, dynamic> tarea) {
    final descripcion = '${tarea['descripcion'] ?? ''}';
    return _TaskCard(
      t: t,
      done: false,
      title: descripcion.isEmpty ? 'Tarea sin descripción' : descripcion,
      subtitle: 'Pendiente',
      trailing: _Pill(label: 'Pendiente', t: t),
      onTap: descripcion.startsWith('Completar test ')
          ? () => _abrirTarea(descripcion)
          : null,
    );
  }

  bool _tareaCompletada(Map<String, dynamic> tarea) {
    const prefijo = 'Completar test ';
    final descripcion = '${tarea['descripcion'] ?? ''}'.trim();
    if (!descripcion.startsWith(prefijo)) {
      return tarea['completada'] == true;
    }

    final nombreTest = descripcion
        .substring(prefijo.length)
        .trim()
        .toUpperCase();
    if (nombreTest.isEmpty) return false;
    final fechaAsignacion = DateTime.tryParse(
      '${tarea['fecha_asignacion'] ?? ''}',
    );

    return _evaluaciones.any((evaluacion) {
      if (!evaluacionRespondidaCompleta(evaluacion)) return false;

      final test = evaluacion['test_psicometrico'];
      final nombreEvaluacion = test is Map
          ? '${test['nombre'] ?? ''}'.trim().toUpperCase()
          : '';
      if (nombreEvaluacion != nombreTest) return false;

      final fechaCompletado = DateTime.tryParse(
        '${evaluacion['fecha_completado'] ?? ''}',
      );
      return fechaAsignacion == null ||
          fechaCompletado == null ||
          !fechaCompletado.isBefore(fechaAsignacion);
    });
  }

  // --- Acompañante vinculado ---------------------------------------------

  Widget _buildCompanion(PanelTokens t) {
    if (!_demo) return _buildCompanionReal(t);
    return _PanelCard(
      t: t,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(color: t.accentBorder),
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: 22,
              color: t.brand,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // `Wrap` y no `Row`: si el título y la píldora no caben en una
                // sola línea, la píldora baja en vez de recortar el título.
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Acompañante Vinculado',
                      style: AppText.body.copyWith(
                        color: t.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _Pill(label: 'ACTIVO', t: t),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Oscar Flerez (Acompañante / Padre) • Acceso a red de '
                  'asistencia y alertas de bienestar.',
                  style: AppText.body.copyWith(
                    color: t.textBody,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SquareIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Configurar acompañante',
            onPressed: _noop,
            backgroundColor: t.card,
            foregroundColor: t.brand,
            borderColor: t.softBorder,
          ),
        ],
      ),
    );
  }

  /// Acompañante en modo real: lo que trae `acompanantePropio`.
  ///
  /// Sin fila no se inventa a nadie: se avisa. El botón de configurar no se
  /// pinta porque todavía no tiene flujo.
  Widget _buildCompanionReal(PanelTokens t) {
    final comp = _acompanante;
    if (comp == null) {
      return AvisoVacio(texto: 'Aún no tienes acompañante vinculado.', t: t);
    }

    final nombre = '${comp['nombre'] ?? ''}'.trim();
    final parentesco = '${comp['parentesco'] ?? ''}'.trim();
    final telefono = '${comp['telefono'] ?? ''}'.trim();
    final detalle = [
      if (parentesco.isNotEmpty) parentesco,
      if (telefono.isNotEmpty) 'Tel. $telefono',
    ].join(' • ');

    return _PanelCard(
      t: t,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(color: t.accentBorder),
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: 22,
              color: t.brand,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      nombre.isEmpty ? 'Acompañante vinculado' : nombre,
                      style: AppText.body.copyWith(
                        color: t.textStrong,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _Pill(label: 'ACTIVO', t: t),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  detalle.isEmpty ? 'Sin datos de contacto.' : detalle,
                  style: AppText.body.copyWith(
                    color: t.textBody,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Estados de ánimo -----------------------------------------------------

/// Los cinco niveles del selector. El emoji va por orden de mejor a peor,
/// como en la escala de Material.
const List<({String label, String emoji})> _kMoods = [
  (label: 'Radiante', emoji: '😄'),
  (label: 'En calma', emoji: '🙂'),
  (label: 'Neutral', emoji: '😐'),
  (label: 'Sobrecarga', emoji: '😣'),
  (label: 'Inquietud', emoji: '😰'),
];

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.mood,
    required this.selected,
    required this.t,
    required this.onTap,
  });

  final ({String label, String emoji}) mood;
  final bool selected;
  final PanelTokens t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? t.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(
              color: selected ? t.accentBorder : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mood.emoji, style: const TextStyle(fontSize: 19)),
              const SizedBox(height: 6),
              Text(
                mood.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: selected ? t.textStrong : t.textBody,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Piezas de la pantalla ------------------------------------------------

/// Tarjeta crema con borde: bloque base de la cita, las evaluaciones,
/// las tareas y el acompañante.
class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.t, required this.child});

  final PanelTokens t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.cardBorder),
      ),
      child: child,
    );
  }
}

/// Píldora de estado: «En 3 horas», «En 4 días», «ACTIVO».
class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.t, this.dot = false});

  final String label;
  final PanelTokens? t;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final tokens = t ?? PanelTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.badge,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.badgeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tokens.brand,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppText.body.copyWith(
              color: tokens.badgeText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de tarea terapéutica: completada con tachado, o pendiente con su
/// botón «Realizar».
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.t,
    required this.done,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final PanelTokens t;
  final bool done;
  final String title;
  final String subtitle;
  final Widget trailing;

  /// Solo las tareas con flujo (los tests) se pueden tocar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = done ? t.textFaint : t.textStrong;
    final card = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: done ? t.accent : t.soft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: done ? t.accentBorder : t.softBorder),
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.edit_note_rounded,
              size: 20,
              color: t.brand,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: titleColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: t.textFaint,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: done ? t.textFaint : t.textBody,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: card,
      ),
    );
  }
}

/// Foto de la profesional. La captura trae una imagen que el proyecto todavía
/// no tiene, así que se resuelve con sus iniciales hasta que llegue el asset.
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final t = PanelTokens.of(context);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.accentBorder),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppText.wordmark.copyWith(
            color: t.textStrong,
            fontSize: 19,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
