import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'paciente_sala.dart';
import 'paciente_tests.dart';
import 'widgets.dart';

/// Rojo apagado de la alerta prioritaria (borde, etiqueta e icono).
///
/// Sale de la captura de diseño y no está en [AppColors]; se deja local, como
/// el verde de estado de la sala.
const Color _kAlert = Color(0xFF83483B);

/// Fondo rosado de la tarjeta de alerta prioritaria.
const Color _kAlertBg = Color(0xFFF6EFEC);

/// Pestañas del filtro. «Todas» muestra todo; las demás, solo los avisos que
/// llevan esa categoría.
enum _Tab { todas, urgencias, citas, tests }

const Map<_Tab, String> _kTabLabels = <_Tab, String>{
  _Tab.todas: 'Todas',
  _Tab.urgencias: 'Urgencias',
  _Tab.citas: 'Citas',
  _Tab.tests: 'Tests',
};

/// Bloque de la lista en el que cae cada aviso.
enum _Group { priority, today, earlier }

/// Los cinco avisos de la captura. Cada uno se dibuja con su propio
/// constructor (`_buildNotice`), porque su contenido y sus acciones difieren.
enum _Kind { inasistencia, preconsulta, cita, animo, permisos }

/// Un aviso: dónde se muestra, en qué pestañas cuenta y si llega sin leer.
class _Notice {
  const _Notice({
    required this.kind,
    required this.group,
    required this.tabs,
    this.unread = false,
    this.id,
  });

  /// Id de la cita de la que deriva el aviso (solo en modo real).
  final Object? id;

  final _Kind kind;
  final _Group group;

  /// Categorías del aviso (sin «Todas», que las incluye todas). Con estas
  /// categorías los contadores de la captura salen de los datos: 5 / 1 / 2 / 2.
  final Set<_Tab> tabs;

  /// Llega sin leer: lleva el punto hasta que se marca como leído.
  final bool unread;
}

const List<_Notice> _kNotices = <_Notice>[
  _Notice(
    kind: _Kind.inasistencia,
    group: _Group.priority,
    tabs: {_Tab.urgencias, _Tab.citas},
    unread: true,
  ),
  _Notice(kind: _Kind.preconsulta, group: _Group.today, tabs: {_Tab.tests}),
  _Notice(
    kind: _Kind.cita,
    group: _Group.today,
    tabs: {_Tab.citas},
    unread: true,
  ),
  _Notice(kind: _Kind.animo, group: _Group.earlier, tabs: {_Tab.tests}),
  _Notice(kind: _Kind.permisos, group: _Group.earlier, tabs: {}),
];

/// Vista 18: Centro de Notificaciones y Alertas Push.
///
/// Historial de avisos del paciente: una alerta prioritaria arriba y el resto
/// agrupado en «Hoy» y «Ayer y anteriores», con un filtro por pestañas.
///
/// Mantienen estado las pestañas (filtran de verdad y sus contadores salen de
/// los datos) y los avisos sin leer: «Marcar leídas» y el botón de check de la
/// cabecera apagan los puntos. «Completar Test» y la fila de la sesión en línea
/// abren las vistas que ya existen; el resto de acciones («Contactar
/// Paciente», «Ver Protocolo», el filtro avanzado y las preferencias de
/// alerta) avisan de que el flujo todavía no existe. Los datos y los textos son
/// los de la captura de diseño, también los nombres que no coinciden con el
/// resto de la app.
class PacienteNotificacionesPage extends StatefulWidget {
  const PacienteNotificacionesPage({super.key, this.auth});

  final PacienteAuth? auth;

  @override
  State<PacienteNotificacionesPage> createState() =>
      _PacienteNotificacionesPageState();
}

