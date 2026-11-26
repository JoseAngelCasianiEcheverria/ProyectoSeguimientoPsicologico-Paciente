import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'tests/instrumentos_test.dart';
import 'widgets.dart';

/// Aviso de confidencialidad del pie, tal como llega en la captura de diseño.
///
/// Es una afirmación legal (secreto profesional), así que, como el resto de
/// textos legales del proyecto, necesita verificación humana antes de
/// publicarse.
const String _kConfidentialityNotice =
    'Confidencialidad de datos psicométricos: uso clínico exclusivo bajo '
    'secreto profesional.';

/// Tiempo que queda para entregar la batería, como en la captura de diseño.
const String _kTimeLeft = 'Faltan 4h 15m';

/// Un cuestionario de la batería: el instrumento, las respuestas y el avance.
class _Questionnaire {
  _Questionnaire({
    required this.tabLabel,
    required this.name,
    required this.icon,
    required this.answers,
    this.instrumento,
    this.index = 0,
    this.done = false,
    this.disponible = true,
    this.asignado = false,
    this.descripcion,
  });

  /// Texto de la pestaña: «PHQ-9 (Depresión)».
  final String tabLabel;

  /// Nombre corto: «PHQ-9».
  final String name;

  final IconData icon;

  /// Ítems y opciones del catálogo clínico; `null` si el test no se conoce.
  final InstrumentoTest? instrumento;

  /// Índice de opción elegido por pregunta, o `null` si todavía no hay.
  final List<int?> answers;

  /// Pregunta que se muestra, empezando en 0.
  int index;

  /// Se marca al responder la última pregunta.
  bool done;

  /// `false` cuando la base trae el test pero la app no tiene sus ítems.
  final bool disponible;

  /// El psicólogo lo asignó como tarea; solo los asignados se habilitan.
  final bool asignado;

  /// Descripción del catálogo (`test_psicometrico.descripcion`), si la hay.
  final String? descripcion;

  int get total => instrumento?.total ?? 0;

  int get puntaje => instrumento?.puntajeTotal(answers) ?? 0;
}

/// Vista 8: Batería de Tests Pre-consulta.
///
/// En modo demo (la cuenta de Karen) muestra la captura: PHQ-9 y GAD-7 con
/// el avance de la maqueta y el contador «Faltan 4h 15m». En modo real el
/// catálogo sale de `test_psicometrico` (con `catalogoTests`), el límite se
/// calcula con `citaSiguiente` y el estado de cada test con
/// `evaluacionesPropias`. Solo se pueden abrir los tests que el psicólogo
/// asignó como tarea (`tareasPropias`); los demás se muestran deshabilitados.
/// Donde no hay dato se avisa en vez de inventarlo.
/// Completar un cuestionario guarda con `guardarEvaluacion`, igual que antes.
///
/// La pestaña activa, la respuesta elegida, el avance con «Anterior» y
/// «Siguiente» y la fila de la pregunta previa funcionan de verdad. El botón
/// de ayuda solo conserva el aspecto.
///
/// Arranca como la captura de diseño: PHQ-9, pregunta 3 de 9, con «Varios
/// días» marcado y las dos preguntas anteriores ya respondidas.
///
/// Los enunciados de los ítems son los de los cuestionarios estándar y, como
/// texto clínico, necesitan verificación humana antes de publicarse. El
/// ítem 9 de PHQ-9 pregunta por pensamientos de hacerse daño: cuando exista
/// el servicio, una respuesta distinta de «Para nada» debería avisar a la
/// terapeuta.
class PacienteTestsPage extends StatefulWidget {
  const PacienteTestsPage({super.key, this.auth, this.testInicial});

  final PacienteAuth? auth;

  /// Nombre del test que debe quedar abierto al entrar: lo manda la tarea
  /// «Completar test X» del panel del paciente.
  final String? testInicial;

  @override
  State<PacienteTestsPage> createState() => _PacienteTestsPageState();
}

class _PacienteTestsPageState extends State<PacienteTestsPage> {
  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  /// `true` mientras se decide el modo (demo o real) y se cargan los datos.
  bool _cargando = true;

  /// `true` si la sesión activa es la cuenta que ve los mockups.
  bool _demo = false;

  /// Cuestionarios de la pantalla. En modo demo son los de la captura; en
  /// modo real se reconstruyen desde el catálogo de la base.
  List<_Questionnaire> _tests = const [];

  /// Próxima cita, para el límite clínico en modo real.
  Map<String, dynamic>? _cita;
  Map<int, ({String nombre, String? avatarUrl})> _directorio = const {};

