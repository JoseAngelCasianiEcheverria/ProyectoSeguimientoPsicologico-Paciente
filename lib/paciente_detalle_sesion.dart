import 'dart:async';

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'widgets.dart';

/// La captura es maqueta: lo que todavía no tiene flujo conserva el aspecto.
void _noop() {}

/// Duración de una consulta, en minutos.
const int _kSessionMinutes = 50;

/// Suma [minutes] a una hora «HH:MM» y la devuelve con el mismo formato.
String _addMinutes(String hhmm, int minutes) {
  final parts = hhmm.split(':');
  final total = int.parse(parts[0]) * 60 + int.parse(parts[1]) + minutes;
  final hours = (total ~/ 60) % 24;
  final mins = total % 60;
  return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
}

/// Pesos colombianos con punto de miles: `60000` → «$60.000 COP».
String _cop(int value) {
  final digits = value.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}\$$grouped COP';
}

/// Lo que se reserva: quién atiende y cuándo.
///
/// La agenda lo arma con la tarjeta del especialista y la hora elegida.
class SesionReserva {
  const SesionReserva({
    required this.specialistName,
    required this.initials,
    required this.role,
    required this.rating,
    required this.reviews,
    required this.focus,
    required this.dateLabel,
    required this.startTime,
    this.avatarUrl,
    this.idPsicologo,
    this.idDisponibilidad,
    this.modalidad = 'PRESENCIAL',
    this.tarifa,
    this.duracionMinutos,
  });

  /// La reserva de la captura de diseño: la Dra. Casiani, hoy a las 18:30.
  static const SesionReserva captura = SesionReserva(
    specialistName: 'Dra. Yani Casiani',
    initials: 'YC',
    role: 'Psicóloga Clínica Sanitaria',
    rating: '4.9',
    reviews: '128',
    focus: 'TCC',
    dateLabel: 'Martes 25 de Octubre',
    startTime: '18:30',
  );

  final String specialistName;
  final String initials;
  final String role;
  final String rating;
  final String reviews;

  /// Enfoque principal, en la etiqueta de la tarjeta: «TCC».
  final String focus;

  /// «Martes 25 de Octubre».
  final String dateLabel;

  /// Hora de inicio, «18:30».
  final String startTime;

  /// Foto del profesional, si la hay.
  final String? avatarUrl;

  /// Tarifa base real del profesional, leida de `psicologo.tarifa_base`.
  final int? tarifa;

  /// Duración calculada entre fecha_hora_inicio y fecha_hora_fin (en minutos).
  final int? duracionMinutos;

  /// Ids reales de `psicologo` y `disponibilidad` (null en la captura).
  /// Cuando ambos están puestos, «Confirmar» llama a `reservar_slot`.
  final int? idPsicologo;
  final int? idDisponibilidad;

  /// Modalidad que espera el RPC: PRESENCIAL, TELECONSULTA o VIDEO.
  final String modalidad;

  /// `true` si esta reserva viene de la base y debe reservarse de verdad.
  bool get esReal => idPsicologo != null && idDisponibilidad != null;

  /// «18:30 - 19:20».
  String get timeRange =>
      '$startTime - ${_addMinutes(startTime, _kSessionMinutes)}';
}

/// Vista: detalle de la sesión que se está reservando.
///
/// Se abre desde «Reservar Cita» del directorio de especialistas. Resume al
/// profesional y el horario, el beneficio corporativo con el desglose del
/// cobro, el método de respaldo y los requisitos antes de confirmar.
///
/// Mantienen estado el contador del bloqueo de horario (cuenta atrás real:
/// al llegar a cero la reserva vence y no se puede confirmar), el interruptor
/// del beneficio (apagado, se cobra la tarifa completa) y el método de
/// respaldo elegido. Las tarifas son las de la captura de diseño.
class PacienteDetalleSesionPage extends StatefulWidget {
  const PacienteDetalleSesionPage({
    super.key,
    this.reserva = SesionReserva.captura,
    this.auth,
  });

  final SesionReserva reserva;

  /// Servicio de datos para reservar de verdad; en la captura no se usa.
  final PacienteAuth? auth;

  @override
  State<PacienteDetalleSesionPage> createState() =>
      _PacienteDetalleSesionPageState();
}

class _PacienteDetalleSesionPageState extends State<PacienteDetalleSesionPage> {
  /// «09:44»: lo que marca el contador en la captura.
  static const int _holdSeconds = 9 * 60 + 44;

  /// Tarifa base de la consulta de 50 minutos.
  static const int _baseFee = 60000;

  late int _remaining = _holdSeconds;
  Timer? _timer;

  /// El beneficio llega aplicado, como en el diseño.
  bool _benefit = true;

  /// «Tarjeta Crédito / Débito» llega marcada.
  int _method = 0;

  bool get _expired => _remaining <= 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining > 0 ? _remaining - 1 : 0;
        if (_remaining == 0) _timer?.cancel();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  bool _reservando = false;

