import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'paciente_detalle_sesion.dart';
import 'paciente_diario.dart';
import 'paciente_inicio.dart';
import 'paciente_notificaciones.dart';
import 'paciente_perfil.dart';
import 'widgets.dart';

/// La captura es maqueta: lo que todavía no tiene flujo conserva el aspecto.
void _noop() {}

/// Vista: especialistas verificados del paciente.
///
/// Directorio con buscador, modalidad, especialidad, fecha y hora. El buscador
/// filtra de verdad (por nombre, motivo o enfoque) y las horas se pueden elegir;
/// la modalidad y la especialidad mueven su selección. En modo real la tira de
/// fechas se arma con los días que el psicólogo dejó libres en su herramienta
/// de horarios semanales (tabla `disponibilidad`) y elegir un día reescribe las
/// horas de cada tarjeta: cada hora lleva su `id_disponibilidad`, así que la
/// reserva sale del día que se está mirando. La cuenta demo sigue viendo los
/// mockups de la captura. El botón de filtros y el convenio son solo aspecto;
/// la campana abre las notificaciones.
/// «Reservar Cita» abre el detalle de la sesión con la hora elegida; si no hay
/// hora elegida, avisa en vez de abrirlo.
class PacienteAgendaPage extends StatefulWidget {
  const PacienteAgendaPage({super.key, this.auth, this.initialDateIndex = 1});

  /// Servicio de datos. Permite inyectar un doble en las pruebas; si es
  /// `null` se crea uno y la pantalla decide entre mockups y datos reales.
  final PacienteAuth? auth;

  /// MAR 25: el día que llega seleccionado en el diseño (solo modo demo).
  final int initialDateIndex;

  @override
  State<PacienteAgendaPage> createState() => _PacienteAgendaPageState();
}

class _PacienteAgendaPageState extends State<PacienteAgendaPage> {
  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  /// `true` mientras se decide el modo y se carga el catálogo real.
  bool _cargando = true;

  /// `true` para la cuenta demo (ve las dos tarjetas de la captura).
  bool _demo = false;

  /// Catálogo real de `psicologo` + su disponibilidad de `disponibilidad`.
  List<_Specialist> _reales = const [];

  /// Días con espacios libres, en orden cronológico (solo modo real).
  List<DateTime> _dias = const [];

  /// Horas de cada especialista por día (`yyyy-MM-dd`) con su
  /// `id_disponibilidad` y duración: la tarjeta solo muestra las del día
  /// elegido y la reserva viaja con los datos reales de ese hueco.
  final Map<
    String,
    Map<String, List<({String hora, int id, int? duracionMinutos})>>
  >
  _horarios =
      <
        String,
        Map<String, List<({String hora, int id, int? duracionMinutos})>>
      >{};

  /// Índice de [_dias] marcado en la tira real.
  int _diaReal = 0;

  final TextEditingController _query = TextEditingController();

  /// «Online (Videollamada)», con lo que abre la vista.
  int _modality = 0;

  /// «Ansiedad y Estrés», la especialidad marcada en el diseño.
  int _specialty = 1;

  late int _date = widget.initialDateIndex;

  /// Hora elegida por tarjeta, indexada por [_Specialist.id].
  final Map<String, String> _slots = <String, String>{};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Solo la cuenta demo ve los mockups. Cualquier otra cuenta consulta
  /// `psicologo` y `disponibilidad` en Supabase y muestra los profesionales
  /// guardados en la base (o el aviso de vacío).
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