  int _tab = 0;

  /// Si la fila «Pregunta N previa» está desplegada.
  bool _showPrevious = false;

  _Questionnaire get _current => _tests[_tab];

  /// Los dos cuestionarios tal como llegan en la captura de diseño.
  List<_Questionnaire> _testsDemo() => <_Questionnaire>[
    _Questionnaire(
      tabLabel: '${phq9.nombre} (${phq9.dominio})',
      name: phq9.nombre,
      icon: Icons.psychology_outlined,
      instrumento: phq9,
      // Las dos primeras respuestas y la tercera son las de la captura.
      answers: <int?>[1, 1, 1, null, null, null, null, null, null],
      index: 2,
      asignado: true,
    ),
    _Questionnaire(
      tabLabel: '${gad7.nombre} (${gad7.dominio})',
      name: gad7.nombre,
      icon: Icons.air_rounded,
      instrumento: gad7,
      answers: List<int?>.filled(gad7.total, null),
      asignado: true,
    ),
  ];

  /// En modo demo no se consulta nada: la pantalla muestra la captura.
  /// En modo real se leen el catálogo, la próxima cita y las evaluaciones
  /// propias.
  Future<void> _cargarDatos() async {
    try {
      final esDemo = await _auth.esCuentaDemo();
      if (!mounted) return;
      if (esDemo) {
        final abierto = _tests.isEmpty ? '' : _tests[_tab].name;
        setState(() {
          _demo = true;
          _tests = _mantenerAvance(_testsDemo());
          _tab = _pestinaPara(_tests, abierto);
          _cargando = false;
        });
        return;
      }

      final resultados = await Future.wait<Object?>([
        _auth.catalogoTests(),
        _auth.citaSiguiente(),
        _auth.evaluacionesPropias(),
        _auth.tareasPropias(),
        _auth.directorioPsicologos(),
      ]);
      if (!mounted) return;
      final catalogo =
          (resultados[0] as List<Map<String, dynamic>>?) ?? const [];
      final cita = resultados[1] as Map<String, dynamic>?;
      final evaluaciones =
          (resultados[2] as List<Map<String, dynamic>>?) ?? const [];
      final tareas =
          (resultados[3] as List<Map<String, dynamic>>?) ?? const [];
      const prefijo = 'Completar test ';
      final asignados = <String>{};
      for (final tarea in tareas) {
        final texto = '${tarea['descripcion'] ?? ''}'.trim();
        if (!texto.startsWith(prefijo)) continue;
        final nombre = texto.substring(prefijo.length).trim();
        if (nombre.isNotEmpty) asignados.add(nombre.toLowerCase());
      }
      setState(() {
        _cita = cita;
        _directorio =
            resultados[4] as Map<int, ({String nombre, String? avatarUrl})>;
        // La pestaña abierta se sigue por nombre: el catálogo puede venir
        // en otro orden tras la actualización.
        final abierto = _tests.isEmpty ? '' : _tests[_tab].name;
        _tests = _mantenerAvance(
          _testsDesdeCatalogo(catalogo, evaluaciones, asignados),
        );
        _tab = _pestinaPara(_tests, abierto);
        _showPrevious = false;
        _cargando = false;
      });
    } catch (_) {
      // Sin sesión o sin configuración de base no hay catálogo: se queda el
      // modo real y la pantalla avisa.
      if (!mounted) return;
      setState(() {
        _tests = const [];
        _cargando = false;
      });
    }
  }

  /// Pestaña que se abre al cargar: la que pidió la tarea del panel, o la
  /// que ya estaba abierta en un refresco. Si el nombre no está en el
  /// catálogo (o no hay tests), cae a la primera.
  int _pestinaPara(List<_Questionnaire> tests, String abierto) {
    final pedido = widget.testInicial?.trim() ?? '';
    final nombre = pedido.isEmpty ? abierto : pedido;
    if (nombre.isEmpty) return 0;
    final i = tests.indexWhere(
      (test) => test.name.toLowerCase() == nombre.toLowerCase(),
    );
    return i < 0 ? 0 : i;
  }

  /// Copia el avance de la tanda anterior a la recién cargada, por nombre de
  /// test: deslizar para actualizar no debe borrar lo que ya se respondió.
  /// Un test marcado hecho se queda hecho aunque el catálogo cambie.
  List<_Questionnaire> _mantenerAvance(List<_Questionnaire> nuevos) {
    final anteriores = <String, _Questionnaire>{
      for (final test in _tests) test.name: test,
    };
    for (final test in nuevos) {
      final previo = anteriores[test.name];
      if (previo == null) continue;
      if (previo.answers.length == test.answers.length) {
        test.answers.setAll(0, previo.answers);
      }
      test.index =
          previo.index < test.answers.length ? previo.index : 0;
      test.done = test.done || previo.done;
    }
    return nuevos;
  }

