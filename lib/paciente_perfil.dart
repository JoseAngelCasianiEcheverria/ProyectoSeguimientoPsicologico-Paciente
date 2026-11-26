import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'design_system.dart';
import 'paciente_acompanante.dart';
import 'paciente_agenda.dart';
import 'paciente_auth.dart';
import 'paciente_diario.dart';
import 'paciente_inicio.dart';
import 'paciente_login.dart';
import 'paciente_notificaciones.dart';
import 'widgets.dart';

/// La captura es maqueta: lo que todavía no tiene flujo conserva el aspecto.
void _noop() {}

/// Borde de las superficies verdes (píldoras e iconos con fondo).
///
/// Es el mismo del panel en modo claro; se toma de [PanelTokens] para no
/// repetir el hex.
final Color _accentBorder = PanelTokens.light().accentBorder;

/// Vista: perfil del paciente y red de apoyo.
///
/// Ficha del paciente, acompañante vinculado con su matriz de permisos y los
/// accesos de gestión y documentación. Como el diario y el directorio de
/// especialistas, es una vista de una sola apariencia: usa [AppColors]
/// directamente y la barra inferior compartida con «Perfil» marcado.
///
/// Es maqueta: los datos son los de la captura y, salvo «Cerrar Sesión» (que
/// vuelve al login), la campana (que abre las notificaciones) y la barra
/// inferior, sus botones solo conservan el aspecto. Las fotos de la captura
/// no existen como asset del proyecto, así que el paciente y el acompañante
/// se resuelven con sus iniciales, igual que la profesional del panel.
class PacientePerfilPage extends StatefulWidget {
  const PacientePerfilPage({super.key, this.auth});

  final PacienteAuth? auth;

  @override
  State<PacientePerfilPage> createState() => _PacientePerfilPageState();
}

class _PacientePerfilPageState extends State<PacientePerfilPage> {
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
  Map<String, dynamic>? _acompanante;
  Map<String, dynamic>? _empresa;
  List<Map<String, dynamic>> _permisos = const [];

  /// Ruta de la foto en el bucket `avatares` (null si no tiene).
  String? _avatarRuta;
  bool _subiendoFoto = false;

  String get _iniciales {
    final n = _datos?.nombre.trim();
    if (n == null || n.isEmpty) return _demo ? 'KZ' : '—';
    final partes = n.split(RegExp(r'\s+'));
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  /// En modo demo no se consulta nada: la pantalla muestra los mockups.
  /// En modo real se leen la ficha, el acompañante y el convenio propios.
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
        _auth.acompanantePropio(),
        _auth.empresaPropia(),
        _auth.avatarPropio(),
        _auth.permisosPropios(),
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
        _acompanante = resultados[1] as Map<String, dynamic>?;
        _empresa = resultados[2] as Map<String, dynamic>?;
        _avatarRuta = resultados[3] as String?;
        _permisos = (resultados[4] as List<Map<String, dynamic>>?) ?? const [];
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// Avatar real con la foto de la base y un boton para cambiarla.
  Widget _buildAvatarReal() {
    final url = _avatarRuta == null ? null : _auth.urlAvatar(_avatarRuta!);
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _Avatar(
              initials: _iniciales,
              size: 84,
              verified: true,
              imageUrl: url,
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: Material(
              color: AppColors.brand,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _subiendoFoto ? null : _cambiarFoto,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _subiendoFoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_outlined,
                          size: 17,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Elige una imagen de la galeria, la sube al bucket y la guarda en la ficha.
  Future<void> _cambiarFoto() async {
    if (_subiendoFoto) return;
    final imagen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (imagen == null) return;
    setState(() => _subiendoFoto = true);
    final bytes = await imagen.readAsBytes();
    final nombre = imagen.name;
    final extension = nombre.contains('.') ? nombre.split('.').last : 'jpg';
    final ruta = await _auth.subirAvatar(bytes: bytes, extension: extension);
    if (!mounted) return;
    setState(() {
      _subiendoFoto = false;
      if (ruta != null) _avatarRuta = ruta;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ruta == null
                ? 'No se pudo actualizar tu foto.'
                : 'Foto de perfil actualizada.',
          ),
        ),
      );
  }

  /// «Inicio» deshace un solo empuje (el panel queda debajo); «Agenda» y
  /// «Diario» sustituyen esta pantalla para que las pestañas no se apilen.
  /// «Perfil» es esta misma pantalla: el toque va, pero la vista no cambia.
  void _openTab(BuildContext context, int index) {
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
      case 2:
        navigator.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const PacienteDiarioPage()),
        );
    }
  }