      final filas = await _auth.catalogoPsicologos();
      final directorio = await _auth.directorioPsicologos();
      final resultado = <_Specialist>[];
      final mapa =
          <
            String,
            Map<String, List<({String hora, int id, int? duracionMinutos})>>
          >{};
      final dias = <String, DateTime>{};
      for (final fila in filas) {
        final id = _comoEntero(fila['id_psicologo']) ?? 0;
        final psi = directorio[id];
        final nombre = psi?.nombre.isEmpty ?? true
            ? 'Profesional #$id'
            : psi!.nombre;
        final disponibilidad = await _auth.disponibilidadDe(id);
        final tarifa = _comoEntero(fila['tarifa_base']) ?? 0;
        final tarifaTexto = tarifa > 0
            ? r'$' + tarifa.toString()
            : 'Tarifa no informada';
        final porDia =
            <String, List<({String hora, int id, int? duracionMinutos})>>{};
        final horas = <String>[];
        for (final hueco in disponibilidad) {
          final inicio = DateTime.tryParse('${hueco['fecha_hora_inicio']}');
          if (inicio == null) continue;
          final fin = DateTime.tryParse('${hueco['fecha_hora_fin']}');
          final duracion = fin?.difference(inicio).inMinutes;
          // La hora es la hora de pared del psicólogo (la base guarda UTC y
          // el portal la escribe igual), así que se lee tal cual.
          final hora =
              '${inicio.hour.toString().padLeft(2, '0')}:'
              '${inicio.minute.toString().padLeft(2, '0')}';
          final dia = DateTime(inicio.year, inicio.month, inicio.day);
          final clave = _claveDia(dia);
          (porDia[clave] ??= <({String hora, int id, int? duracionMinutos})>[])
              .add((
                hora: hora,
                id: _comoEntero(hueco['id_disponibilidad']) ?? 0,
                duracionMinutos: duracion != null && duracion > 0
                    ? duracion
                    : null,
              ));
          dias[clave] = dia;
          if (!horas.contains(hora)) horas.add(hora);
        }
        mapa['psicologo-$id'] = porDia;
        resultado.add(
          _Specialist(
            id: 'psicologo-$id',
            idPsicologo: id,
            name: nombre,
            initials: psi == null ? 'P$id' : inicialesDe(nombre),
            avatarUrl: psi?.avatarUrl,
            role: 'Psicólogo/a de la base',
            experience: '',
            rating: '',
            reviews: '',
            approach: fila['es_independiente'] == true
                ? 'Profesional independiente'
                : 'Convenio empresa',
            approachIcon: Icons.badge_outlined,
            tags: const <String>[],
            extraTags: 0,
            sessionDate: nombre,
            slotsTitle: 'Disponibilidad registrada:',
            slotsNote: horas.isEmpty ? 'Sin horarios' : 'Horarios reales',
            slotsIcon: Icons.schedule_rounded,
            slots: horas,
            price: tarifaTexto,
            tarifaBase: tarifa > 0 ? tarifa : null,
            approx: '',
          ),
        );
      }
      if (!mounted) return;
      final fechas = dias.values.toList()..sort();
      setState(() {
        _reales = resultado;
        _horarios
          ..clear()
          ..addAll(mapa);
        _dias = fechas;
        _diaReal = 0;
        _slots.clear();
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  static int? _comoEntero(Object? valor) => switch (valor) {
    int() => valor,
    num() => valor.toInt(),
    String() => int.tryParse(valor) ?? double.tryParse(valor)?.toInt(),
    _ => null,
  };

  /// Tarjetas que casan con la búsqueda (sobre los datos del modo activo).
  List<_Specialist> get _results {
    final origen = _demo ? _kSpecialists : _reales;
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return origen;
    return origen.where((s) => s.haystack.contains(q)).toList();
  }

  void _pickSlot(_Specialist specialist, String slot) {
    setState(() {
      if (_slots[specialist.id] == slot) {
        _slots.remove(specialist.id);
      } else {
        _slots[specialist.id] = slot;
      }
    });
  }

  /// Clave estable de un día para mirarlo en [_horarios].
  static String _claveDia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Día marcado en la tira real (null si ningún profesional dejó huecos).
  DateTime? get _diaElegido => _dias.isEmpty ? null : _dias[_diaReal];

  /// Horas de la tarjeta para el día elegido; la captura usa sus literales.
  List<({String hora, int id, int? duracionMinutos})> _horasDe(
    _Specialist specialist,
  ) {
    final dia = _diaElegido;
    if (_demo || dia == null || specialist.idPsicologo == null) return const [];
    return _horarios[specialist.id]?[_claveDia(dia)] ?? const [];
  }

  /// Id real de `disponibilidad` de la hora elegida, del día elegido (modo
  /// real). Elegir otro día vacía la hora elegida, así que el id siempre
  /// corresponde a lo que se está mirando.
  int? _idSlot(_Specialist specialist) {
    if (specialist.idPsicologo == null) return null;
    final slot = _slots[specialist.id];
    if (slot == null) return null;
    for (final hueco in _horasDe(specialist)) {
      if (hueco.hora == slot) return hueco.id;
    }
    return null;
  }

  /// Duración en minutos calculada a partir del hueco elegido.
  int? _duracionSlot(_Specialist specialist) {
    if (specialist.idPsicologo == null) return null;
    final slot = _slots[specialist.id];
    if (slot == null) return null;
    for (final hueco in _horasDe(specialist)) {
      if (hueco.hora == slot) return hueco.duracionMinutos;
    }
    return null;
  }

  /// Fecha del día elegido como la lee «Detalle de Sesión».
  String _fechaLarga(DateTime dia) =>
      '${_kWeekdays[dia.weekday - 1]} ${dia.day} de ${_kMonths[dia.month - 1]}';

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final results = _results;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              // Deslizar hacia abajo vuelve a consultar el catálogo y la
              // disponibilidad; el `AlwaysScrollable` permite el gesto
              // aunque la lista quepa en pantalla.
              child: RefreshIndicator(
                onRefresh: _cargar,
                color: AppColors.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 22),
                        _buildEyebrow(),
                        const SizedBox(height: 14),
                        _buildTitleBlock(),
                        const SizedBox(height: 16),
                        _buildSearch(),
                        const SizedBox(height: 12),
                        _buildModality(),
                        const SizedBox(height: 12),
                        // En modo real no hay especialidades de la captura (la
                        // tabla `psicologo` no tiene esa columna); la tira de
                        // fechas sí existe, pero con los días que tienen huecos.
                        if (_demo) ...[
                          _buildSpecialties(),
                          const SizedBox(height: 22),
                          _buildDates(),
                        ] else ...[
                          _buildRealNotice(),
                          const SizedBox(height: 14),
                          _buildRealDates(),
                        ],
                        const SizedBox(height: 14),
                        ..._buildResults(results),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            PanelBottomNav(
              selectedIndex: 1,
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
                'Especialistas',
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
          badgeColor: AppColors.dayActive,
        ),
        const SizedBox(width: 9),
        SquareIconButton(
          icon: Icons.person_outline_rounded,
          tooltip: 'Mi perfil',
          onPressed: _noop,
        ),
      ],
    );
  }

  /// «CUIDADO CLÍNICO» con el contador de disponibles a la derecha.
  ///
  /// Solo el contador es `Flexible`: con dos hijos flexibles Flutter les parte
  /// el espacio a mitades y la píldora se recorta. Así el rótulo se queda con
  /// su ancho natural y la píldora cede si no cabe.
  Widget _buildEyebrow() {
    return Row(
      children: [
        const Text(
          'CUIDADO CLÍNICO',
          style: TextStyle(
            color: AppColors.brand,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(child: _availabilityPill()),
      ],
    );
  }

  /// Aviso en modo real: el catálogo trae los profesionales guardados en la
  /// base, pero el nombre vive en `usuario` y el paciente no puede leerlo
  /// (bloqueo 6.1). Se muestra el id hasta que exista el RPC del catálogo.
  Widget _buildRealNotice() {
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
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.inkSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Catálogo real de la base, con el nombre y la foto del '
              'directorio de psicólogos.',
              style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  /// Contador de especialistas del encabezado.
  Widget _availabilityPill() {
    // En demo se conserva el literal de la captura; en real sale el conteo real.
    final texto = _demo
        ? '24 especialistas disponibles'
        : '${_reales.length} especialistas disponibles';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.dayActive,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              texto,
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
    );
  }

  Widget _buildTitleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Especialistas verificados',
          style: AppText.display.copyWith(color: AppColors.ink, fontSize: 26),
        ),
        const SizedBox(height: 8),
        Text(
          'Encuentra un espacio seguro guiado por profesionales con '
          'experiencia clínica certificada.',
          style: AppText.body.copyWith(
            color: AppColors.inkSoft,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // --- Buscador, modalidad y especialidad --------------------------------

  Widget _buildSearch() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 19, color: AppColors.inkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppColors.ink, fontSize: 13.5),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Buscar por nombre, motivo o enfoque...',
                hintStyle: TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: _noop,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.tune_rounded, size: 19, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModality() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _kModalities.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _ModalitySegment(
                modality: _kModalities[i],
                selected: _modality == i,
                onTap: () => setState(() => _modality = i),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecialties() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < _kSpecialties.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _SpecialtyChip(
              label: _kSpecialties[i],
              selected: _specialty == i,
              onTap: () => setState(() => _specialty = i),
            ),
          ],
        ],
      ),
    );
  }

  // --- Tira de fechas ----------------------------------------------------

  /// Tira de fechas en modo real: los días en los que al menos un profesional
  /// dejó huecos libres. Solo esos días se pueden tocar; elegir uno reescribe
  /// las horas de cada tarjeta.
  Widget _buildRealDates() {
    if (_dias.isEmpty) {
      return const AvisoVacio(
        texto: 'Ningún profesional tiene horarios libres por ahora.',
      );
    }
    final elegido = _dias[_diaReal];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Seleccionar fecha preferida',
          color: AppColors.ink,
          trailing: Text(
            '${_kMonths[elegido.month - 1]} ${elegido.year}',
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < _dias.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _DayCard(
                  day: _DayOption(
                    _kWeekdayShort[_dias[i].weekday - 1],
                    _dias[i].day.toString().padLeft(2, '0'),
                    hasSlots: true,
                  ),
                  selected: i == _diaReal,
                  onTap: () => setState(() {
                    _diaReal = i;
                    // La hora elegida era de otro día: no puede viajar con
                    // el id_disponibilidad del día anterior.
                    _slots.clear();
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelSectionHeading(
          title: 'Seleccionar fecha preferida',
          color: AppColors.ink,
          trailing: const Text(
            'Septiembre 2026',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < _kDays.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _DayCard(
                  day: _kDays[i],
                  selected: i == _date,
                  onTap: () => setState(() => _date = i),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- Tarjetas ----------------------------------------------------------

  List<Widget> _buildResults(List<_Specialist> specialists) {
    if (specialists.isEmpty) {
      if (!_demo && _reales.isEmpty) {
        return [
          AvisoVacio(
            texto: 'No hay profesionales registrados en la base de datos.',
          ),
          const SizedBox(height: 12),
        ];
      }
      return [
        _EmptyState(query: _query.text, onReset: _clearQuery),
        const SizedBox(height: 12),
      ];
    }
    return [
      for (var i = 0; i < specialists.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _cardFor(specialists[i]),
      ],
    ];
  }

  /// Tarjeta con las horas del día elegido (modo real) o con sus literales
  /// de la captura (demo). El título también nombra el día elegido.
  Widget _cardFor(_Specialist specialist) {
    var slots = specialist.slots;
    var title = specialist.slotsTitle;
    var note = specialist.slotsNote;
    if (!_demo) {
      final dia = _diaElegido;
      slots = [for (final hueco in _horasDe(specialist)) hueco.hora];
      title = dia == null
          ? 'Sin día seleccionado:'
          : 'Disponibilidad ${_kWeekdayShort[dia.weekday - 1]} '
                '${dia.day}:';
      note = slots.isEmpty ? 'Sin horarios' : 'Horarios reales';
    }
    return _SpecialistCard(
      specialist: specialist,
      slots: slots,
      slotsTitle: title,
      slotsNote: note,
      selectedSlot: _slots[specialist.id],
      onSlotSelected: (slot) => _pickSlot(specialist, slot),
      onReserve: () => _reserve(specialist),
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

  /// Abre «Detalle de Sesión» con la hora elegida en la tarjeta. Sin hora no
  /// hay nada que reservar: se avisa en vez de abrirlo. Al volver recarga para
  /// que un horario recien tomado deje de ofrecerse.
  Future<void> _reserve(_Specialist specialist) async {
    final slot = _slots[specialist.id];
    if (slot == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Elige una hora para reservar tu cita.'),
          ),
        );
      return;
    }
    if (!_demo &&
        specialist.idPsicologo != null &&
        _idSlot(specialist) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Ese horario ya no está disponible. Elige otro.'),
          ),
        );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PacienteDetalleSesionPage(
          auth: _auth,
          reserva: SesionReserva(
            specialistName: specialist.name,
            initials: specialist.initials,
            avatarUrl: specialist.avatarUrl,
            role: specialist.role,
            rating: specialist.rating,
            reviews: specialist.reviews,
            focus: specialist.tags.isEmpty ? 'General' : specialist.tags.first,
            dateLabel: _demo || _diaElegido == null
                ? specialist.sessionDate
                : _fechaLarga(_diaElegido!),
            startTime: slot,
            idPsicologo: _demo ? null : specialist.idPsicologo,
            idDisponibilidad: _demo ? null : _idSlot(specialist),
            modalidad: _modality == 0 ? 'VIDEO' : 'PRESENCIAL',
            tarifa: _demo ? null : specialist.tarifaBase,
            duracionMinutos: _demo ? null : _duracionSlot(specialist),
          ),
        ),
      ),
    );
    if (mounted && !_demo) await _cargar();
  }

  void _clearQuery() {
    _query.clear();
    setState(() {});
  }

  /// «Inicio» devuelve al panel del paciente. «Agenda» es esta misma pantalla y
  /// «Diario» y «Perfil» sustituyen esta pantalla en vez de apilarse sobre ella.
  /// Tocar la propia pestaña «Agenda» no hace nada: el toque va, pero la vista
  /// no cambia.
  ///
  /// Se deshace **un** empuje, no todos: volver con `popUntil(isFirst)`
  /// acabaría en el login, que es la primera ruta cuando se entra desde ahí.
  void _openTab(int index) {
    if (index == 2) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PacienteDiarioPage()),
      );
      return;
    }
    if (index == 3) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PacientePerfilPage()),
      );
      return;
    }
    if (index != 0) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const PacienteInicioPage()),
    );
  }
}