class _PacienteNotificacionesPageState
    extends State<PacienteNotificacionesPage> {
  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  bool _cargando = true;
  bool _demo = false;

  /// Notificaciones derivadas de las citas reales del paciente.
  List<_Notice> _reales = const [];

  /// Texto de cada aviso real (la captura lo tiene fijo en el widget).
  final Map<_Kind, String> _textosReales = <_Kind, String>{};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// No existe tabla `notificacion`: los avisos reales se derivan del
  /// estado de las citas propias (`PENDIENTE`, `CONFIRMADA`, etc.).
  Future<void> _cargar() async {
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
      final citas = await _auth.citasPropias();
      final avisos = <_Notice>[];
      final textos = <_Kind, String>{};
      for (final cita in citas) {
        final estado = '${cita['estado_cita'] ?? ''}';
        final fecha = DateTime.tryParse('${cita['fecha_hora']}');
        final cuando = fecha == null
            ? 'fecha por confirmar'
            : '${fecha.day}/${fecha.month} ${fecha.hour.toString().padLeft(2, '0')}:'
                '${fecha.minute.toString().padLeft(2, '0')}';
        final kind = switch (estado) {
          'CANCELADA' => _Kind.inasistencia,
          'PENDIENTE' => _Kind.preconsulta,
          _ => _Kind.cita,
        };
        final titulo = switch (estado) {
          'CANCELADA' => 'Cita cancelada',
          'PENDIENTE' => 'Cita pendiente de confirmar',
          'CONFIRMADA' => 'Cita confirmada',
          'COMPLETADA' => 'Sesión completada',
          _ => 'Cita: $estado',
        };
        final tab = switch (estado) {
          'PENDIENTE' => _Tab.tests,
          'CANCELADA' => _Tab.urgencias,
          _ => _Tab.citas,
        };
        // Cada cita necesita su propia clave: se usa el id para el texto y
        // el kind para el icono/color del aviso.
        final idCita = cita['id_cita'];
        textos[kind] = '$titulo • $cuando';
        avisos.add(
          _Notice(
            kind: kind,
            group: _Group.today,
            tabs: <_Tab>{tab},
            unread: false,
            id: idCita is int ? idCita : null,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _reales = avisos;
        _textosReales
          ..clear()
          ..addAll(textos);
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  _Tab _tab = _Tab.todas;

  /// Avisos que siguen sin leer; arranca con los que la captura marca con punto.
  final Set<_Kind> _unread = <_Kind>{
    for (final notice in _kNotices)
      if (notice.unread) notice.kind,
  };

  bool _matches(_Notice notice, _Tab tab) =>
      tab == _Tab.todas || notice.tabs.contains(tab);

  List<_Notice> get _avisos => _demo ? _kNotices : _reales;

  int _count(_Tab tab) => _avisos.where((n) => _matches(n, tab)).length;

  void _markAllRead() => setState(_unread.clear);

  /// Aviso de que el flujo todavía no existe, en vez de un botón muerto.
  void _pending(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openTests() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PacienteTestsPage()),
    );
  }

  void _openRoom() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PacienteSalaPage(auth: _auth)),
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

    final visible = <_Notice>[
      for (final notice in _avisos)
        if (_matches(notice, _tab)) notice,
    ];
    final priority = visible.where((n) => n.group == _Group.priority);
    final today = visible.where((n) => n.group == _Group.today).toList();
    final earlier = visible.where((n) => n.group == _Group.earlier).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              // Deslizar hacia abajo vuelve a consultar las citas y sus
              // avisos; el `AlwaysScrollable` permite el gesto aunque la
              // lista quepa en pantalla.
              child: RefreshIndicator(
                onRefresh: _cargar,
                color: AppColors.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildTabs(),
                      const SizedBox(height: 20),
                      for (final notice in priority) ...[
                        _buildNotice(notice.kind),
                        const SizedBox(height: 20),
                      ],
                      if (today.isNotEmpty) ..._buildGroup('HOY', today),
                      if (earlier.isNotEmpty)
                        ..._buildGroup('AYER Y ANTERIORES', earlier),
                      if (visible.isEmpty) const _EmptyState(),
                      const SizedBox(height: 4),
                      _buildChannels(),
                    ],
                  ),
                ),
              ),
            ),
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
        color: AppColors.canvas,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 12),
          const BrandLogo(size: 28, radius: 6),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Centro De Notificaciones',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.wordmark.copyWith(
                    color: AppColors.ink,
                    fontSize: 15,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Mindjora • Salud Mental',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SquareIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filtrar notificaciones',
            size: 36,
            onPressed: () => _pending(
              'Los filtros avanzados todavía no están disponibles.',
            ),
          ),
          const SizedBox(width: 8),
          SquareIconButton(
            icon: Icons.check_rounded,
            tooltip: 'Marcar todo como leído',
            size: 36,
            onPressed: _unread.isEmpty ? null : _markAllRead,
          ),
        ],
      ),
    );
  }

  // --- Título y filtro -----------------------------------------------------

  Widget _buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notificaciones y Alertas',
                style: AppText.display.copyWith(
                  color: AppColors.ink,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Historial de avisos clínicos, recordatorios y alertas '
                'prioritarias.',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SoftButton(
          label: 'Marcar leídas',
          icon: Icons.check_rounded,
          onPressed: _unread.isEmpty ? null : _markAllRead,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          borderColor: AppColors.border,
          minWidth: 0,
          minHeight: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          fontSize: 12,
        ),
      ],
    );
  }

  /// Las pestañas se desplazan de lado: la última queda cortada en la captura.
  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _Tab.values) ...[
            if (tab != _Tab.todas) const SizedBox(width: 6),
            _FilterTab(
              label: _kTabLabels[tab]!,
              count: _count(tab),
              selected: tab == _tab,
              urgent: tab == _Tab.urgencias,
              onTap: () => setState(() => _tab = tab),
            ),
          ],
        ],
      ),
    );
  }

  // --- Lista de avisos ---------------------------------------------------

  /// Título del bloque («HOY», «AYER Y ANTERIORES») y sus avisos.
  List<Widget> _buildGroup(String label, List<_Notice> items) {
    final count = items.length;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          Text(
            '$count ${count == 1 ? 'aviso' : 'avisos'}',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 11),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Divider(height: 1, thickness: 1, color: AppColors.border),
      const SizedBox(height: 12),
      for (final notice in items) ...[
        _buildNotice(notice.kind),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 8),
    ];
  }

  /// Aviso derivado de una cita real: solo muestra lo que hay en la base.
  Widget _buildRealNotice(_Notice notice) {
    final texto = _textosReales[notice.kind] ?? 'Cita registrada';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 20, color: AppColors.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: AppText.body.copyWith(
                color: AppColors.ink,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(_Kind kind) {
    if (!_demo) {
      final aviso = _avisos.firstWhere(
        (n) => n.kind == kind,
        orElse: () => const _Notice(
          kind: _Kind.cita,
          group: _Group.today,
          tabs: <_Tab>{_Tab.citas},
        ),
      );
      return _buildRealNotice(aviso);
    }
    return switch (kind) {
      _Kind.inasistencia => _buildAlert(),
      _Kind.preconsulta => _buildPreConsulta(),
      _Kind.cita => _buildCita(),
      _Kind.animo => _buildAnimo(),
      _Kind.permisos => _buildPermisos(),
    };
  }

  /// Alerta prioritaria: tarjeta rosada con sus dos acciones.
  Widget _buildAlert() {
    final unread = _unread.contains(_Kind.inasistencia);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kAlertBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _kAlertBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _kAlert),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unread) ...[
                        const _Dot(color: _kAlert),
                        const SizedBox(width: 8),
                      ],
                      const Flexible(
                        child: Text(
                          'ALERTA PRIORITARIA • INASISTENCIA',
                          style: TextStyle(
                            color: _kAlert,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Hace 25 min',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBox(
                icon: Icons.warning_amber_rounded,
                background: Colors.white,
                borderColor: _kAlert,
                iconColor: _kAlert,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inasistencia a sesión programada',
                      style: AppText.panelHeading.copyWith(
                        color: AppColors.ink,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _RichBody(
                      'El paciente no ingresó a la sala tras **15 minutos** '
                      'de inicio. Protocolo de contingencia **OPER 1** '
                      'activado. Se notificó al acompañante **Oscar F.**',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 176,
                child: SoftButton(
                  label: 'Contactar Paciente',
                  icon: Icons.call_outlined,
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  borderColor: AppColors.brand,
                  minWidth: 0,
                  minHeight: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  fontSize: 12.5,
                  onPressed: () => _pending(
                    'Contactar al paciente todavía no está disponible.',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 140,
                child: SoftButton(
                  label: 'Ver Protocolo',
                  icon: Icons.description_outlined,
                  backgroundColor: AppColors.chipBg,
                  foregroundColor: AppColors.ink,
                  borderColor: AppColors.border,
                  minWidth: 0,
                  minHeight: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  fontSize: 12.5,
                  onPressed: () => _pending(
                    'El protocolo de contingencia todavía no está disponible.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreConsulta() {
    return _NoticeCard(
      icon: Icons.menu_book_outlined,
      category: 'PRE-CONSULTA',
      highlighted: true,
      time: 'Hace 1 hora',
      title: 'Evaluación Pre-consulta pendiente',
      body:
          'Faltan **2h 15m** para tu sesión con Dra. Camila Rivas. Completa '
          'los cuestionarios **PHQ-9** y **GAD-7** para habilitar la sala '
          'virtual.',
      extra: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 15, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: const Text(
              'Est. 4 min',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 142,
            child: PrimaryButton(
              label: 'Completar Test',
              icon: Icons.arrow_forward_rounded,
              minHeight: 44,
              onPressed: _openTests,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCita() {
    return _NoticeCard(
      icon: Icons.calendar_today_outlined,
      category: 'CITA CONFIRMADA',
      highlighted: true,
      unread: _unread.contains(_Kind.cita),
      time: 'Hace 3 horas',
      title: 'Cita confirmada con subsidio 100%',
      body:
          'El acompañante **Oscar Flerez** confirmó su vinculación en nivel '
          '**OPER 1** (Notificaciones operativas).',
      extra: _LinkTile(
        icon: Icons.videocam_outlined,
        label: 'Sesión en Línea Mindjora Rooms',
        onTap: _openRoom,
      ),
    );
  }

  Widget _buildAnimo() {
    return const _NoticeCard(
      icon: Icons.sentiment_satisfied_alt_outlined,
      category: 'BIENESTAR DIARIO',
      time: 'Ayer, 20:00 hrs',
      title: 'Recordatorio: Check-in de ánimo',
      body:
          'Has completado **4 días** seguidos de registro anímico. Tómate 1 '
          'minuto para registrar tu sensación actual.',
      extra: Align(alignment: Alignment.centerLeft, child: _StreakChip()),
    );
  }

  Widget _buildPermisos() {
    return const _NoticeCard(
      icon: Icons.shield_outlined,
      category: 'SEGURIDAD Y RED',
      time: 'Hace 2 días',
      title: 'Actualización en Matriz de Permisos',
      body:
          'El acompañante **Rodrigo Valenzuela** confirmó su vinculación en '
          'nivel **OPER 1** (Notificaciones operativas).',
    );
  }

  // --- Canales activos ---------------------------------------------------

  /// Aviso punteado del pie: canales activos y enlace a las preferencias.
  Widget _buildChannels() {
    return CustomPaint(
      painter: const DashedBorderPainter(
        fill: Colors.white,
        stroke: AppColors.border,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _IconBox(icon: Icons.tune_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _RichBody(
                    'Canales activos: **Push en app, WhatsApp** '
                    'recordatorios y **Email**.',
                    fontSize: 12,
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _pending(
                      'Las preferencias de alerta todavía no están '
                      'disponibles.',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Configurar preferencias de alerta',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.brand,
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
      ),
    );
  }
}

// --- Piezas de la pantalla -------------------------------------------------

/// Pestaña del filtro con su contador. La activa va en verde de marca; el
/// contador de «Urgencias» se pinta con el rojo de la alerta.
class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.urgent,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countColor = selected
        ? Colors.white
        : (urgent ? _kAlert : AppColors.inkSoft);
    return Material(
      color: selected ? AppColors.brand : AppColors.chipBg,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandDark : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: countColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

/// Tarjeta blanca de un aviso: icono, categoría, hora, título, texto y, si la
/// lleva, una acción debajo.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.category,
    required this.time,
    required this.title,
    required this.body,
    this.highlighted = false,
    this.unread = false,
    this.extra,
  });

  final IconData icon;
  final String category;
  final String time;
  final String title;

  /// Texto con partes en negrita marcadas con `**`.
  final String body;

  /// Categoría en verde de marca («PRE-CONSULTA», «CITA CONFIRMADA») en vez
  /// del gris de las demás.
  final bool highlighted;

  /// Punto verde delante de la categoría.
  final bool unread;

  /// Acción o detalle bajo el texto.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (unread) ...[
                      const _Dot(color: AppColors.brand),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: highlighted
                              ? AppColors.brand
                              : AppColors.inkSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: AppText.panelHeading.copyWith(
                    color: AppColors.ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                _RichBody(body),
                if (extra != null) ...[const SizedBox(height: 12), extra!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuadro con icono a la izquierda de cada aviso y del aviso de canales.
class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    this.background = AppColors.chipBg,
    this.borderColor = AppColors.border,
    this.iconColor = AppColors.inkSoft,
  });

  final IconData icon;
  final Color background;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, size: 17, color: iconColor),
    );
  }
}

/// Texto con partes en negrita: lo que va entre `**` se pinta más oscuro.
class _RichBody extends StatelessWidget {
  const _RichBody(this.text, {this.fontSize = 13});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: AppColors.inkSoft,
          fontSize: fontSize,
          height: 1.5,
        ),
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Punto de «sin leer».
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Fila pulsable bajo un aviso: «Sesión en Línea Mindjora Rooms».
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chipBg,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip «Racha de 4 días» del recordatorio de ánimo.
class _StreakChip extends StatelessWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            size: 14,
            color: AppColors.inkSoft,
          ),
          SizedBox(width: 6),
          Text(
            'Racha de 4 días',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista vacía: ninguna notificación cae en la pestaña elegida.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No hay avisos en esta categoría.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
      ),
    );
  }
}