  /// Catálogo real convertido en cuestionarios.
  ///
  /// Solo se habilitan los tests que el psicólogo asignó como tarea. Si el
  /// código del catálogo no corresponde a un instrumento conocido se muestra
  /// su nombre y descripción con un aviso, sin inventar preguntas.
  List<_Questionnaire> _testsDesdeCatalogo(
    List<Map<String, dynamic>> catalogo,
    List<Map<String, dynamic>> evaluaciones,
    Set<String> asignados,
  ) {
    final hechas = <String>{};
    for (final fila in evaluaciones) {
      if (fila['completado'] != true) continue;
      final test = fila['test_psicometrico'];
      final nombre = test is Map ? '${test['nombre'] ?? ''}'.trim() : '';
      if (nombre.isNotEmpty) hechas.add(nombre.toUpperCase());
    }

    final lista = <_Questionnaire>[];
    for (final fila in catalogo) {
      final nombre = '${fila['nombre'] ?? ''}'.trim();
      if (nombre.isEmpty) continue;
      final upper = nombre.toUpperCase();
      final instrumento = instrumentoPorCodigo('${fila['codigo'] ?? ''}'.trim()) ??
          instrumentoPorCodigo(upper);
      final asignado = asignados.contains(upper.toLowerCase());
      lista.add(
        _Questionnaire(
          tabLabel: instrumento == null
              ? nombre
              : '${instrumento.nombre} (${instrumento.dominio})',
          name: nombre,
          icon: instrumento?.codigo == 'PHQ-9'
              ? Icons.psychology_outlined
              : instrumento?.codigo == 'GAD-7'
                  ? Icons.air_rounded
                  : Icons.assignment_outlined,
          instrumento: instrumento,
          answers: List<int?>.filled(instrumento?.total ?? 0, null),
          done: hechas.contains(upper),
          asignado: asignado,
          disponible: instrumento != null && asignado,
          descripcion: '${fila['descripcion'] ?? ''}'.trim(),
        ),
      );
    }
    return lista;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  /// Aviso de que el flujo todavía no existe, en vez de un botón muerto.
  void _pending(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    setState(() {
      _tab = index;
      _showPrevious = false;
    });
  }

  void _answer(int value) {
    setState(() {
      _current.answers[_current.index] = value;
      _current.done = false;
    });
  }

  void _previous() {
    final test = _current;
    if (test.index == 0) return;
    setState(() {
      test.index--;
      _showPrevious = false;
    });
  }

  /// Avanza a la siguiente pregunta; en la última cierra el cuestionario y
  /// pasa al que falte, o termina la batería si ya no queda ninguno.
  Future<void> _next() async {
    final test = _current;
    if (test.answers[test.index] == null) return;

    if (test.index < test.total - 1) {
      setState(() {
        test.index++;
        _showPrevious = false;
      });
      return;
    }

    final instrumento = test.instrumento!;
    final score = instrumento.puntajeTotal(test.answers);
    if (!_demo) {
      final guardado = await _auth.guardarEvaluacion(
        nombreTest: test.name,
        puntajeTotal: score,
        respuestas: test.answers,
      );
      if (!mounted) return;
      if (!guardado) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo guardar el resultado. Inténtalo de nuevo.',
              ),
            ),
          );
        return;
      }
    }
    await _mostrarResultado(instrumento, score, test.answers);
    if (!mounted) return;
    setState(() => test.done = true);
    final messenger = ScaffoldMessenger.of(context);
    // Los tests sin ítems no se cuentan como pendientes de responder.
    final pending = _tests.indexWhere((t) => t.disponible && !t.done);
    if (pending != -1) {
      setState(() {
        _tab = pending;
        _showPrevious = false;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${test.name} completado. Continúa con ${_tests[pending].name}.',
            ),
          ),
        );
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Tests enviados. Tu terapeuta los revisará antes de la sesión.',
          ),
        ),
      );
    Navigator.of(context).maybePop();
  }

  Future<void> _mostrarResultado(
    InstrumentoTest instrumento,
    int puntaje,
    List<int?> respuestas,
  ) {
    final banda = instrumento.interpretar(puntaje);
    final revision = instrumento.requiereRevisionHumana(respuestas);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resultado de ${instrumento.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Puntaje: $puntaje / ${instrumento.maximo}'),
            const SizedBox(height: 8),
            Text(banda ?? 'Sin interpretación disponible.'),
            if (revision) ...[
              const SizedBox(height: 8),
              const Text(
                'Tu terapeuta revisará personalmente este resultado.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Catálogo vacío: no hay cuestionarios que mostrar.
    final sinTests = _tests.isEmpty;
    final test = sinTests ? null : _current;
    final disponible = test?.disponible ?? false;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              // Deslizar hacia abajo vuelve a leer catálogo, cita y
              // evaluaciones; el avance respondido se conserva por nombre
              // de test para que el gesto no borre lo ya contestado.
              child: RefreshIndicator(
                onRefresh: _cargarDatos,
                color: AppColors.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDeadline(),
                      const SizedBox(height: 16),
                      if (sinTests) ...[
                        AvisoVacio(
                          texto: 'Aún no hay tests disponibles.',
                          t: PanelTokens.light(),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        _buildTabs(),
                        const SizedBox(height: 16),
                        if (disponible) ...[
                          _buildProgress(test!),
                          const SizedBox(height: 16),
                          _buildQuestion(test),
                          if (test.index > 0) ...[
                            const SizedBox(height: 16),
                            _buildPrevious(test),
                          ],
                        ] else ...[
                          _buildUnavailable(test!),
                        ],
                        const SizedBox(height: 16),
                      ],
                      _buildSpecialist(),
                      const SizedBox(height: 16),
                      const PrivacyNotice(
                        text: _kConfidentialityNotice,
                        background: AppColors.softFill,
                        icon: Icons.lock_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (disponible) _buildActionBar(test!),
          ],
        ),
      ),
    );
  }

  // --- Cabecera ----------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'MINDJORA',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Batería de Tests',
                  style: AppText.wordmark.copyWith(
                    color: AppColors.ink,
                    fontSize: 18,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          SquareIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'Ayuda',
            onPressed: () =>
                _pending('La ayuda de los tests todavía no está disponible.'),
          ),
        ],
      ),
    );
  }

  // --- Límite clínico ------------------------------------------------------

  /// En modo demo, el contador «Faltan 4h 15m» de la captura. En modo real,
  /// la fecha de la próxima cita; sin cita se avisa en vez de contar hacia
  /// una sesión que no existe.
  Widget _buildDeadline() {
    if (!_demo) return _buildDeadlineReal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 17,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'LÍMITE CLÍNICO',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _TimePill(label: _kTimeLeft),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Debe completarse al menos 2 horas antes de tu sesión. El '
                  'resultado será confidencial y analizado previamente por tu '
                  'terapeuta.',
                  style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Límite en modo real: la próxima cita de `citaSiguiente`.
  Widget _buildDeadlineReal() {
    final tokens = PanelTokens.light();
    final cita = _cita;
    if (cita == null) {
      return AvisoVacio(
        texto: 'Aún no tienes una sesión programada.',
        t: tokens,
      );
    }

    final fecha = DateTime.tryParse('${cita['fecha_hora']}');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 17,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'LÍMITE CLÍNICO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TimePill(
                      label: fecha == null
                          ? 'Fecha por confirmar'
                          : _formatoSesion(fecha),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Debe completarse al menos 2 horas antes de tu sesión. El '
                  'resultado será confidencial y analizado previamente por tu '
                  'terapeuta.',
                  style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fecha y hora de la cita en local, «dd/MM HH:mm».
  static String _formatoSesion(DateTime f) {
    final d = f.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  // --- Pestañas -------------------------------------------------------------

  Widget _buildTabs() {
    return Row(
      children: [
        for (var i = 0; i < _tests.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _TestTab(
              label: _tests[i].tabLabel,
              icon: _tests[i].icon,
              selected: i == _tab,
              done: _tests[i].done,
              onTap: () => _selectTab(i),
            ),
          ),
        ],
      ],
    );
  }

  // --- Avance ---------------------------------------------------------------

  Widget _buildProgress(_Questionnaire test) {
    final ratio = (test.index + 1) / test.total;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CUESTIONARIO ${test.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Pregunta ${test.index + 1} de ${test.total}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Pregunta -------------------------------------------------------------

  Widget _buildQuestion(_Questionnaire test) {
    final instrumento = test.instrumento!;
    final selected = test.answers[test.index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ítem ${test.index + 1}',
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            instrumento.instruccion,
            style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Text(
            instrumento.items[test.index].texto,
            style: AppText.panelHeading.copyWith(
              color: AppColors.ink,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          for (final opcion in instrumento.opciones) ...[
            if (opcion.valor > 0) const SizedBox(height: 8),
            _OptionTile(
              value: opcion.valor,
              label: opcion.etiqueta,
              selected: selected == opcion.valor,
              onTap: () => _answer(opcion.valor),
            ),
          ],
        ],
      ),
    );
  }

  /// Fila «Pregunta N previa (Completada)»; desplegada, muestra qué se
  /// preguntó y qué se respondió.
  Widget _buildPrevious(_Questionnaire test) {
    final previousIndex = test.index - 1;
    final answer = test.answers[previousIndex];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => setState(() => _showPrevious = !_showPrevious),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pregunta ${previousIndex + 1} previa (Completada)',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    _showPrevious
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
          if (_showPrevious)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    test.instrumento!.items[previousIndex].texto,
                    style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    answer == null
                        ? 'Sin respuesta'
                        : 'Tu respuesta: ${test.instrumento!.opciones[answer].etiqueta}',
                    style: const TextStyle(
                      color: AppColors.brandDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Test que la base conoce pero la app todavía no puede preguntar: se
  /// muestra su nombre y descripción con un aviso, sin inventar ítems.
  Widget _buildUnavailable(_Questionnaire test) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            test.name,
            style: AppText.panelHeading.copyWith(
              color: AppColors.ink,
              fontSize: 18,
              height: 1.35,
            ),
          ),
          if (test.descripcion != null && test.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              test.descripcion!,
              style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 12),
          AvisoVacio(
            texto: test.asignado
                ? 'Este test aún no está disponible en la app.'
                : 'Tu psicólogo aún no ha asignado este test.',
            t: PanelTokens.light(),
          ),
        ],
      ),
    );
  }

  // --- Terapeuta ------------------------------------------------------------

  /// En modo demo, la doctora de la captura. En modo real el nombre del
  /// profesional no se expone (bloqueo 6.1), así que se avisa.
  Widget _buildSpecialist() {
    if (!_demo) return _buildSpecialistReal();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // La foto de la captura no existe como asset del proyecto: se
          // resuelve con las iniciales, igual que en el panel.
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'YC',
              style: AppText.wordmark.copyWith(
                color: AppColors.brandDark,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dra. Yani Casiani',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Psicóloga Clínica asignada',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 15,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }

  /// Terapeuta en modo real: nombre y foto del directorio de psicólogos.
  Widget _buildSpecialistReal() {
    final id = int.tryParse('${_cita?['id_psicologo'] ?? ''}');
    final psi = id == null ? null : _directorio[id];
    final nombre = psi?.nombre ?? 'Nombre del profesional no disponible.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          FotoPerfil(
            iniciales: inicialesDe(nombre),
            url: psi?.avatarUrl,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: TextStyle(
                color: psi == null ? AppColors.inkSoft : AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Barra inferior -------------------------------------------------------

  Widget _buildActionBar(_Questionnaire test) {
    final isLast = test.index == test.total - 1;
    final hasAnswer = test.answers[test.index] != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: SoftButton(
                  label: 'Anterior',
                  icon: Icons.arrow_back_rounded,
                  onPressed: test.index == 0 ? null : _previous,
                  backgroundColor: AppColors.chipBg,
                  foregroundColor: AppColors.ink,
                  borderColor: AppColors.border,
                  minHeight: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: isLast ? 'Finalizar cuestionario' : 'Siguiente Pregunta',
                  icon: isLast
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: hasAnswer ? _next : null,
                  minHeight: 48,
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

/// Píldora blanca con el tiempo que queda: «Faltan 4h 15m».
class _TimePill extends StatelessWidget {
  const _TimePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Pestaña de un cuestionario: marcada en verde cuando es la activa, y con una
/// marca de verificación cuando ya está completado.
class _TestTab extends StatelessWidget {
  const _TestTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.done,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandSoft : AppColors.chipBg,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                done ? Icons.check_circle_rounded : icon,
                size: 16,
                color: selected ? AppColors.brandDark : AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.brandDark : AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// Una opción de respuesta: número, texto y casilla; la elegida se pinta en
/// verde.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '$value, $label',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.brandSoft : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.soft),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(
                color: selected ? AppColors.brand : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.brand : AppColors.chipBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? AppColors.brand : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.brandDark : AppColors.ink,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.brand : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? AppColors.brand : AppColors.border,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