// --- Datos de muestra ------------------------------------------------------

/// Modalidades de la atención.
const _kModalities = <({String label, IconData icon})>[
  (label: 'En línea (Videollamada)', icon: Icons.videocam_outlined),
  (label: 'Presencial', icon: Icons.place_outlined),
];

/// Especialidades del filtro horizontal.
const _kSpecialties = <String>[
  'Todos',
  'Ansiedad y Estrés',
  'TCC',
  'Autoestima',
  'Depresión',
];

/// Un día de la tira de fechas. [hasSlots] dibuja el punto de disponibilidad.
class _DayOption {
  const _DayOption(this.weekday, this.day, {this.hasSlots = false});

  final String weekday;
  final String day;
  final bool hasSlots;
}

/// Días de la semana en tres letras para la tira (empezando en lunes).
const _kWeekdayShort = <String>[
  'LUN',
  'MAR',
  'MIÉ',
  'JUE',
  'VIE',
  'SÁB',
  'DOM',
];

/// Días de la semana en largo, para la fecha que lee «Detalle de Sesión».
const _kWeekdays = <String>[
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Meses en largo: el encabezado de la tira y la fecha del detalle.
const _kMonths = <String>[
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Fechas de septiembre de 2026 que muestra la captura.
const _kDays = <_DayOption>[
  _DayOption('LUN', '24', hasSlots: true),
  _DayOption('MAR', '25', hasSlots: true),
  _DayOption('MIÉ', '26', hasSlots: true),
  _DayOption('JUE', '27'),
  _DayOption('VIE', '28'),
  _DayOption('SÁB', '29'),
];

/// Una tarjeta del directorio.
class _Specialist {
  const _Specialist({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
    required this.experience,
    required this.rating,
    required this.reviews,
    required this.approach,
    required this.approachIcon,
    required this.tags,
    required this.extraTags,
    required this.sessionDate,
    required this.slotsTitle,
    required this.slotsNote,
    required this.slotsIcon,
    required this.slots,
    required this.price,
    required this.approx,
    this.idPsicologo,
    this.tarifaBase,
    this.avatarUrl,
  });

  /// Identificador estable: la hora elegida se guarda por [id], no por posición.
  final String id;

  /// Id real en `psicologo` (null en las tarjetas de la captura).
  final int? idPsicologo;

  /// Tarifa base real de la base (null en la captura).
  final int? tarifaBase;

  /// Ruta pública de la foto del profesional (null si no tiene).
  final String? avatarUrl;
  final String name;
  final String initials;
  final String role;
  final String experience;
  final String rating;
  final String reviews;

  /// Distintivo bajo el nombre: convenio o enfoque.
  final String approach;
  final IconData approachIcon;

  /// Etiquetas visibles; [extraTags] son las que van plegadas tras «+N más».
  final List<String> tags;
  final int extraTags;

  /// «Disponibilidad hoy (Mar 25):» y su nota de la derecha.
  final String slotsTitle;
  final String slotsNote;

  /// Día de la sesión tal como se lee en «Detalle de Sesión».
  final String sessionDate;
  final IconData slotsIcon;
  final List<String> slots;

  /// «$40 Mil COP» y el aproximado que va debajo.
  final String price;
  final String approx;

  /// Texto por el que busca el buscador: nombre, rol, enfoque, etiquetas
  /// y horas disponibles (para que el filtro también sirva con datos reales).
  String get haystack =>
      '$name $role $approach ${tags.join(' ')} ${slots.join(' ')}'
          .toLowerCase();
}

/// Las dos tarjetas de la captura de diseño.
const _kSpecialists = <_Specialist>[
  _Specialist(
    id: 'yani-casiani',
    name: 'Dra. Yani Casiani',
    initials: 'YC',
    role: 'Psicóloga Clínica Sanitaria',
    experience: '8 años exp.',
    rating: '4.9',
    reviews: '128',
    approach: 'Convenio Empresa Disponible',
    approachIcon: Icons.apartment_rounded,
    tags: <String>['TCC', 'Mindfulness', 'Ansiedad'],
    extraTags: 2,
    sessionDate: 'Martes 25 de Octubre',
    slotsTitle: 'Disponibilidad hoy (Mar 25):',
    slotsNote: 'Zona horaria local',
    slotsIcon: Icons.schedule_rounded,
    slots: <String>['16:00', '18:30', '20:00'],
    price: '\$40 Mil COP',
    approx: '\$45.000 COP aprox.',
  ),
  _Specialist(
    id: 'oscar-flerez',
    name: 'Lic. Oscar Flerez',
    initials: 'OF',
    role: 'Psicoterapeuta Integrativo',
    experience: '6 años exp.',
    rating: '4.8',
    reviews: '94',
    approach: 'Enfoque Contextual y ACT',
    approachIcon: Icons.lightbulb_outline_rounded,
    tags: <String>['Humanista', 'Terapia de Aceptación', 'Depresión'],
    extraTags: 0,
    sessionDate: 'Miércoles 26 de Octubre',
    slotsTitle: 'Disponibilidad mañana (Mié 26):',
    slotsNote: 'Sesión 50 min',
    slotsIcon: Icons.calendar_today_rounded,
    slots: <String>['10:00', '15:30'],
    price: '\$30 Mil COP',
    approx: '\$42.000 COP aprox.',
  ),
];

// --- Piezas de la pantalla -------------------------------------------------

/// Media banda de modalidad: la elegida va en blanco sobre la gris.
class _ModalitySegment extends StatelessWidget {
  const _ModalitySegment({
    required this.modality,
    required this.selected,
    required this.onTap,
  });

  final ({String label, IconData icon}) modality;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(
              color: selected ? AppColors.border : Colors.transparent,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                modality.icon,
                size: 17,
                color: selected ? AppColors.ink : AppColors.inkSoft,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  modality.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(
                    color: selected ? AppColors.ink : AppColors.inkSoft,
                    fontSize: 13,
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

/// Chip de especialidad; el elegido va en verde con su marca de verificación.
class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.body.copyWith(
                  color: selected ? Colors.white : AppColors.ink,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Día de la tira: día de la semana, número y punto si tiene horarios.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final _DayOption day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.dayActive : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.soft),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.soft),
            border: Border.all(
              color: selected ? AppColors.dayActive : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                day.weekday,
                style: AppText.body.copyWith(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                day.day,
                style: AppText.body.copyWith(
                  color: selected ? Colors.white : AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              // Punto de disponibilidad: hueco reservado aunque no haya
              // horarios, para que los días queden alineados.
              SizedBox(
                height: 5,
                child: day.hasSlots
                    ? Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : AppColors.dot,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de un especialista: quién es, su distintivo, cuándo y cuánto.
///
/// Las horas y su rótulo vienen de fuera: en modo real son las del día elegido
/// en la tira, así que cambiar de día reescribe este bloque sin reconstruir la
/// tarjeta.
class _SpecialistCard extends StatelessWidget {
  const _SpecialistCard({
    required this.specialist,
    required this.slots,
    required this.slotsTitle,
    required this.slotsNote,
    required this.selectedSlot,
    required this.onSlotSelected,
    required this.onReserve,
  });

  final _Specialist specialist;
  final List<String> slots;
  final String slotsTitle;
  final String slotsNote;
  final String? selectedSlot;
  final ValueChanged<String> onSlotSelected;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildTags(),
          const SizedBox(height: 14),
          _buildAvailability(),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          _buildPrice(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VerifiedAvatar(
          initials: specialist.initials,
          url: specialist.avatarUrl,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      specialist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.wordmark.copyWith(
                        color: AppColors.ink,
                        fontSize: 16,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                  const SizedBox(width: 3),
                  Text(
                    specialist.rating,
                    style: AppText.body.copyWith(
                      color: AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '(${specialist.reviews})',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textFaint,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${specialist.role} • ${specialist.experience}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: AppColors.inkSoft,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: SoftButton(
                  label: specialist.approach,
                  icon: specialist.approachIcon,
                  onPressed: _noop,
                  backgroundColor: AppColors.softFill,
                  foregroundColor: AppColors.ink,
                  borderColor: AppColors.border,
                  minWidth: 0,
                  minHeight: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final tag in specialist.tags) _TagChip(label: tag),
        if (specialist.extraTags > 0)
          _TagChip(label: '+${specialist.extraTags} más', filled: true),
      ],
    );
  }

  /// Bloque gris con el día de los horarios, su nota y las horas elegibles.
  Widget _buildAvailability() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(specialist.slotsIcon, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slotsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: AppColors.ink,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                slotsNote,
                style: AppText.body.copyWith(
                  color: AppColors.brand,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (slots.isEmpty)
            Text(
              'Este día no tiene horas libres.',
              style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
            )
          else
            Row(
              children: [
                for (var i = 0; i < slots.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _SlotButton(
                      label: slots[i],
                      selected: selectedSlot == slots[i],
                      onTap: () => onSlotSelected(slots[i]),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPrice() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    specialist.price,
                    style: AppText.body.copyWith(
                      color: AppColors.ink,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '/ sesión',
                    style: AppText.body.copyWith(
                      color: AppColors.inkSoft,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                specialist.approx,
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textFaint,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 168,
          child: PrimaryButton(
            label: 'Reservar Cita',
            icon: Icons.arrow_forward_rounded,
            onPressed: onReserve,
            minHeight: 46,
          ),
        ),
      ],
    );
  }
}

/// Foto del especialista con el distintivo de verificado.
/// La captura trae fotografías que el proyecto todavía no tiene, así que se
/// resuelven con sus iniciales hasta que lleguen los assets.
class _VerifiedAvatar extends StatelessWidget {
  const _VerifiedAvatar({required this.initials, this.url});

  final String initials;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FotoPerfil(
            iniciales: initials,
            url: url,
            size: 58,
            radius: AppRadius.soft,
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de enfoque: «TCC», «Depresión». La última, «+2 más», va rellena.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, this.filled = false});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? AppColors.chipBg : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppText.body.copyWith(
          color: AppColors.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Hora elegible; la elegida se pinta en verde de marca.
class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandDark : AppColors.ink;
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.brandSoft : Colors.white,
          foregroundColor: color,
          side: BorderSide(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.soft),
          ),
        ),
        // La tinta va en el `Text` y no solo en `foregroundColor` para que la
        // elección se pueda leer desde fuera, igual que los chips y los días.
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ).copyWith(color: color),
        ),
      ),
    );
  }
}

/// Estado sin resultados del buscador.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.onReset});

  final String query;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 26,
            color: AppColors.inkSoft,
          ),
          const SizedBox(height: 10),
          Text(
            'Sin especialistas',
            style: AppText.body.copyWith(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            query.trim().isEmpty
                ? 'Ajusta los filtros para ver profesionales.'
                : 'Ningún especialista coincide con «${query.trim()}».',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(
              color: AppColors.inkSoft,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SoftButton(
            label: 'Limpiar búsqueda',
            onPressed: onReset,
            backgroundColor: AppColors.softFill,
            foregroundColor: AppColors.brand,
            borderColor: AppColors.border,
            minWidth: 0,
            minHeight: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            fontSize: 12.5,
          ),
        ],
      ),
    );
  }
}