  /// Confirma la cita. En la captura solo avisa; si la reserva viene de la
  /// base, llama al RPC `reservar_slot` y solo vuelve a la agenda si la
  /// base creó la cita (nunca finge éxito).
  Future<void> _confirm() async {
    if (_reservando) return;
    final reserva = widget.reserva;
    if (!reserva.esReal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Cita confirmada: ${reserva.dateLabel}, ${reserva.startTime} hrs.',
            ),
          ),
        );
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _reservando = true);
    final cita = await _auth.reservarSlot(
      idPsicologo: reserva.idPsicologo!,
      idDisponibilidad: reserva.idDisponibilidad!,
      modalidad: reserva.modalidad,
    );
    if (!mounted) return;
    setState(() => _reservando = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            cita == null
                ? (_auth.errorReserva ??
                      'No se pudo reservar la cita. El horario puede estar tomado.')
                : 'Cita reservada: ${reserva.dateLabel}, '
                      '${reserva.startTime} hrs.',
          ),
        ),
      );
    if (cita != null) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final reserva = widget.reserva;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 18),
                _buildHoldBanner(),
                const SizedBox(height: 14),
                _buildSpecialist(reserva),
                const SizedBox(height: 14),
                if (!reserva.esReal) ...[
                  _buildBenefit(),
                  const SizedBox(height: 14),
                  _buildPaymentMethod(),
                  const SizedBox(height: 14),
                ] else
                  _buildTarifaReal(reserva),
                _buildRequirements(),
                const SizedBox(height: 16),
                _buildConfirm(),
                const SizedBox(height: 14),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Cabecera ----------------------------------------------------------

  Widget _buildTopBar() {
    return Row(
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Detalle de Sesión',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.wordmark.copyWith(
                  color: AppColors.ink,
                  fontSize: 19,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SquareIconButton(
          icon: Icons.person_outline_rounded,
          tooltip: 'Mi perfil',
          onPressed: _noop,
          size: 44,
        ),
      ],
    );
  }

  // --- Bloqueo de horario ------------------------------------------------

  /// «Bloqueo atómico de slot activo» con la cuenta atrás a la derecha. Al
  /// vencer cambia el texto y el contador pasa a «Vencido».
  Widget _buildHoldBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 22, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _expired
                      ? 'Bloqueo de horario vencido'
                      : 'Bloqueo atómico de slot activo',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _expired
                      ? 'Vuelve a la agenda para elegir otra hora'
                      : 'Tu horario reservado está asegurado',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.soft),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expired
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 17,
                  color: _expired ? AppColors.error : AppColors.brandDark,
                ),
                const SizedBox(width: 7),
                Text(
                  _expired ? 'Vencido' : _countdown,
                  style: TextStyle(
                    color: _expired ? AppColors.error : AppColors.brandDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Profesional y horario --------------------------------------------

  Widget _buildSpecialist(SesionReserva reserva) {
    return _SesionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(initials: reserva.initials, url: reserva.avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            reserva.specialistName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.display.copyWith(
                              color: AppColors.ink,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _FocusTag(label: reserva.focus),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reserva.role,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: AppColors.star,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reserva.rating,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '(${reserva.reviews} valoraciones)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 19,
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${reserva.dateLabel} • ${reserva.timeRange} hrs',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      size: 19,
                      color: AppColors.inkSoft,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppText.sessionEncryptionNote,
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Unico dato economico real: la tarifa del profesional elegido. El resto
  /// del desglose de la captura (beneficio, subsidio, copago) no existe en la
  /// base y en modo real no se muestra.
  Widget _buildTarifaReal(SesionReserva reserva) {
    return _SesionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _IconBox(icon: Icons.receipt_long_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tarifa de la consulta',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AmountRow(
            label: reserva.duracionMinutos != null
                ? 'Tarifa base consulta (${reserva.duracionMinutos} min)'
                : 'Tarifa base consulta',
            value: reserva.tarifa == null
                ? 'No informada'
                : _cop(reserva.tarifa!),
          ),
        ],
      ),
    );
  }

  // --- Beneficio corporativo y desglose del cobro ------------------------

  Widget _buildBenefit() {
    final subsidy = _benefit ? _baseFee : 0;
    final total = _baseFee - subsidy;

    return _SesionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _IconBox(icon: Icons.apartment_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _benefit
                          ? 'Beneficio Corporativo Activo'
                          : 'Beneficio Corporativo Pausado',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'InnovaTech S.A.',
                      style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              appSwitch(
                value: _benefit,
                onChanged: (value) => setState(() => _benefit = value),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    _benefit
                        ? Icons.star_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 21,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _benefit
                            ? '2 de 4 sesiones gratuitas restantes este mes'
                            : 'Beneficio sin aplicar a esta sesión',
                        style: const TextStyle(
                          color: AppColors.brandDark,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _benefit
                            ? 'Cubierto al 100% por el plan de bienestar '
                                  'integral de tu empresa.'
                            : 'Pagarás la tarifa base completa. Puedes '
                                  'reactivarlo cuando quieras.',
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          _AmountRow(
            label: 'Tarifa base consulta (50 min)',
            value: _cop(_baseFee),
          ),
          if (_benefit) ...[
            const SizedBox(height: 14),
            _AmountRow(
              icon: Icons.card_giftcard_rounded,
              label: 'Subsidio InnovaTech (100%)',
              value: _cop(-subsidy),
              highlighted: true,
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total a facturar hoy',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _benefit
                          ? 'Copago \$0 garantizado'
                          : 'Sin beneficio aplicado',
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _cop(total),
                    maxLines: 1,
                    style: TextStyle(
                      color: _benefit ? AppColors.brand : AppColors.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Método de respaldo ------------------------------------------------

  Widget _buildPaymentMethod() {
    return _SesionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Método de respaldo o copago',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(AppRadius.soft),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'OPCIONAL',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _kMethods.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _MethodTile(
              method: _kMethods[i],
              selected: _method == i,
              onTap: () => setState(() => _method = i),
            ),
          ],
        ],
      ),
    );
  }

  // --- Requisitos --------------------------------------------------------

  Widget _buildRequirements() {
    const body = TextStyle(color: AppColors.inkSoft, fontSize: 14, height: 1.5);
    const strong = TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700);

    return _SesionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBox(icon: Icons.verified_user_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'Requisito clínico obligatorio',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      const TextSpan(
                        style: body,
                        children: [
                          TextSpan(
                            text:
                                'Deberás completar tu test psicométrico '
                                'confidencial (',
                          ),
                          TextSpan(text: 'PHQ-9', style: strong),
                          TextSpan(text: ' / '),
                          TextSpan(text: 'GAD-7', style: strong),
                          TextSpan(text: ') hasta '),
                          TextSpan(text: '2 horas antes', style: strong),
                          TextSpan(
                            text:
                                ' de la cita para habilitar el enlace '
                                'seguro de acceso a la sala virtual.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(AppRadius.field),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.event_available_outlined,
                    size: 20,
                    color: AppColors.inkSoft,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: AppText.cancellationPolicyTitle,
                          style: strong,
                        ),
                        TextSpan(text: AppText.cancellationPolicyBody),
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

  // --- Confirmación y pie ------------------------------------------------

  /// «Confirmar y Congelar Cita», con el candado a la izquierda como en el
  /// diseño. Si el bloqueo venció, queda deshabilitado.
  Widget _buildConfirm() {
    return FilledButton(
      onPressed: _expired || _reservando ? null : _confirm,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 20),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Confirmar y Congelar Cita',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return CustomPaint(
      painter: const DashedBorderPainter(
        fill: AppColors.canvas,
        stroke: AppColors.border,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Text(
          AppText.bookingTerms,
          textAlign: TextAlign.center,
          style: AppText.footer.copyWith(
            color: AppColors.inkSoft,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

// --- Datos de muestra ------------------------------------------------------

/// Métodos de respaldo del copago.
const List<({IconData icon, String title, String subtitle})> _kMethods =
    <({IconData icon, String title, String subtitle})>[
      (
        icon: Icons.credit_card_outlined,
        title: 'Tarjeta Crédito / Débito',
        subtitle: 'Visa o Mastercard vinculada',
      ),
      (
        icon: Icons.account_balance_outlined,
        title: 'PSE • Transferencia directa',
        subtitle: 'Bancos colombianos y Nequi/Daviplata',
      ),
      (
        icon: Icons.smartphone_rounded,
        title: 'Billetera Digital',
        subtitle: 'Apple Pay • Google Pay',
      ),
    ];

// --- Piezas de la pantalla -------------------------------------------------

/// Tarjeta blanca con borde: bloque base del detalle.
class _SesionCard extends StatelessWidget {
  const _SesionCard({required this.child});

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

/// Cuadro con un icono: el edificio del convenio, el escudo del requisito, y
/// cada método de respaldo.
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, size: size * 0.5, color: AppColors.inkSoft),
    );
  }
}

/// Foto del profesional con la insignia de verificado. La captura trae una
/// fotografía que el proyecto todavía no tiene, así que se resuelve con las
/// iniciales hasta que llegue el asset.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.url});

  final String initials;
  final String? url;

  static const double _size = 80;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FotoPerfil(
              iniciales: initials,
              url: url,
              size: _size,
              radius: AppRadius.field,
            ),
          ),
          Positioned(
            right: -6,
            bottom: -8,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 17,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de enfoque de la tarjeta del profesional: «TCC».
class _FocusTag extends StatelessWidget {
  const _FocusTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.soft),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Fila del desglose: concepto a la izquierda e importe a la derecha. La del
/// subsidio va en verde y con su icono.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.icon,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final labelColor = highlighted ? AppColors.brand : AppColors.inkSoft;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19, color: AppColors.brand),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 14.5),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: TextStyle(
            color: highlighted ? AppColors.brand : AppColors.ink,
            fontSize: 14.5,
            fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Opción de método de respaldo; la elegida lleva el borde verde y el punto.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, String title, String subtitle}) method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _IconBox(icon: method.icon, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.subtitle,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador de opción: círculo vacío o con el punto de marca.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.dot,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
