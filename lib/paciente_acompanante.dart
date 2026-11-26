import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'widgets.dart';

/// Portal restringido de acompañantes.
///
/// Esta vista conserva la separación OPER 1 / OPER 2. En modo real carga
/// los datos del paciente, el acompañante vinculado y la próxima cita mediante
/// [Future.wait]. Si no hay acompañante, paciente o cita, muestra [AvisoVacio].
class PacienteAcompanantePage extends StatefulWidget {
  const PacienteAcompanantePage({super.key, this.auth});

  final PacienteAuth? auth;

  @override
  State<PacienteAcompanantePage> createState() =>
      _PacienteAcompanantePageState();
}

class _PacienteAcompanantePageState extends State<PacienteAcompanantePage> {
  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  bool _cargando = true;
  bool _demo = false;
  String? _error;

  ({
    String nombre,
    String correo,
    bool requiereAcompanante,
    String documento,
    String telefono,
    String direccion,
  })?
  _datosPaciente;
  Map<String, dynamic>? _acompanante;
  Map<String, dynamic>? _cita;
  Map<int, ({String nombre, String? avatarUrl})> _directorio = const {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

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

      final resultados = await Future.wait<Object?>([
        _auth.datosPaciente(),
        _auth.acompanantePropio(),
        _auth.citaSiguiente(),
        _auth.directorioPsicologos(),
      ]);
      if (!mounted) return;
      setState(() {
        _datosPaciente =
            resultados[0]
                as ({
                  String nombre,
                  String correo,
                  bool requiereAcompanante,
                  String documento,
                  String telefono,
                  String direccion,
                })?;
        _acompanante = resultados[1] as Map<String, dynamic>?;
        _cita = resultados[2] as Map<String, dynamic>?;
        _directorio =
            resultados[3] as Map<int, ({String nombre, String? avatarUrl})>;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los datos del portal.';
        _cargando = false;
      });
    }
  }

  void _showProtectedNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _inicialesDe(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '—';
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  static String _formatearFechaHora(String? valor) {
    if (valor == null) return 'Fecha no informada';
    final fecha = DateTime.tryParse(valor);
    if (fecha == null) return valor;
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora =
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    return '$dia/$mes, $hora hrs';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final nombreAcomp = _acompanante != null
        ? '${_acompanante!['nombre'] ?? ''}'.trim()
        : '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _PortalHeader(),
                      _buildNotice(),
                      const SizedBox(height: 16),
                      const Text(
                        'Portal de acompañamiento',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _demo
                            ? 'Consulta autorizada para Oscar Flerez'
                            : (nombreAcomp.isNotEmpty
                                  ? 'Consulta autorizada para $nombreAcomp'
                                  : 'Consulta autorizada'),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_demo && _acompanante == null) ...[
                        const AvisoVacio(
                          texto: 'Aún no tienes acompañante vinculado.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildPatientSummary(),
                      const SizedBox(height: 16),
                      _buildUpcomingSession(context),
                      const SizedBox(height: 16),
                      _RestrictedAction(
                        icon: Icons.notifications_active_outlined,
                        title: 'Alertas de contingencia',
                        subtitle: 'Inasistencia y alertas OPER 1',
                        onPressed: () => _showProtectedNotice(
                          context,
                          'Las alertas reales requieren acceso propio del acompañante.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _ProtectedSection(),
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

  Widget _buildNotice() {
    if (_demo) {
      return const Column(
        children: [
          SizedBox(height: 16),
          _AccessNotice(texto: 'Sin conexión a la base de datos.'),
        ],
      );
    }
    if (_error != null) {
      return Column(
        children: [
          const SizedBox(height: 16),
          _AccessNotice(texto: _error!),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPatientSummary() {
    if (_demo) {
      return const _PatientSummary(nombre: 'Karen Lucía', initials: 'KL');
    }
    if (_datosPaciente == null) {
      return const AvisoVacio(texto: 'No se encontraron datos del paciente.');
    }
    final nombre = _datosPaciente!.nombre.trim();
    return _PatientSummary(
      nombre: nombre.isEmpty ? 'Paciente' : nombre,
      initials: _inicialesDe(nombre),
    );
  }

  Widget _buildUpcomingSession(BuildContext context) {
    if (_demo) {
      return _UpcomingSession(
        fechaTexto: 'Hoy, 18:30 - 19:20',
        profesionalTexto: 'Sesión en línea con la Dra. Yani Casiani',
        onDetalle: () =>
            _showProtectedNotice(context, 'Sin conexión a la base de datos.'),
      );
    }
    if (_cita == null) {
      return const AvisoVacio(texto: 'Aún no tienes citas programadas.');
    }
    final fecha = _formatearFechaHora(_cita!['fecha_hora'] as String?);
    final idPsicologo = int.tryParse('${_cita!['id_psicologo'] ?? ''}');
    final nombre = idPsicologo == null
        ? ''
        : _directorio[idPsicologo]?.nombre ?? '';
    return _UpcomingSession(
      fechaTexto: fecha,
      profesionalTexto: nombre.isEmpty
          ? 'Sesión con Profesional #${idPsicologo ?? '—'}'
          : 'Sesión con $nombre',
      onDetalle: () => _showProtectedNotice(
        context,
        'El detalle autorizado todavía no está disponible.',
      ),
    );
  }
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppBackButton(onPressed: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 10),
        const BrandLogo(size: 42),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MINDJORA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppText.displayFont,
                  color: AppColors.brandDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text('Portal restringido', style: AppText.bodySmall),
            ],
          ),
        ),
        SquareIconButton(
          icon: Icons.logout_rounded,
          tooltip: 'Cerrar sesión',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: const Color(0xFFE0C391)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF80622F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: Color(0xFF80622F),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientSummary extends StatelessWidget {
  const _PatientSummary({required this.nombre, required this.initials});

  final String nombre;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return _PortalCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.brandSoft,
            foregroundColor: AppColors.brand,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: AppText.sectionTitle),
                const SizedBox(height: 3),
                const Text('Paciente vinculada', style: AppText.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.verified_user_outlined, color: AppColors.brand),
        ],
      ),
    );
  }
}

class _UpcomingSession extends StatelessWidget {
  const _UpcomingSession({
    required this.fechaTexto,
    required this.profesionalTexto,
    required this.onDetalle,
  });

  final String fechaTexto;
  final String profesionalTexto;
  final VoidCallback onDetalle;

  @override
  Widget build(BuildContext context) {
    return _PortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.calendar_month_outlined,
            title: 'Próxima sesión',
          ),
          const SizedBox(height: 14),
          Text(fechaTexto, style: AppText.sectionTitle),
          const SizedBox(height: 4),
          Text(profesionalTexto, style: AppText.bodySmall),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Ver detalles autorizados',
            onPressed: onDetalle,
          ),
        ],
      ),
    );
  }
}

class _RestrictedAction extends StatelessWidget {
  const _RestrictedAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _PortalCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sectionTitle),
                const SizedBox(height: 3),
                Text(subtitle, style: AppText.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _ProtectedSection extends StatelessWidget {
  const _ProtectedSection();

  @override
  Widget build(BuildContext context) {
    return const _PortalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.lock_outline_rounded,
            title: 'Información protegida',
          ),
          SizedBox(height: 12),
          _ProtectedItem(label: 'Notas de terapia'),
          _ProtectedItem(label: 'Diario íntimo'),
          _ProtectedItem(label: 'Tests psicométricos'),
        ],
      ),
    );
  }
}

class _ProtectedItem extends StatelessWidget {
  const _ProtectedItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 17, color: AppColors.textFaint),
          const SizedBox(width: 9),
          Expanded(child: Text(label, style: AppText.body)),
          const Text(
            'OPER 2',
            style: TextStyle(
              color: AppColors.textFaint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.brand),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sectionTitle,
          ),
        ),
      ],
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({required this.child});

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
