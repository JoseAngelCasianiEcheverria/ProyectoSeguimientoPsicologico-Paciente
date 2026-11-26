import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_agenda.dart';
import 'paciente_auth.dart';
import 'paciente_inicio.dart';
import 'paciente_notificaciones.dart';
import 'paciente_perfil.dart';
import 'widgets.dart';

/// La captura es maqueta: lo que todavía no tiene flujo conserva el aspecto.
void _noop() {}

/// Borde de las superficies verdes (píldoras e iconos con fondo).
///
/// Es el mismo del panel en modo claro; se toma de [PanelTokens] para no
/// repetir el hex.
final Color _accentBorder = PanelTokens.light().accentBorder;

/// Vista: diario emocional y actividades del paciente.
///
/// Semana en curso, registro rápido de ánimo, tareas asignadas y evolución.
/// Como el directorio de especialistas, es una vista de una sola apariencia:
/// usa [AppColors] directamente y la barra inferior compartida con «Diario»
/// marcado.
///
/// Mantienen estado el nivel de energía, las emociones elegidas y la
/// reflexión. En modo demo (la cuenta de Karen) la semana, las tareas y la
/// gráfica son los de la captura; en modo real se leen `tareasPropias` y
/// `seguimientoPropio`, y donde no hay datos se avisa en vez de inventarlos.
class PacienteDiarioPage extends StatefulWidget {
  const PacienteDiarioPage({super.key, this.auth});

  final PacienteAuth? auth;

  @override
  State<PacienteDiarioPage> createState() => _PacienteDiarioPageState();
}

class _PacienteDiarioPageState extends State<PacienteDiarioPage> {
  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  /// `true` mientras se decide el modo (demo o real) y se cargan los datos.
  bool _cargando = true;

  /// `true` si la sesión activa es la cuenta que ve los mockups.
  bool _demo = false;

  /// Tareas propias (`tarea_recomendada`) y últimos registros
  /// (`seguimiento_diario`) en modo real.
  List<Map<String, dynamic>> _tareas = const [];
  List<Map<String, dynamic>> _registros = const [];

  /// «Calma moderada»: el nivel con el que llega el diseño (0 a 4).
  double _energy = 2;

  /// Emociones elegidas. La cuenta demo arranca con «Gratitud», como en el
  /// diseño; en modo real empieza vacío para no dar por marcada una emoción
  /// que la persona no eligió.
  final Set<String> _feelings = <String>{};

  final TextEditingController _reflection = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  /// En modo demo no se consulta nada: la pantalla muestra los mockups.
  /// En modo real se leen las tareas y el seguimiento propios.
  Future<void> _cargarDatos() async {
    try {
      final esDemo = await _auth.esCuentaDemo();
      if (!mounted) return;
      if (esDemo) {
        setState(() {
          _demo = true;
          _feelings.add('Gratitud');
          _cargando = false;
        });
        return;
      }

      final resultados = await Future.wait<Object?>([
        _auth.tareasPropias(),
        _auth.seguimientoPropio(),
      ]);
      if (!mounted) return;
      setState(() {
        _tareas = (resultados[0] as List<Map<String, dynamic>>?) ?? const [];
        _registros = (resultados[1] as List<Map<String, dynamic>>?) ?? const [];
        _cargando = false;
      });
    } catch (_) {
      // Sin sesión o sin configuración de base no hay datos propios: se queda
      // el modo real y cada bloque muestra su aviso.
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  void _toggleFeeling(String feeling) {
    setState(() {
      if (!_feelings.add(feeling)) _feelings.remove(feeling);
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);

    // La cuenta demo no escribe en la base: solo conserva el flujo de la
    // captura.
    if (_demo) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Registro de hoy guardado.')),
      );
      return;
    }

    final idPaciente = await _auth.idPacienteActual();
    if (idPaciente == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos guardar el registro. Intenta de nuevo.'),
        ),
      );
      return;
    }