  /// La campana de la cabecera abre el centro de notificaciones.
  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PacienteNotificacionesPage(auth: _auth),
      ),
    );
  }

  void _openCompanionPortal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PacienteAcompanantePage(auth: _auth),
      ),
    );
  }

  /// Vuelve al login y vacía el historial, para que atrás no regrese al perfil.
  Future<void> _logout(BuildContext context) async {
    await _auth.cerrarSesion();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PacienteLoginPage()),
      (route) => false,
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              // Deslizar hacia abajo vuelve a leer datos, red de apoyo y
              // convenio; el `AlwaysScrollable` permite el gesto aunque el
              // contenido quepa en pantalla.
              child: RefreshIndicator(
                onRefresh: _cargarDatos,
                color: AppColors.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(context),
                      const SizedBox(height: 12),
                      _buildDbNotice(),
                      const SizedBox(height: 18),
                      _buildProfileCard(),
                      if (_demo || _acompanante != null) ...[
                        const SizedBox(height: 16),
                        _buildSupportNetwork(context),
                      ],
                      const SizedBox(height: 16),
                      _buildLogout(context),
                    ],
                  ),
                ),
              ),
            ),
            PanelBottomNav(
              selectedIndex: 3,
              backgroundColor: Colors.white,
              borderColor: AppColors.border,
              selectedColor: AppColors.brand,
              idleColor: AppColors.textFaint,
              onTabSelected: (index) => _openTab(context, index),
            ),
          ],
        ),
      ),
    );
  }

  /// En modo demo es parte del mockup. En modo real solo se pinta si la ficha
  /// no llegó: nunca un «sin conexión» fijo que no sea cierto.
  Widget _buildDbNotice() {
    final texto = _demo
        ? 'Sin conexion a la base de datos.'
        : (_datos == null ? 'No se pudieron cargar tus datos.' : null);
    if (texto == null) return const SizedBox.shrink();

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
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.inkSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: AppText.bodySmall.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  // --- Cabecera ----------------------------------------------------------

  Widget _buildTopBar(BuildContext context) {
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
                'Mi Perfil',
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
          onPressed: () => _openNotifications(context),
          badge: true,
        ),
        const SizedBox(width: 9),
        _InitialsButton(initials: _iniciales),
      ],
    );
  }

  // --- Ficha del paciente ------------------------------------------------

  Widget _buildProfileCard() {
    if (!_demo) return _buildProfileCardReal();
    return _PerfilCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initials: _iniciales, size: 84, verified: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _datos?.nombre.isNotEmpty == true
                          ? _datos!.nombre
                          : 'Karen Lucía Zapata Castillo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display.copyWith(
                        color: AppColors.ink,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _datos?.correo.isNotEmpty == true
                          ? _datos!.correo
                          : 'karen.zapata@empresa.com',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'RUT 14.520.118-2',
                          style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 12.5,
                          ),
                        ),
                        _Dot(),
                        Text(
                          'Ficha #SV-2049',
                          style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildActiveBanner(),
          const SizedBox(height: 12),
          _buildAgreement(),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _kStats.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _StatTile(stat: _kStats[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// «PACIENTE ACTIVO» con el estado de la libreta clínica a la derecha.
  Widget _buildActiveBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: _accentBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.adjust_rounded, size: 19, color: AppColors.brand),
          SizedBox(width: 9),
          Text(
            'PACIENTE ACTIVO',
            style: TextStyle(
              color: AppColors.brandDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Libreta Clínica Al Día',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.brandDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Convenio corporativo con la píldora del plan.
  Widget _buildAgreement() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONVENIO CORPORATIVO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'InnovaTech Solutions S.A.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'PLAN PRO ACTIVO',
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ficha en modo real: solo lo que traen `datosPaciente` y `empresaPropia`.
  ///
  /// Sin RUT ni número de ficha: esos identificadores no existen en la base y
  /// en modo real no se pintan.
  Widget _buildProfileCardReal() {
    final nombre = _datos?.nombre.trim() ?? '';
    final correo = _datos?.correo.trim() ?? '';
    final empresa = _empresa;
    final tokens = PanelTokens.light();

    return _PerfilCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatarReal(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.isEmpty ? 'Sin nombre registrado' : nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display.copyWith(
                        color: AppColors.ink,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      correo.isEmpty ? 'Sin correo registrado' : correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (empresa == null)
                          const Text(
                            'Sin convenio corporativo',
                            style: TextStyle(
                              color: AppColors.textFaint,
                              fontSize: 12.5,
                            ),
                          )
                        else ...[
                          Text(
                            '${empresa['codigo'] ?? ''}',
                            style: const TextStyle(
                              color: AppColors.textFaint,
                              fontSize: 12.5,
                            ),
                          ),
                          const _Dot(),
                          Text(
                            '${empresa['nombre'] ?? ''}',
                            style: const TextStyle(
                              color: AppColors.textFaint,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_datos == null)
            AvisoVacio(texto: 'No se pudieron cargar tus datos.', t: tokens)
          else ...[
            _buildActiveBannerReal(),
            const SizedBox(height: 12),
            _buildContactoReal(),
            const SizedBox(height: 12),
            _buildAgreementReal(),
            const SizedBox(height: 12),
            AvisoVacio(
              texto: 'Aún no hay indicadores de tu proceso.',
              t: tokens,
            ),
          ],
        ],
      ),
    );
  }

  /// «FICHA DE PACIENTE» con la única bandera real que trae la base:
  /// `paciente.requiere_acompanante`.
  Widget _buildActiveBannerReal() {
    final requiere = _datos?.requiereAcompanante ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: _accentBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.adjust_rounded, size: 19, color: AppColors.brand),
          const SizedBox(width: 9),
          // Los dos textos son flexibles: con el ancho de un móvil estrecho
          // se recortan con puntos suspensivos en vez de desbordar.
          const Expanded(
            child: Text(
              'FICHA DE PACIENTE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.brandDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              requiere ? 'Acompañante requerido' : 'Sin acompañante',
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.brandDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Convenio real desde `empresaPropia`. Sin fila se avisa en vez de pintar
  /// «InnovaTech Solutions S.A.».
  ///
  /// Las políticas RLS pueden negar la lectura de `empresa` al paciente
  /// (bloqueo 6.7): en ese caso también sale el aviso.
  /// Documento y teléfono guardados en `usuario` al registrarse. Si no hay
  /// datos (cuentas antiguas), se avisa en vez de inventarlos.
  Widget _buildContactoReal() {
    final tokens = PanelTokens.light();
    final documento = _datos?.documento.trim() ?? '';
    final telefono = _datos?.telefono.trim() ?? '';
    final direccion = _datos?.direccion.trim() ?? '';
    if (documento.isEmpty && telefono.isEmpty && direccion.isEmpty) {
      return AvisoVacio(
        texto: 'Aún no hay documento, teléfono ni dirección registrados.',
        t: tokens,
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (documento.isNotEmpty) Text('Documento: $documento'),
          if (telefono.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Teléfono: $telefono'),
          ],
          if (direccion.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Dirección: $direccion'),
          ],
        ],
      ),
    );
  }

  Widget _buildAgreementReal() {
    final tokens = PanelTokens.light();
    final empresa = _empresa;
    if (empresa == null) {
      return AvisoVacio(texto: 'Aún no tienes convenio asociado.', t: tokens);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONVENIO CORPORATIVO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${empresa['nombre'] ?? 'Sin nombre'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '${empresa['codigo'] ?? ''}',
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Red de apoyo y acompañante ---------------------------------------

  Widget _buildSupportNetwork(BuildContext context) {
    return _PerfilCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeading(
            title: 'Red de Apoyo y Acompañante',
            icon: Icons.people_outline_rounded,
          ),
          const SizedBox(height: 8),
          Text(
            'Supervisión logística y alertas preventivas bajo tu '
            'consentimiento',
            style: AppText.body.copyWith(
              color: AppColors.inkSoft,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          _buildCompanion(),
          const SizedBox(height: 20),
          const Text(
            'MATRIZ DE PERMISOS Y PROTECCIÓN',
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          if (_demo) ...[
            const _PermissionRow(
              icon: Icons.error_outline_rounded,
              title: 'Alertas de inasistencia o contingencia (OPER 1)',
              enabled: true,
            ),
            const SizedBox(height: 10),
            const _PermissionRow(
              icon: Icons.calendar_today_outlined,
              title: 'Calendario de próximas sesiones y horarios',
              enabled: true,
            ),
            const SizedBox(height: 10),
            const _PermissionRow(
              icon: Icons.lock_outline_rounded,
              title:
                  'Notas de terapia, diario íntimo y tests clínicos (OPER 2)',
              enabled: false,
              note: AppText.lockedNotesNotice,
            ),
          ] else
            ..._buildPermisosReal(),
          const SizedBox(height: 18),
          _WideButton(
            label: 'Configurar Notificaciones del Acompañante',
            icon: Icons.notifications_active_outlined,
            onPressed: _noop,
            background: AppColors.brandSoft,
            foreground: AppColors.brandDark,
            border: _accentBorder,
          ),
          const SizedBox(height: 10),
          _WideButton(
            label: 'Portal del Acompañante',
            icon: Icons.family_restroom_rounded,
            onPressed: () => _openCompanionPortal(context),
            background: Colors.white,
            foreground: AppColors.brandDark,
            border: _accentBorder,
          ),
          const SizedBox(height: 10),
          const _WideButton(
            label: 'Desvincular Acompañante',
            icon: Icons.person_remove_outlined,
            onPressed: _noop,
            background: Colors.white,
            foreground: AppColors.error,
            border: AppColors.error,
          ),
        ],
      ),
    );
  }

  /// Filas de la matriz de permisos leídas de la base en modo real.
  /// Mapea ALERTA, CITA y recursos clínicos (NOTA_CLINICA, SEGUIMIENTO,
  /// TEST_RESULTADO) y avisa si la base no tiene permisos para este paciente.
  List<Widget> _buildPermisosReal() {
    final tieneAlerta = _permisos.any((p) => p['tipo_recurso'] == 'ALERTA');
    final tieneCita = _permisos.any((p) => p['tipo_recurso'] == 'CITA');
    final tieneClinico = _permisos.any(
      (p) => const [
        'NOTA_CLINICA',
        'SEGUIMIENTO',
        'TEST_RESULTADO',
      ].contains(p['tipo_recurso']),
    );

    final filas = <Widget>[
      if (tieneAlerta)
        const _PermissionRow(
          icon: Icons.error_outline_rounded,
          title: 'Alertas de inasistencia o contingencia (OPER 1)',
          enabled: true,
        ),
      if (tieneCita)
        const _PermissionRow(
          icon: Icons.calendar_today_outlined,
          title: 'Calendario de próximas sesiones y horarios',
          enabled: true,
        ),
      if (tieneClinico)
        const _PermissionRow(
          icon: Icons.lock_outline_rounded,
          title: 'Notas de terapia, diario íntimo y tests clínicos (OPER 2)',
          enabled: true,
        ),
    ];

    if (filas.isEmpty) {
      return const [AvisoVacio(texto: 'Aún no tienes permisos registrados.')];
    }

    return [
      for (var i = 0; i < filas.length; i++) ...[
        if (i > 0) const SizedBox(height: 10),
        filas[i],
      ],
    ];
  }

  /// Acompañante vinculado: iniciales, parentesco, teléfono y vinculación.
  Widget _buildCompanion() {
    if (!_demo) return _buildCompanionReal();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _Avatar(initials: 'OF', size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oscar Flerez',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.panelHeading.copyWith(
                        color: AppColors.ink,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Padre / Tutor designado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '+56 9 8765 4321',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accentBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 16, color: AppColors.brand),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'VINCULACIÓN ACTIVA (OPER 1)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Acompañante real desde `acompanantePropio`.
  ///
  /// Sin fila no se inventa a nadie: se avisa. El nombre viene de la propia
  /// fila de `acompanante`, no de `usuario`.
  Widget _buildCompanionReal() {
    final tokens = PanelTokens.light();
    final comp = _acompanante;
    if (comp == null) {
      return AvisoVacio(
        texto: 'Aún no tienes acompañante vinculado.',
        t: tokens,
      );
    }

    final nombre = '${comp['nombre'] ?? ''}'.trim();
    final parentesco = '${comp['parentesco'] ?? ''}'.trim();
    final telefono = '${comp['telefono'] ?? ''}'.trim();
    final documento = '${comp['documento'] ?? ''}'.trim();
    final detalle = [
      if (parentesco.isNotEmpty) parentesco,
      if (documento.isNotEmpty) 'Doc. $documento',
      if (telefono.isNotEmpty) telefono,
      if (telefono.isEmpty && parentesco.isEmpty && documento.isEmpty)
        'Sin datos de contacto',
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(initials: _inicialesDe(nombre), size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre.isEmpty ? 'Acompañante' : nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.panelHeading.copyWith(
                        color: AppColors.ink,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detalle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accentBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 16, color: AppColors.brand),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'Vínculo registrado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.brandDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Iniciales de un nombre que viene de la base, o «—» si está vacío.
  static String _inicialesDe(String nombre) {
    final partes = nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '—';
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return partes[0][0].toUpperCase();
  }

  // --- Cierre de sesión --------------------------------------------------

  Widget _buildLogout(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _logout(context),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.logout_rounded, size: 20, color: AppColors.inkSoft),
          SizedBox(width: 10),
          Text('Cerrar Sesión'),
        ],
      ),
    );
  }
}

// --- Datos de muestra ------------------------------------------------------

/// Indicadores de la ficha: sesiones del mes, adherencia y fase clínica.
const List<({String label, String value, String caption})> _kStats =
    <({String label, String value, String caption})>[
      (label: 'SESIONES', value: '2 de 4', caption: 'este mes'),
      (label: 'ASISTENCIA', value: '92%', caption: 'adherencia'),
      (label: 'FASE CLÍNICA', value: 'Semana 8', caption: 'Consolidación'),
    ];

// --- Piezas de la pantalla -------------------------------------------------

/// Tarjeta blanca con borde: bloque base del perfil.
class _PerfilCard extends StatelessWidget {
  const _PerfilCard({required this.child});

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

/// Título serif de tarjeta, con icono opcional a la izquierda.
class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: AppColors.brand),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.panelHeading.copyWith(
              color: AppColors.ink,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón cuadrado verde con las iniciales del paciente en la cabecera.
class _InitialsButton extends StatelessWidget {
  const _InitialsButton({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mi perfil',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar con iniciales o con la foto de la base; `verified` añade la insignia.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.size,
    this.verified = false,
    this.imageUrl,
  });

  final String initials;
  final double size;
  final bool verified;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initialsWidget = Center(
      child: Text(
        initials,
        style: AppText.wordmark.copyWith(
          color: AppColors.brandDark,
          fontSize: size * 0.32,
          letterSpacing: 0.5,
        ),
      ),
    );
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: _accentBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? initialsWidget
          : Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initialsWidget,
            ),
    );
    if (!verified) return box;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: box),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto separador entre el RUT y la ficha.
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: AppColors.dot,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Indicador de la ficha: etiqueta, valor y detalle.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final ({String label, String value, String caption}) stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.softFill,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Fila de la matriz de permisos: habilitada, o bloqueada con su motivo.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.enabled,
    this.note,
  });

  final IconData icon;
  final String title;
  final bool enabled;

  /// Motivo del bloqueo; solo lo llevan las filas bloqueadas.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : AppColors.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: enabled ? AppColors.inkSoft : AppColors.textFaint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StateChip(
                label: enabled ? 'Habilitado' : 'BLOQUEADO',
                enabled: enabled,
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 33),
              child: Text(
                note!,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Etiqueta de estado del permiso: verde si está habilitado, gris si no.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: enabled ? AppColors.brandSoft : AppColors.border,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: enabled ? _accentBorder : AppColors.dot),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: enabled ? AppColors.brandDark : AppColors.inkSoft,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: enabled ? 0 : 0.4,
        ),
      ),
    );
  }
}

/// Botón ancho con titular serif. A diferencia de [SoftButton], deja que el
/// texto pase a dos líneas: «Configurar Notificaciones del Acompañante» no
/// cabe en una en pantallas estrechas.
class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: border, width: 1.2),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppText.displayFont,
                color: foreground,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
