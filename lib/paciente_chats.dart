import 'dart:async';

import 'package:flutter/material.dart';

import 'design_system.dart';
import 'paciente_auth.dart';
import 'paciente_sala.dart';
import 'widgets.dart';

/// Bandeja de conversaciones del paciente con sus psicólogos.
class PacienteChatsPage extends StatefulWidget {
  const PacienteChatsPage({super.key, this.auth, this.onMessagesSeen});

  final PacienteAuth? auth;
  final VoidCallback? onMessagesSeen;

  @override
  State<PacienteChatsPage> createState() => _PacienteChatsPageState();
}

class _PacienteChatsPageState extends State<PacienteChatsPage> {
  late final PacienteAuth _auth = widget.auth ?? PacienteAuth();

  List<_ChatPreview> _chats = const [];
  StreamSubscription<Map<String, dynamic>>? _mensajesSubscription;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
    _mensajesSubscription = _auth.mensajesEntrantes().listen(
      (_) {
        unawaited(_cargar(silencioso: true));
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        widget.onMessagesSeen?.call();
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

  @override
  void dispose() {
    unawaited(_mensajesSubscription?.cancel());
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final resultados = await Future.wait<Object?>([
        _auth.mensajesPaciente(),
        _auth.directorioPsicologos(),
      ]);
      final filas = resultados[0] as List<Map<String, dynamic>>;
      final directorio =
          resultados[1] as Map<int, ({String nombre, String? avatarUrl})>;
      final ultimos = <int, Map<String, dynamic>>{};

      for (final mensaje in filas) {
        final id = int.tryParse('${mensaje['id_psicologo'] ?? ''}');
        if (id == null) continue;
        final actual = ultimos[id];
        final fecha = DateTime.tryParse('${mensaje['fecha_envio'] ?? ''}');
        final fechaActual = actual == null
            ? null
            : DateTime.tryParse('${actual['fecha_envio'] ?? ''}');
        if (actual == null ||
            (fecha != null &&
                (fechaActual == null || fecha.isAfter(fechaActual)))) {
          ultimos[id] = mensaje;
        }
      }

      final chats =
          <_ChatPreview>[
            for (final entry in ultimos.entries)
              _ChatPreview(
                idPsicologo: entry.key,
                nombre: directorio[entry.key]?.nombre.trim().isNotEmpty == true
                    ? directorio[entry.key]!.nombre.trim()
                    : 'Psicólogo ${entry.key}',
                avatarUrl: directorio[entry.key]?.avatarUrl,
                mensaje: entry.value,
              ),
          ]..sort((a, b) {
            final fechaA = a.fecha;
            final fechaB = b.fecha;
            if (fechaA == null) return fechaB == null ? 0 : 1;
            if (fechaB == null) return -1;
            return fechaB.compareTo(fechaA);
          });

      if (!mounted) return;
      setState(() {
        _chats = chats;
        _error = null;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los chats. Desliza para reintentar.';
        _cargando = false;
      });
    }
  }

  void _abrirChat(_ChatPreview chat) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: PacienteChatSheet(
          auth: _auth,
          idPsicologo: chat.idPsicologo,
          nombre: chat.nombre,
          onMessagesSeen: widget.onMessagesSeen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ResponsiveContent(child: _buildHeader()),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargar,
                color: AppColors.brand,
                child: ResponsiveContent(
                  child: _cargando
                      ? ListView(
                          physics: AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 260,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ],
                        )
                      : _buildList(),
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
          const Expanded(
            child: Text(
              'Chats',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SquareIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualizar chats',
            onPressed: () => unawaited(_cargar()),
            backgroundColor: AppColors.canvas,
            foregroundColor: AppColors.ink,
            borderColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final error = _error;
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [AvisoVacio(texto: error)],
      );
    }
    if (_chats.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 110),
          AvisoVacio(texto: 'Aún no tienes conversaciones con psicólogos.'),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _chats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            onTap: () => _abrirChat(chat),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  FotoPerfil(
                    iniciales: inicialesDe(chat.nombre),
                    url: chat.avatarUrl,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chat.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${chat.mensaje['texto'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fechaLabel(chat.fecha),
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatPreview {
  const _ChatPreview({
    required this.idPsicologo,
    required this.nombre,
    required this.avatarUrl,
    required this.mensaje,
  });

  final int idPsicologo;
  final String nombre;
  final String? avatarUrl;
  final Map<String, dynamic> mensaje;

  DateTime? get fecha => DateTime.tryParse('${mensaje['fecha_envio'] ?? ''}');
}

String _fechaLabel(DateTime? fecha) {
  if (fecha == null) return '';
  final ahora = DateTime.now();
  final mismaFecha =
      fecha.year == ahora.year &&
      fecha.month == ahora.month &&
      fecha.day == ahora.day;
  if (mismaFecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }
  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}';
}