    final ok = await _auth.guardarSeguimiento(
      nivelAnimo: (_energy * 25).round(),
      comentarios: _reflection.text.trim().isEmpty ? null : _reflection.text.trim(),
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos guardar el registro. Intenta de nuevo.'),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Registro de hoy guardado.')),
    );

    // La semana y la gráfica se vuelven a leer con el registro nuevo.
    if (mounted) _cargarDatos();
  }

  /// La campana de la cabecera abre el centro de notificaciones.
  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PacienteNotificacionesPage(auth: _auth),
      ),
    );
  }

  /// «Inicio» deshace un solo empuje (el panel queda debajo); «Agenda»
  /// sustituye esta pantalla para que las pestañas no se apilen. «Diario» es
  /// esta misma pantalla, así que no hace nada, y «Perfil» sustituye esta
  /// pantalla igual que «Agenda».
  void _openTab(int index) {
    final navigator = Navigator.of(context);
    switch (index) {
      case 0:
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          navigator.push(
            MaterialPageRoute<void>(builder: (_) => const PacienteInicioPage()),
          );
        }
      case 1:
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PacienteAgendaPage(auth: _auth),
          ),
        );
      case 3:
        navigator.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const PacientePerfilPage()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              // Deslizar hacia abajo vuelve a consultar tareas y registros;
              // el `AlwaysScrollable` permite el gesto aunque el contenido
              // quepa en pantalla.
              child: RefreshIndicator(
                onRefresh: _cargarDatos,
                color: AppColors.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 22),
                      _buildPhasePill(),
                      const SizedBox(height: 14),
                      _buildTitleBlock(),
                      const SizedBox(height: 18),
                      _buildWeek(),
                      const SizedBox(height: 16),
                      _buildQuickLog(),
                      const SizedBox(height: 26),
                      _buildTasks(),
                      const SizedBox(height: 26),
                      _buildTrend(),
                      const SizedBox(height: 18),
                      const PrivacyNotice(
                        text: AppText.diaryNotice,
                        dashed: true,
                        background: AppColors.canvas,
                        borderColor: AppColors.border,
                        icon: Icons.verified_user_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PanelBottomNav(
              selectedIndex: 2,
              backgroundColor: Colors.white,
              borderColor: AppColors.border,
              selectedColor: AppColors.brand,
              idleColor: AppColors.textFaint,
              onTabSelected: _openTab,
            ),
          ],
        ),
      ),
    );
  }

  // --- Cabecera ----------------------------------------------------------

  Widget _buildTopBar() {
    return Row(
      children: [
        const BrandLogo(size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MINDJORA',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Diario',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.wordmark.copyWith(
                  color: AppColors.ink,
                  fontSize: 17,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        SquareIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notificaciones',
          onPressed: _openNotifications,
          badge: true,
        ),
        const SizedBox(width: 9),
        const SquareIconButton(
          icon: Icons.person_outline_rounded,
          tooltip: 'Mi perfil',
          onPressed: _noop,
        ),
      ],
    );
  }

  /// «Fase 4 · Acompañamiento Activo»: mismo molde que el contador del
  /// directorio, con el texto flexible para que no desborde.
  ///
  /// La base no guarda fases del proceso, así que en modo real la píldora no
  /// se pinta: no hay dato real que mostrar.
  Widget _buildPhasePill() {
    if (!_demo) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(AppRadius.soft),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_outlined, size: 15, color: AppColors.brand),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'Fase 4 · Acompañamiento Activo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Diario Emocional y Actividades',
          style: AppText.display.copyWith(color: AppColors.ink, fontSize: 26),
        ),
        const SizedBox(height: 8),
        Text(
          'Registra tus sensaciones y avanza en tus tareas terapéuticas con '
          'calma reflexiva.',
          style: AppText.body.copyWith(
            color: AppColors.inkSoft,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // --- Semana en curso ---------------------------------------------------

  Widget _buildWeek() {
    if (!_demo) return _buildWeekReal();
    return _DiaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Semana en curso',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 18,
                      color: AppColors.brand,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '5 días constantes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.brand,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _kWeek.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _WeekDayChip(entry: _kWeek[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Semana en modo real: los días con registro de `seguimiento_diario`.
  ///
  /// La racha se calcula con los registros propios (la base no la guarda) y,
  /// si esta semana no hay ningún registro, se avisa en vez de pintar ánimos.
  Widget _buildWeekReal() {
    final tokens = PanelTokens.light();
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));

    final porDia = <String, Map<String, dynamic>>{};
    for (final fila in _registros) {
      final fecha = DateTime.tryParse('${fila['fecha']}');
      if (fecha == null) continue;
      porDia[_claveDia(DateTime(fecha.year, fecha.month, fecha.day))] = fila;
    }

    final entradas =
        List<({String day, String? mood, _DayState state})>.generate(7, (
          i,
        ) {
          final dia = lunes.add(Duration(days: i));
          final registro = porDia[_claveDia(dia)];
          final esHoy = i == hoy.weekday - 1;
          if (registro != null && !esHoy) {
            return (
              day: _kAxis[i].toUpperCase(),
              mood: _etiquetaAnimo(registro['nivel_animo']),
              state: _DayState.logged,
            );
          }
          if (esHoy) {
            return (
              day: _kAxis[i].toUpperCase(),
              mood: registro == null
                  ? 'Hoy'
                  : _etiquetaAnimo(registro['nivel_animo']),
              state: _DayState.today,
            );
          }
          return (day: _kAxis[i].toUpperCase(), mood: null, state: _DayState.upcoming);
        });

    var racha = 0;
    var cursor = hoy;
    if (!porDia.containsKey(_claveDia(cursor))) {
      // Si hoy todavía no se registró, la racha cuenta hasta ayer.
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (porDia.containsKey(_claveDia(cursor))) {
      racha++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var hayEstaSemana = false;
    for (var i = 0; i < 7; i++) {
      if (porDia.containsKey(_claveDia(lunes.add(Duration(days: i))))) {
        hayEstaSemana = true;
        break;
      }
    }

    return _DiaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Semana en curso',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (racha > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 18,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$racha ${racha == 1 ? 'día' : 'días'} con registro',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < entradas.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _WeekDayChip(entry: entradas[i])),
              ],
            ],
          ),
          if (!hayEstaSemana) ...[
            const SizedBox(height: 12),
            AvisoVacio(
              texto: 'Aún no hay registros esta semana.',
              t: tokens,
            ),
          ],
        ],
      ),
    );
  }

  /// Clave de día (año-mes-día) para cruzar registros con la semana.
  static String _claveDia(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// Nombre corto del nivel de ánimo (0 a 100) para la tira de la semana.
  static String? _etiquetaAnimo(Object? nivel) {
    final n = (nivel as num?)?.toInt();
    if (n == null) return null;
    return _kShortMoods[(n / 25).round().clamp(0, 4)];
  }

  // --- Registro rápido ---------------------------------------------------

  Widget _buildQuickLog() {
    final level = _kEnergyLevels[_energy.round()];

    return _DiaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.soft),
                  border: Border.all(color: _accentBorder),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  size: 22,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registro Rápido de Ánimo',
                      style: AppText.panelHeading.copyWith(
                        color: AppColors.ink,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¿Cómo se percibe tu cuerpo hoy?',
                      style: AppText.body.copyWith(
                        color: AppColors.inkSoft,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _StatusPill(label: 'Hoy'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nivel de energía anímica',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: level),
            ],
          ),
          const SizedBox(height: 6),
          _buildEnergySlider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text('Agotamiento', style: _tickStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: Text(
                    'Equilibrio',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _tickStyle,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Vitalidad alta',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _tickStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Desencadenantes y emociones sentidas',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final feeling in _kFeelings)
                _FeelingChip(
                  label: feeling,
                  selected: _feelings.contains(feeling),
                  onTap: () => _toggleFeeling(feeling),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Reflexión breve',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Opcional',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reflection,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
            decoration: appInputDecoration(
              hint: 'Anotar pensamientos del momento...',
            ).copyWith(fillColor: AppColors.softFill),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Guardar Registro de Hoy',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  static const TextStyle _tickStyle = TextStyle(
    color: AppColors.inkSoft,
    fontSize: 12,
  );

  /// Deslizador de cinco niveles. En la captura salía vacío y sin pulgar, así
  /// que no se veía qué nivel estaba elegido: aquí la pista se rellena hasta
  /// el pulgar y la píldora de arriba nombra el nivel.
  Widget _buildEnergySlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: AppColors.brand,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.brand,
        overlayColor: AppColors.brand.withValues(alpha: 0.12),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: _energy,
        max: 4,
        divisions: 4,
        semanticFormatterCallback: (value) => _kEnergyLevels[value.round()],
        onChanged: (value) => setState(() => _energy = value),
      ),
    );
  }

  // --- Tareas asignadas --------------------------------------------------

  Widget _buildTasks() {
    if (!_demo) return _buildTasksReal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.assignment_outlined, size: 22, color: AppColors.brand),
            SizedBox(width: 9),
            Expanded(
              child: PanelSectionHeading(
                title: 'Tareas Asignadas',
                color: AppColors.ink,
                fontSize: 19,
                // La doctora es la del panel y la del directorio; la captura
                // traía otro nombre.
                trailing: Text(
                  'Dra. Yani Casiani',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildPrimaryTask(),
        const SizedBox(height: 12),
        const _DiaryTaskRow(
          icon: Icons.check_rounded,
          done: true,
          title: 'Caminata consciente y grounding',
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  'Completado hoy a las 11:00 hrs',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.check_rounded, size: 14, color: AppColors.brand),
            ],
          ),
          trailing: SquareIconButton(
            icon: Icons.visibility_outlined,
            tooltip: 'Ver tarea completada',
            onPressed: _noop,
          ),
        ),
        const SizedBox(height: 12),
        const _DiaryTaskRow(
          icon: Icons.menu_book_outlined,
          done: false,
          title: 'Higiene de sueño y descanso',
          subtitle: Text(
            'Recomendada por Dra. Yani Casiani',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
          ),
          trailing: SoftButton(
            label: 'Leer ficha',
            onPressed: _noop,
            backgroundColor: AppColors.softFill,
            foregroundColor: AppColors.ink,
            borderColor: AppColors.border,
            minWidth: 0,
            minHeight: 38,
            padding: EdgeInsets.symmetric(horizontal: 14),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  /// Tareas en modo real: las que trae `tareasPropias`.
  ///
  /// Sin la doctora de la captura (el nombre del profesional no se expone,
  /// bloqueo 6.1) y sin la tarea destacada, que era un maqueta.
  Widget _buildTasksReal() {
    final tokens = PanelTokens.light();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.assignment_outlined, size: 22, color: AppColors.brand),
            SizedBox(width: 9),
            Expanded(
              child: PanelSectionHeading(
                title: 'Tareas Asignadas',
                color: AppColors.ink,
                fontSize: 19,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_tareas.isEmpty)
          AvisoVacio(texto: 'Aún no tienes tareas asignadas.', t: tokens)
        else
          for (var i = 0; i < _tareas.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildTaskRowReal(_tareas[i]),
          ],
      ],
    );
  }

  /// Fila de una tarea real: descripción y estado, sin acciones sin flujo.
  Widget _buildTaskRowReal(Map<String, dynamic> tarea) {
    final hecha = tarea['completada'] == true;
    return _DiaryTaskRow(
      icon: hecha ? Icons.check_rounded : Icons.menu_book_outlined,
      done: hecha,
      title: '${tarea['descripcion'] ?? 'Tarea sin descripción'}',
      subtitle: Text(
        hecha ? 'Completado' : 'Pendiente',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hecha ? AppColors.textFaint : AppColors.inkSoft,
          fontSize: 12.5,
        ),
      ),
      trailing: hecha
          ? const Icon(Icons.check_rounded, size: 18, color: AppColors.brand)
          : null,
    );
  }

  /// La tarea pendiente destacada, con su etiqueta, duración y botón.
  Widget _buildPrimaryTask() {
    return _DiaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: _TaskTag(label: 'Terapia Cognitivo-Conductual'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Registro de Pensamiento Disfuncional (Modelo ABC)',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifica el evento activador, tu creencia inmediata y la '
            'consecuencia emocional.',
            style: AppText.body.copyWith(
              color: AppColors.inkSoft,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: AppColors.inkSoft,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '8 minutos aprox.',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: PrimaryButton(
                  label: 'Comenzar',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _noop,
                  minHeight: 46,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Evolución ---------------------------------------------------------

  Widget _buildTrend() {
    if (!_demo) return _buildTrendReal();
    return _DiaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolución del Estado de Ánimo',
                      style: AppText.panelHeading.copyWith(
                        color: AppColors.ink,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tendencia semanal de serenidad y valencia',
                      style: AppText.body.copyWith(
                        color: AppColors.inkSoft,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SquareIconButton(
                icon: Icons.show_chart_rounded,
                tooltip: 'Ver detalle de la tendencia',
                onPressed: _noop,
                backgroundColor: AppColors.brandSoft,
                foregroundColor: AppColors.brand,
                borderColor: _accentBorder,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SizedBox(
            height: 116,
            child: CustomPaint(painter: _MoodTrendPainter(values: _kTrendDemo)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < _kAxis.length; i++)
                Expanded(
                  child: Text(
                    _kAxis[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: i == _kTodayIndex
                          ? AppColors.ink
                          : AppColors.inkSoft,
                      fontSize: 11.5,
                      fontWeight: i == _kTodayIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.softFill,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 19,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppText.body.copyWith(
                        color: AppColors.ink,
                        fontSize: 13,
                        height: 1.45,
                      ),
                      children: const [
                        TextSpan(text: 'Tus niveles de calma aumentaron un '),
                        TextSpan(
                          text: '18%',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' después de las sesiones de grounding '
                              'matutinas.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  /// Evolución en modo real: la gráfica se dibuja con los registros de la
  /// semana propia.
  ///
  /// Sin registros no se traza una línea inventada: se avisa. La caja del
  /// «18%» era un dato de la captura y en modo real no se pinta.
  Widget _buildTrendReal() {
    final tokens = PanelTokens.light();
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));

    final porDia = <String, Map<String, dynamic>>{};
    for (final fila in _registros) {
      final fecha = DateTime.tryParse('${fila['fecha']}');
      if (fecha == null) continue;
      porDia[_claveDia(DateTime(fecha.year, fecha.month, fecha.day))] = fila;
    }

    // Ánimo del día, de 0 a 1; `null` = sin registro ese día.
    final valores = List<double?>.generate(7, (i) {
      final registro = porDia[_claveDia(lunes.add(Duration(days: i)))];
      if (registro == null) return null;
      final n = (registro['nivel_animo'] as num?)?.toInt();
      if (n == null) return null;
      return (n / 100).clamp(0.0, 1.0).toDouble();
    });

    final encabezado = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Evolución del Estado de Ánimo',
          style: AppText.panelHeading.copyWith(color: AppColors.ink, fontSize: 19),
        ),
        const SizedBox(height: 4),
        Text(
          'Tendencia semanal de serenidad y valencia',
          style: AppText.body.copyWith(color: AppColors.inkSoft, fontSize: 13.5),
        ),
      ],
    );

    if (!valores.any((v) => v != null)) {
      return _DiaryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            encabezado,
            const SizedBox(height: 14),
            AvisoVacio(texto: 'Aún no hay registros esta semana.', t: tokens),
          ],
        ),
      );
    }

    return _DiaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          encabezado,
          const SizedBox(height: 18),
          SizedBox(
            height: 116,
            child: CustomPaint(painter: _MoodTrendPainter(values: valores)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < _kAxis.length; i++)
                Expanded(
                  child: Text(
                    _kAxis[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: i == hoy.weekday - 1
                          ? AppColors.ink
                          : AppColors.inkSoft,
                      fontSize: 11.5,
                      fontWeight: i == hoy.weekday - 1
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Datos de muestra ------------------------------------------------------

/// Niveles del deslizador de energía, de menor a mayor. El del medio es
/// «Equilibrio» en la escala de abajo.
const List<String> _kEnergyLevels = <String>[
  'Agotamiento',
  'Calma baja',
  'Calma moderada',
  'Calma alta',
  'Vitalidad alta',
];

/// Emociones y desencadenantes que se pueden marcar.
const List<String> _kFeelings = <String>[
  'Ansiedad laboral',
  'Gratitud',
  'Cansancio',
  'Logro personal',
  'Sobrecarga',
];

/// Nombre corto de cada nivel de ánimo (0 a 100, de 25 en 25) para la tira
/// de la semana en modo real: en una columna de unos 47 px no caben los
/// nombres largos de la escala del deslizador.
const List<String> _kShortMoods = <String>[
  'Muy baja',
  'Baja',
  'Media',
  'Alta',
  'Muy alta',
];

/// Serenidad de la captura para la gráfica: lunes a viernes con dato y el
/// fin de semana sin él (`null` = sin registro).
const List<double?> _kTrendDemo = <double?>[0.38, 0.52, 0.30, 0.72, 0.86, null, null];

/// Estado de un día en la tira de la semana.
enum _DayState { logged, today, upcoming }

/// Tira de la semana: los días con registro llevan su ánimo, hoy (viernes)
/// va marcado y el fin de semana queda por venir. Las abreviaturas son las
/// del directorio y las de la gráfica, no una letra suelta.
const List<({String day, String? mood, _DayState state})> _kWeek =
    <({String day, String? mood, _DayState state})>[
      (day: 'LUN', mood: 'Calma', state: _DayState.logged),
      (day: 'MAR', mood: 'Sereno', state: _DayState.logged),
      (day: 'MIÉ', mood: 'Bajo', state: _DayState.logged),
      (day: 'JUE', mood: 'Vital', state: _DayState.logged),
      (day: 'VIE', mood: 'Hoy', state: _DayState.today),
      (day: 'SÁB', mood: null, state: _DayState.upcoming),
      (day: 'DOM', mood: null, state: _DayState.upcoming),
    ];

/// Etiquetas del eje de la gráfica; «Vie» es hoy.
const List<String> _kAxis = <String>[
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];
const int _kTodayIndex = 4;

// --- Piezas de la pantalla -------------------------------------------------

/// Tarjeta blanca con borde: bloque base del diario.
class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Píldora verde: «Hoy» y el nombre del nivel de energía elegido.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentBorder),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.brandDark,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Un día de la tira de la semana: abreviatura, ánimo y punto de registro.
///
/// Todos miden lo mismo; los del fin de semana, por venir, van atenuados con
/// un círculo vacío en vez del punto.
class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({required this.entry});

  final ({String day, String? mood, _DayState state}) entry;

  @override
  Widget build(BuildContext context) {
    final today = entry.state == _DayState.today;
    final upcoming = entry.state == _DayState.upcoming;
    final strong = today
        ? Colors.white
        : upcoming
        ? AppColors.textFaint
        : AppColors.ink;
    final soft = today
        ? Colors.white
        : upcoming
        ? AppColors.textFaint
        : AppColors.inkSoft;

    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
      decoration: BoxDecoration(
        color: today
            ? AppColors.dayActive
            : upcoming
            ? AppColors.softFill
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(
          color: today ? AppColors.dayActive : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              entry.day,
              maxLines: 1,
              style: TextStyle(
                color: strong,
                fontSize: 10,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 14,
            child: entry.mood == null
                ? null
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      entry.mood!,
                      maxLines: 1,
                      style: TextStyle(
                        color: soft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: upcoming
                  ? null
                  : today
                  ? Colors.white
                  : AppColors.brand,
              border: upcoming
                  ? Border.all(color: AppColors.textFaint, width: 1.2)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Emoción o desencadenante: el elegido va relleno de verde con un punto
/// blanco; el resto, con un círculo vacío.
class _FeelingChip extends StatelessWidget {
  const _FeelingChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : AppColors.chipBg,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : null,
                  border: selected
                      ? null
                      : Border.all(color: AppColors.inkSoft, width: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

/// Etiqueta de enfoque de la tarea destacada.
class _TaskTag extends StatelessWidget {
  const _TaskTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: _accentBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.brandDark,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Fila de tarea: icono, título, detalle y acción a la derecha.
///
/// El título admite dos líneas, para que un nombre largo («Higiene de sueño
/// y descanso») no quede cortado junto al botón. Una tarea completada va con
/// el título tachado y apagado, igual que en el panel.
class _DiaryTaskRow extends StatelessWidget {
  const _DiaryTaskRow({
    required this.icon,
    required this.done,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final bool done;
  final String title;
  final Widget subtitle;

  /// Acción a la derecha. Es opcional: en modo real, donde no hay flujo para
  /// la acción, la fila se queda sin botón en vez de pintar uno muerto.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: done ? AppColors.brandSoft : AppColors.softFill,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: done ? _accentBorder : AppColors.border,
              ),
            ),
            child: Icon(icon, size: 20, color: AppColors.brand),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: done ? AppColors.textFaint : AppColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textFaint,
                  ),
                ),
                const SizedBox(height: 3),
                subtitle,
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Gráfica de la serenidad de la semana, dibujada a mano.
///
/// Cada elemento de [values] es el ánimo de un día, de 0 (mínima) a 1
/// (máxima); `null` = sin registro. Los días con dato llevan línea continua
/// con relleno y marcadores; los posteriores al último registro siguen en
/// punteado con círculos vacíos, como en la captura. Cada punto cae en el
/// centro de su columna, de modo que queda alineado con las etiquetas del
/// eje que van debajo.
class _MoodTrendPainter extends CustomPainter {
  const _MoodTrendPainter({required this.values});

  /// Serenidad por día de la semana (lunes a domingo).
  final List<double?> values;

  static const double _padding = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final conDato = <int>[
      for (var i = 0; i < values.length; i++)
        if (values[i] != null) i,
    ];
    if (conDato.isEmpty) return;

    final column = size.width / values.length;
    final baseline = size.height - _padding;
    final plot = baseline - _padding;
    double xAt(int index) => column * (index + 0.5);
    double yAt(double value) => _padding + (1 - value) * plot;

    final first = conDato.first;
    final last = conDato.last;

    // Guías horizontales punteadas: máximo y punto medio.
    final guide = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final level in const [1.0, 0.5]) {
      final path = Path()
        ..moveTo(0, yAt(level))
        ..lineTo(size.width, yAt(level));
      _drawDashed(canvas, path, guide);
    }

    // Línea y relleno solo por los días con registro.
    final line = Path()..moveTo(xAt(first), yAt(values[first]!));
    final area = Path()
      ..moveTo(xAt(first), baseline)
      ..lineTo(xAt(first), yAt(values[first]!));
    for (final i in conDato) {
      if (i == first) continue;
      line.lineTo(xAt(i), yAt(values[i]!));
      area.lineTo(xAt(i), yAt(values[i]!));
    }
    area
      ..lineTo(xAt(last), baseline)
      ..close();

    // Relleno bajo la línea, de verde translúcido a transparente.
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.brand.withValues(alpha: 0.22),
            AppColors.brand.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, _padding, size.width, plot)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.brand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Días posteriores al último registro: continuación punteada con círculos
    // vacíos.
    if (last < values.length - 1) {
      final projection = Path()
        ..moveTo(xAt(last), yAt(values[last]!))
        ..lineTo(xAt(values.length - 1), yAt(values[last]!));
      _drawDashed(
        canvas,
        projection,
        Paint()
          ..color = AppColors.brand.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = last + 1; i < values.length; i++) {
        final center = Offset(xAt(i), yAt(values[last]!));
        canvas.drawCircle(center, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          center,
          4.5,
          Paint()
            ..color = AppColors.textFaint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }

    // Marcadores de los días registrados y, más grande, el último.
    for (final i in conDato) {
      final center = Offset(xAt(i), yAt(values[i]!));
      if (i == last) {
        canvas.drawCircle(center, 7, Paint()..color = Colors.white);
        canvas.drawCircle(center, 5, Paint()..color = AppColors.brand);
        continue;
      }
      canvas.drawCircle(center, 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        4.5,
        Paint()
          ..color = AppColors.brand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_MoodTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

/// Dibuja un trazo punteado siguiendo [path]: tramos de [dash] separados por
/// huecos de [gap]. Material no trae líneas punteadas.
void _drawDashed(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 5,
  double gap = 4,
}) {
  for (final metric in path.computeMetrics()) {
    var start = 0.0;
    while (start < metric.length) {
      final end = start + dash < metric.length ? start + dash : metric.length;
      canvas.drawPath(metric.extractPath(start, end), paint);
      start = end + gap;
    }
  }
}
