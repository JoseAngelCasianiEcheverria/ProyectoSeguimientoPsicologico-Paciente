import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'widgets.dart';

/// Mismo enlace que usa el portal del psicólogo (`core/videollamada.dart`).
String enlaceVideollamada(int idPsicologo) =>
    'https://meet.jit.si/mindjora-psicologo-$idPsicologo';

/// Vista 9: sala de la consulta.
///
/// La antesala maqueta (cámara falsa, validación clínica y reglas de protocolo)
/// se quitó: de aquí se entra a la videollamada real y al hilo de mensajes con
/// el profesional, como en el portal del psicólogo.
class PacienteSalaPage extends StatefulWidget {
  const PacienteSalaPage({super.key, this.auth});

  final PacienteAuth? auth;

  @override
  State<PacienteSalaPage> createState() => _PacienteSalaPageState();
}

class _PacienteSalaPageState extends State<PacienteSalaPage> {
  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  bool _cargando = true;
  bool _demo = false;
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
        _auth.citaSiguiente(),
        _auth.directorioPsicologos(),
      ]);
      if (!mounted) return;
      setState(() {
        _cita = resultados[0] as Map<String, dynamic>?;
        _directorio =
            resultados[1] as Map<int, ({String nombre, String? avatarUrl})>;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  int? get _idPsicologo =>
      _demo ? null : int.tryParse('${_cita?['id_psicologo'] ?? ''}');

  String get _nombreProfesional {
    if (_demo) return 'Dra. Yani Casiani';
    final id = _idPsicologo;
    final nombre = id == null ? '' : _directorio[id]?.nombre ?? '';
    return nombre.isEmpty ? 'Profesional no disponible' : nombre;
  }

  String? get _fotoProfesional {
    final id = _idPsicologo;
    return id == null ? null : _directorio[id]?.avatarUrl;
  }

  String? get _fechaCita {
    final value = _cita?['fecha_hora'] as String?;
    if (value == null) return null;
    final fecha = DateTime.tryParse(value);
    if (fecha == null) return value;
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora =
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
    return '$dia/$mes, $hora hrs';
  }

  void _pending(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _abrirVideollamada() async {
    final id = _idPsicologo;
    if (id == null) {
      _pending('No tienes una cita programada para entrar a la sala.');
      return;
    }
    final uri = Uri.parse(enlaceVideollamada(id));
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _pending('No se pudo abrir la videollamada. Revisa el navegador.');
      }
    } catch (_) {
      _pending('No se pudo abrir la videollamada. Revisa el navegador.');
    }
  }

  void _abrirChat() {
    final id = _idPsicologo;
    if (id == null) {
      _pending('No tienes un profesional asignado para escribirle.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: PacienteChatSheet(
          auth: _auth,
          idPsicologo: id,
          nombre: _nombreProfesional,
        ),
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSpecialist(),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Unirse a la Videollamada Ahora',
                      icon: Icons.videocam_outlined,
                      minHeight: 48,
                      onPressed: _abrirVideollamada,
                    ),
                    const SizedBox(height: 10),
                    SoftButton(
                      label: 'Enviar mensaje breve al profesional',
                      icon: Icons.chat_bubble_outline_rounded,
                      minHeight: 48,
                      backgroundColor: AppColors.chipBg,
                      foregroundColor: AppColors.ink,
                      borderColor: AppColors.border,
                      onPressed: _abrirChat,
                    ),
                    const SizedBox(height: 16),
                    const PrivacyNotice(
                      text:
                          'La videollamada se abre en el navegador con el '
                          'enlace de tu sesión.',
                      background: AppColors.softFill,
                      icon: Icons.lock_outline_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          const Expanded(
            child: Text(
              'Sala de Consulta',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialist() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          FotoPerfil(
            iniciales: inicialesDe(_nombreProfesional),
            url: _fotoProfesional,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreProfesional,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _demo
                      ? 'Hoy, 18:30 – 19:20 hrs'
                      : (_fechaCita ?? 'Sin cita programada.'),
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
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

/// Hilo breve con el profesional: lee los últimos mensajes y envía uno nuevo.
class PacienteChatSheet extends StatefulWidget {
  const PacienteChatSheet({
    super.key,
    required this.auth,
    required this.idPsicologo,
    required this.nombre,
    this.onMessagesSeen,
  });

  final PacienteAuth auth;
  final int idPsicologo;
  final String nombre;
  final VoidCallback? onMessagesSeen;

  @override
  State<PacienteChatSheet> createState() => _PacienteChatSheetState();
}

class _PacienteChatSheetState extends State<PacienteChatSheet> {
  final _controlador = TextEditingController();
  List<Map<String, dynamic>> _mensajes = const [];
  StreamSubscription<Map<String, dynamic>>? _mensajesSubscription;
  bool _cargando = true;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    _mensajesSubscription = widget.auth.mensajesEntrantes().listen(
      (mensaje) {
        final id = int.tryParse('${mensaje['id_psicologo'] ?? ''}');
        if (id != widget.idPsicologo) return;
        unawaited(_cargar());
        if (!mounted) return;
        widget.onMessagesSeen?.call();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('No se pudo mantener la conexión del chat.'),
            ),
          );
      },
    );
  }

  @override
  void dispose() {
    unawaited(_mensajesSubscription?.cancel());
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final mensajes = await widget.auth.mensajesCon(widget.idPsicologo);
      if (!mounted) return;
      setState(() {
        _mensajes = mensajes;
        _error = null;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los mensajes. Inténtalo de nuevo.';
        _cargando = false;
      });
    }
  }

  Future<void> _enviar() async {
    final texto = _controlador.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    final ok = await widget.auth.enviarMensaje(widget.idPsicologo, texto);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje.')),
      );
      return;
    }
    _controlador.clear();
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mensaje a ${widget.nombre}',
            style: AppText.wordmark.copyWith(
              color: AppColors.ink,
              fontSize: 17,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  )
                : _mensajes.isEmpty
                ? const Center(
                    child: Text(
                      'Aún no hay mensajes',
                      style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: _mensajes.length,
                    itemBuilder: (_, i) {
                      final mensaje = _mensajes[i];
                      final pacienteId = int.tryParse(
                        '${mensaje['id_paciente'] ?? ''}',
                      );
                      final autorId = int.tryParse(
                        '${mensaje['autor_id'] ?? ''}',
                      );
                      final esPaciente =
                          pacienteId != null && autorId == pacienteId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Align(
                          alignment: esPaciente
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.76,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: esPaciente
                                    ? AppColors.brand
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: esPaciente
                                    ? null
                                    : Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                '${mensaje['texto'] ?? ''}',
                                style: TextStyle(
                                  color: esPaciente
                                      ? Colors.white
                                      : AppColors.ink,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controlador,
                  maxLines: 1,
                  decoration: appInputDecoration(hint: 'Escribe un mensaje...'),
                  onSubmitted: (_) => _enviar(),
                ),
              ),
              const SizedBox(width: 8),
              SoftButton(
                label: 'Enviar',
                onPressed: _enviando ? null : _enviar,
                minWidth: 90,
                minHeight: 50,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
