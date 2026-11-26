import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/supabase_client.dart';

/// Igual que en el portal del psicologo: no se devuelve un `String` suelto
/// porque la pantalla tiene que diferenciar credenciales malas, correo sin
/// confirmar y problema de red. El usuario actua distinto en cada caso.
enum FalloDeLogin {
  credenciales,
  correoSinConfirmar,
  contrasenaFiltrada,
  red,
  rolNoAutorizado,
  desconocido,
}

class ResultadoLogin {
  const ResultadoLogin.ok() : fallo = null, mensaje = null;

  const ResultadoLogin.error(this.fallo, this.mensaje);

  final FalloDeLogin? fallo;
  final String? mensaje;

  bool get exito => fallo == null;

  /// Texto para mostrar en la pantalla de login.
  String get textoParaUsuario => mensaje ?? 'No pudimos iniciar sesion.';
}

/// Resultado de un intento de registro de paciente.
class ResultadoRegistro {
  const ResultadoRegistro.exito({required this.requiereConfirmacion})
    : mensaje = null;

  const ResultadoRegistro.error(this.mensaje) : requiereConfirmacion = false;

  final bool requiereConfirmacion;
  final String? mensaje;

  bool get exito => mensaje == null;
}

/// Inicio y cierre de sesion del paciente contra Supabase Auth.
///
/// Es el equivalente del `AuthService` del proyecto principal, pero vive en
/// `lib/paciente_auth.dart` porque la rama del paciente no toca
/// `lib/repositories/`. Si mas adelante Jose prefiere unificarlo, lo mueve el.
class PacienteAuth {
  PacienteAuth({SupabaseClient? cliente}) : _clienteExterno = cliente;

  final SupabaseClient? _clienteExterno;

  Future<SupabaseClient> get _cliente async =>
      _clienteExterno ?? AppSupabase.instance();

  String? _errorReserva;

  /// Motivo del ultimo fallo de [reservarSlot], para que la pantalla explique
  /// el error real (horario tomado, sesion vencida, red) en vez de uno generico.
  String? get errorReserva => _errorReserva;

  String? _errorSeguimiento;

  /// Motivo del ultimo fallo al guardar el animo.
  String? get errorSeguimiento => _errorSeguimiento;

  /// Intenta iniciar sesion.
  ///
  /// No devuelve excepcion: cualquier fallo se traduce a [ResultadoLogin]. La
  /// pantalla de login no deberia catchear errores de Supabase.
  Future<ResultadoLogin> iniciarSesion(String correo, String contrasena) async {
    final limpio = correo.trim().toLowerCase();
    if (limpio.isEmpty || contrasena.isEmpty) {
      return const ResultadoLogin.error(
        FalloDeLogin.credenciales,
        'Ingresa tu correo y tu contrasena.',
      );
    }

    try {
      final cliente = await _cliente;
      final resp = await cliente.auth.signInWithPassword(
        email: limpio,
        password: contrasena,
      );

      if (resp.session == null) {
        return const ResultadoLogin.error(
          FalloDeLogin.credenciales,
          'Correo o contrasena incorrectos.',
        );
      }
      return const ResultadoLogin.ok();
    } on AuthException catch (e) {
      return _traducir(e);
    } on AppConfigException {
      return const ResultadoLogin.error(
        FalloDeLogin.red,
        'Sin conexion a la base de datos.',
      );
    } catch (_) {
      return const ResultadoLogin.error(
        FalloDeLogin.red,
        'Sin conexion a la base de datos.',
      );
    }
  }

  /// Crea la cuenta de un paciente.
  ///
  /// El perfil en `usuario`, `paciente` y `acompanante` lo crea un trigger
  /// de la base al recibir el signUp: viaja todo en los metadatos
  /// (nombre, documento, telefono, interruptor de acompanante y, si
  /// aplica, los datos de la persona autorizada). Migracion
  /// `registro_datos_formulario`.
  Future<ResultadoRegistro> registrarPaciente({
    required String nombre,
    required String correo,
    required String contrasena,
    String? documento,
    String? telefono,
    bool requiereAcompanante = false,
    String? acompananteNombre,
    String? acompananteParentesco,
    String? acompananteDocumento,
    String? acompananteEmail,
  }) async {
    final limpio = correo.trim().toLowerCase();
    final datos = <String, dynamic>{
      'rol': 'PACIENTE',
      'nombre': nombre.trim(),
      'requiere_acompanante': requiereAcompanante,
    };
    if (documento != null && documento.trim().isNotEmpty) {
      datos['documento'] = documento.trim();
    }
    if (telefono != null && telefono.trim().isNotEmpty) {
      datos['telefono'] = telefono.trim();
    }
    final nombreAcompanante = acompananteNombre?.trim() ?? '';
    if (requiereAcompanante && nombreAcompanante.isNotEmpty) {
      datos['acompanante'] = <String, dynamic>{
        'nombre': nombreAcompanante,
        if ((acompananteParentesco ?? '').trim().isNotEmpty)
          'parentesco': acompananteParentesco!.trim(),
        if ((acompananteDocumento ?? '').trim().isNotEmpty)
          'documento': acompananteDocumento!.trim(),
        if ((acompananteEmail ?? '').trim().isNotEmpty)
          'email': acompananteEmail!.trim(),
      };
    }
    try {
      final cliente = await _cliente;
      final resp = await cliente.auth.signUp(
        email: limpio,
        password: contrasena,
        data: datos,
      );

      if (resp.user == null) {
        return const ResultadoRegistro.error(
          'No pudimos crear la cuenta. Intenta de nuevo.',
        );
      }
      return ResultadoRegistro.exito(
        requiereConfirmacion: resp.session == null,
      );
    } on AuthException catch (e) {
      return _traducirRegistro(e);
    } on AppConfigException {
      return const ResultadoRegistro.error('Sin conexion a la base de datos.');
    } catch (_) {
      return const ResultadoRegistro.error('Sin conexion a la base de datos.');
    }
  }

  /// Traduce el error de Supabase al registrar.
  ResultadoRegistro _traducirRegistro(AuthException e) {
    final codigo = e.code ?? '';
    final mensaje = e.message.toLowerCase();

    if (codigo == 'user_already_exists' ||
        mensaje.contains('already registered') ||
        mensaje.contains('already been registered')) {
      return const ResultadoRegistro.error(
        'Ya existe una cuenta con ese correo. Inicia sesion.',
      );
    }
    if (codigo == 'weak_password' ||
        mensaje.contains('weak') ||
        mensaje.contains('leaked') ||
        mensaje.contains('breached')) {
      return const ResultadoRegistro.error(
        'Esa contrasena aparece en listas de filtradas. Usa otra.',
      );
    }
    if (codigo == 'over_email_send_rate_limit' ||
        mensaje.contains('rate limit')) {
      return const ResultadoRegistro.error(
        'Demasiados intentos. Espera unos minutos e intenta de nuevo.',
      );
    }
    if (mensaje.contains('database error')) {
      return const ResultadoRegistro.error(
        'No se pudo crear el perfil. Revisa los datos.',
      );
    }
    if (mensaje.contains('socket') ||
        mensaje.contains('connection') ||
        mensaje.contains('failed to fetch') ||
        mensaje.contains('network') ||
        mensaje.contains('timeout')) {
      return const ResultadoRegistro.error('Sin conexion a la base de datos.');
    }
    return const ResultadoRegistro.error(
      'No pudimos crear la cuenta. Intenta de nuevo.',
    );
  }

  /// Rol del usuario con sesion abierta, o `null` si no hay perfil.
  ///
  /// `mi_rol()` es `SECURITY DEFINER` y solo devuelve la fila propia, asi que
  /// no expone roles ajenos. Se atrapa el error a proposito: un perfil
  /// incompleto debe tratarse como "sin acceso", no tumbar el login.
  Future<String?> rolActual() async {
    try {
      final cliente = await _cliente;
      final rol = await cliente.rpc('mi_rol');
      return rol is String ? rol : null;
    } catch (_) {
      return null;
    }
  }

  /// `true` si queda una sesion de paciente al abrir la app. Supabase ya
  /// persiste el token en el dispositivo; aqui solo se comprueba que siga
  /// vigente y que el perfil siga siendo PACIENTE.
  Future<bool> haySesionDePaciente() async {
    try {
      final cliente = await _cliente;
      if (cliente.auth.currentSession == null) return false;
      return await rolActual() == 'PACIENTE';
    } catch (_) {
      return false;
    }
  }

  /// Cierra la sesion y limpia el cliente cacheado.
  Future<void> cerrarSesion() async {
    final cliente = await _cliente;
    await cliente.auth.signOut();
    AppSupabase.reset();
  }

  /// Unica cuenta que ve los mockups tal como estan en la captura.
  ///
  /// Toda el resto, incluidas las cuentas que se creen a partir de ahora, ve
  /// datos reales de la base con avisos de vacio donde no haya datos.
  static const String cuentaDemo = 'karen.zapata@mindjora.demo';

  /// `true` si la sesion activa es la cuenta demo.
  ///
  /// En duda se comporta como cuenta real: no hay sesion, no se puede leer el
  /// correo o falla la base, y entonces no se muestran datos inventados.
  Future<bool> esCuentaDemo() async {
    try {
      final cliente = await _cliente;
      final correo = cliente.auth.currentUser?.email;
      if (correo == null) return false;
      return correo.trim().toLowerCase() == cuentaDemo;
    } catch (_) {
      return false;
    }
  }

  /// Id del usuario con sesion abierta, o `null` si no hay.
  Future<String?> idUsuarioActual() async {
    try {
      final cliente = await _cliente;
      return cliente.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// Id de negocio del paciente autenticado (`usuario.id_usuario`, que coincide
  /// con `paciente.id_paciente`), o `null` si no hay sesion o perfil.
  Future<int?> idPacienteActual() async {
    try {
      final cliente = await _cliente;
      final id = await cliente.rpc('mi_usuario_id');
      if (id == null) return null;
      return id is int ? id : int.tryParse('$id');
    } on AppConfigException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ruta de la foto de perfil en el bucket `avatares`, o `null` si no tiene.
  Future<String?> avatarPropio() async {
    try {
      final cliente = await _cliente;
      final fila = await cliente
          .from('usuario')
          .select('avatar_url')
          .maybeSingle();
      final ruta = fila?['avatar_url'] as String?;
      return (ruta == null || ruta.isEmpty) ? null : ruta;
    } on AppConfigException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// URL publica de una ruta del bucket `avatares`.
  String urlAvatar(String ruta) =>
      '${AppConfig.supabaseUrl}/storage/v1/object/public/avatares/$ruta';

  /// Sube la foto al bucket `avatares` (carpeta propia) y guarda la ruta en
  /// `usuario.avatar_url`. Devuelve la ruta nueva, o `null` si fallo.
  ///
  /// shortcut: no borra la foto anterior; las viejas quedan en el bucket.
  Future<String?> subirAvatar({
    required List<int> bytes,
    required String extension,
  }) async {
    try {
      final cliente = await _cliente;
      final uid = cliente.auth.currentUser?.id;
      if (uid == null) return null;
      final ext = extension.toLowerCase().replaceAll('.', '');
      final tipo = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final ruta =
          '$uid/avatar-${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
      await cliente.storage
          .from('avatares')
          .uploadBinary(
            ruta,
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: tipo, upsert: true),
          );
      final id = await cliente.rpc('mi_usuario_id');
      final idInt = id is int ? id : int.tryParse('$id');
      if (idInt == null) return null;
      await cliente
          .from('usuario')
          .update(<String, dynamic>{'avatar_url': ruta})
          .eq('id_usuario', idInt);
      return ruta;
    } on AppConfigException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Guarda un registro de seguimiento diario del paciente autenticado.
  ///
  /// Devuelve `true` si se guardo (o si no hay sesion, para no bloquear la UI
  /// en entornos sin base). Devuelve `false` solo si hubo un error real.
  Future<bool> guardarSeguimiento({
    required int nivelAnimo,
    String? comentarios,
    bool esCritico = false,
  }) async {
    _errorSeguimiento = null;
    try {
      final id = await idPacienteActual();
      if (id == null) return true;
      final cliente = await _cliente;
      await cliente.from('seguimiento_diario').insert(<String, dynamic>{
        'id_paciente': id,
        'nivel_animo': nivelAnimo,
        'es_critico': esCritico,
        'comentarios': comentarios,
        'fecha': DateTime.now().toIso8601String().substring(0, 10),
        'fecha_registro': DateTime.now().toIso8601String(),
      });
      return true;
    } on AppConfigException {
      return true;
    } on PostgrestException catch (e) {
      _errorSeguimiento = switch (e.code) {
        '23503' =>
          'Tu perfil de paciente no esta completo. Contacta con soporte.',
        '42501' => 'Tu sesion expiro. Vuelve a iniciar sesion.',
        _ => 'No se pudo guardar tu animo. Intenta de nuevo.',
      };
      return false;
    } catch (_) {
      _errorSeguimiento = 'Sin conexion a la base de datos.';
      return false;
    }
  }

  /// Guarda el resultado de una bateria de tests del paciente autenticado.
  ///
  /// Busca el test en el catalogo `test_psicometrico` por nombre y guarda
  /// tambien las respuestas por item. Si no hay sesion o no hay configuracion
  /// de base no hay nada que guardar; si el test no esta en el catalogo o falla
  /// la insercion se devuelve `false` para que la pantalla lo avise.
  Future<bool> guardarEvaluacion({
    required String nombreTest,
    required int puntajeTotal,
    List<int?>? respuestas,
  }) async {
    try {
      final idPaciente = await idPacienteActual();
      if (idPaciente == null) return false;
      final cliente = await _cliente;
      final fila = await cliente
          .from('test_psicometrico')
          .select('id_test')
          .eq('nombre', nombreTest)
          .maybeSingle();
      if (fila == null) return false;
      final idTest = fila['id_test'];
      if (idTest == null) return false;
      await cliente.from('evaluacion_paciente').insert(<String, dynamic>{
        'id_paciente': idPaciente,
        'id_test': idTest,
        'puntaje_total': puntajeTotal,
        'respuestas': respuestas,
        'completado': true,
        'fecha_completado': DateTime.now().toIso8601String(),
      });
      return true;
    } on AppConfigException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Marca como completada la tarea asignada que corresponde a un test.
  Future<bool> completarTareaTest(String nombreTest) async {
    try {
      final idPaciente = await idPacienteActual();
      if (idPaciente == null) return false;
      final cliente = await _cliente;
      final filas = await cliente
          .from('tarea_recomendada')
          .select('id_tarea,descripcion,completada')
          .eq('id_paciente', idPaciente);
      final tareas = (filas as List).cast<Map<String, dynamic>>();
      final descripcionEsperada = 'Completar test ${nombreTest.trim()}'
          .toLowerCase();
      var encontrada = false;

      for (final tarea in tareas) {
        final descripcion = '${tarea['descripcion'] ?? ''}'
            .trim()
            .toLowerCase();
        if (descripcion != descripcionEsperada) continue;
        encontrada = true;
        if (tarea['completada'] == true) continue;

        final idTarea = tarea['id_tarea'];
        if (idTarea == null) return false;
        final actualizada = await cliente
            .from('tarea_recomendada')
            .update(<String, dynamic>{'completada': true})
            .eq('id_tarea', idTarea)
            .eq('id_paciente', idPaciente)
            .select('id_tarea');
        if ((actualizada as List).isEmpty) return false;
      }

      return encontrada;
    } on AppConfigException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Catalogo de psicologos disponibles (tabla `psicologo`, lectura publica).
  ///
  /// El NOMBRE del profesional vive en `usuario` y el paciente no puede leerlo
  /// (bloqueo 6.1): aqui solo se devuelven los datos de `psicologo`
  /// (id, tarifa, empresa, enfoques, titulo). La UI combina esto con el
  /// catalogo que tenga a mano hasta que exista el RPC `catalogo_psicologos()`.
  Future<List<Map<String, dynamic>>> catalogoPsicologos() async {
    try {
      final cliente = await _cliente;
      // OJO: la base real solo tiene id_psicologo, tarifa_base, es_independiente e
      // id_empresa (la migracion 13 que agrega titulo/enfoques/telefono NO esta
      // aplicada en este proyecto). Seleccionar columnas inexistentes da 400.
      final filas = await cliente
          .from('psicologo')
          .select('id_psicologo,tarifa_base,es_independiente,id_empresa');
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Horarios disponibles de un psicologo.
  ///
  /// Solo los huecos futuros de los proximos 28 dias: es la misma ventana
  /// que genera el portal del psicologo con su herramienta de horarios
  /// semanales. Los slots pasados no se muestran (el portal no los borra,
  /// pero tampoco se pueden reservar ya).
  /// Nombre y foto de los psicologos, por id. La tabla `usuario` no se puede
  /// leer directamente (bloqueo 6.1): lo expone el RPC `directorio_psicologos`,
  /// creado en la migracion `sql/20261123_directorio_psicologos.sql`.
  /// Sin la migracion devuelve un mapa vacio y las pantallas conservan su
  /// aviso honesto en vez de inventar nombres.
  Future<Map<int, ({String nombre, String? avatarUrl})>>
  directorioPsicologos() async {
    try {
      final cliente = await _cliente;
      final filas = await cliente.rpc('directorio_psicologos');
      final resultado = <int, ({String nombre, String? avatarUrl})>{};
      for (final fila in (filas as List?) ?? const <dynamic>[]) {
        if (fila is! Map) continue;
        final id = int.tryParse('${fila['id_psicologo'] ?? ''}');
        if (id == null) continue;
        final ruta = (fila['avatar_url'] as String?)?.trim() ?? '';
        resultado[id] = (
          nombre: (fila['nombre'] as String?)?.trim() ?? '',
          avatarUrl: ruta.isEmpty ? null : urlAvatar(ruta),
        );
      }
      return resultado;
    } on AppConfigException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  /// Todos los mensajes visibles del paciente, para agrupar sus conversaciones.
  Future<List<Map<String, dynamic>>> mensajesPaciente() async {
    final idPaciente = await idPacienteActual();
    if (idPaciente == null) return const [];
    final cliente = await _cliente;
    final filas = await cliente
        .from('mensaje_chat')
        .select('id_psicologo,autor_id,texto,fecha_envio')
        .eq('id_paciente', idPaciente)
        .order('fecha_envio', ascending: false);
    return (filas as List).cast<Map<String, dynamic>>();
  }

  /// Ultimos mensajes del hilo con un psicologo.
  Future<List<Map<String, dynamic>>> mensajesCon(int idPsicologo) async {
    final idPaciente = await idPacienteActual();
    if (idPaciente == null) return const [];
    final cliente = await _cliente;
    final filas = await cliente
        .from('mensaje_chat')
        .select('id_mensaje,id_paciente,autor_id,texto,fecha_envio')
        .eq('id_psicologo', idPsicologo)
        .eq('id_paciente', idPaciente)
        .order('fecha_envio', ascending: false)
        .limit(50);
    return (filas as List).cast<Map<String, dynamic>>().reversed.toList();
  }

  /// Cambios en tiempo real de los mensajes recibidos por el paciente.
  ///
  /// La suscripcion se cancela cuando el consumidor deja de escuchar el
  /// stream. Se filtran mensajes enviados por el propio paciente.
  Stream<Map<String, dynamic>> mensajesEntrantes() {
    late final StreamController<Map<String, dynamic>> controller;
    RealtimeChannel? channel;
    var cancelRequested = false;

    Future<void> subscribe() async {
      try {
        final idPaciente = await idPacienteActual();
        if (cancelRequested || idPaciente == null) return;
        final cliente = await _cliente;
        if (cancelRequested) return;

        final candidate = cliente
            .channel(
              'paciente-mensajes-$idPaciente-'
              '${DateTime.now().microsecondsSinceEpoch}',
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'mensaje_chat',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id_paciente',
                value: idPaciente.toString(),
              ),
              callback: (payload) {
                if (cancelRequested || controller.isClosed) return;
                final mensaje = payload.newRecord;
                final autorId = int.tryParse('${mensaje['autor_id'] ?? ''}');
                if (autorId == idPaciente) return;
                controller.add(Map<String, dynamic>.from(mensaje));
              },
            );
        if (cancelRequested) return;
        channel = candidate.subscribe((status, error) {
          if (cancelRequested || controller.isClosed) return;
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            controller.addError(
              error ?? StateError('No se pudo suscribir a los mensajes.'),
            );
          }
        });
      } catch (error, stackTrace) {
        if (!cancelRequested && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () => unawaited(subscribe()),
      onCancel: () async {
        cancelRequested = true;
        await channel?.unsubscribe();
      },
    );
    return controller.stream;
  }

  /// Envia un mensaje breve al psicologo. La RLS exige que el autor sea el
  /// propio paciente y que el hilo sea el suyo.
  Future<bool> enviarMensaje(int idPsicologo, String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || limpio.length > 2000) return false;
    try {
      final idPaciente = await idPacienteActual();
      if (idPaciente == null) return false;
      final cliente = await _cliente;
      await cliente.from('mensaje_chat').insert(<String, dynamic>{
        'id_psicologo': idPsicologo,
        'id_paciente': idPaciente,
        'autor_id': idPaciente,
        'texto': limpio,
      });
      return true;
    } on AppConfigException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> disponibilidadDe(int idPsicologo) async {
    try {
      final cliente = await _cliente;
      final ahora = DateTime.now().toUtc();
      final hasta = ahora.add(const Duration(days: 28));
      final filas = await cliente
          .from('disponibilidad')
          .select('id_disponibilidad,fecha_hora_inicio,fecha_hora_fin,estado')
          .eq('id_psicologo', idPsicologo)
          .eq('estado', 'DISPONIBLE')
          .gte('fecha_hora_inicio', ahora.toIso8601String())
          .lt('fecha_hora_inicio', hasta.toIso8601String())
          .order('fecha_hora_inicio', ascending: true);
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Reserva una cita con `reservar_slot`. Devuelve la cita creada o `null`
  /// si fallo; en ese caso [errorReserva] explica el motivo.
  Future<Map<String, dynamic>?> reservarSlot({
    required int idPsicologo,
    required int idDisponibilidad,
    String modalidad = 'PRESENCIAL',
    String? motivo,
  }) async {
    _errorReserva = null;
    try {
      final idPaciente = await idPacienteActual();
      if (idPaciente == null) {
        _errorReserva =
            'Tu cuenta no tiene perfil de paciente. '
            'Vuelve a iniciar sesion.';
        return null;
      }
      final cliente = await _cliente;
      final cita = await cliente.rpc(
        'reservar_slot',
        params: <String, dynamic>{
          'p_id_paciente': idPaciente,
          'p_id_psicologo': idPsicologo,
          'p_id_disponibilidad': idDisponibilidad,
          'p_modalidad': modalidad,
          'p_motivo_consulta': motivo,
        },
      );
      if (cita is Map<String, dynamic>) return cita;
      if (cita is List && cita.isNotEmpty && cita.first is Map) {
        return (cita.first as Map).cast<String, dynamic>();
      }
      _errorReserva = 'No se pudo reservar la cita. Intenta de nuevo.';
      return null;
    } on PostgrestException catch (e) {
      _errorReserva = switch (e.code) {
        '23505' => 'Ese horario acaba de ser reservado. Elige otro.',
        '23514' => 'Ese horario ya no esta disponible. Elige otro.',
        '23503' =>
          'Tu perfil de paciente no esta completo. Contacta con soporte.',
        '42501' => 'Tu sesion expiro. Vuelve a iniciar sesion.',
        _ => 'No se pudo reservar la cita. Intenta de nuevo.',
      };
      return null;
    } on AppConfigException {
      _errorReserva = 'Sin conexion a la base de datos.';
      return null;
    } catch (_) {
      _errorReserva = 'Sin conexion a la base de datos.';
      return null;
    }
  }

  /// Citas propias del paciente (tabla `cita`, RLS a propio).
  Future<List<Map<String, dynamic>>> citasPropias() async {
    try {
      final cliente = await _cliente;
      final filas = await cliente
          .from('cita')
          .select(
            'id_cita,id_psicologo,fecha_hora,estado_cita,modalidad,motivo_consulta',
          )
          .order('fecha_hora', ascending: false);
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Ficha propia del paciente autenticado: nombre y correo desde `usuario`,
  /// y el flag de acompanante desde `paciente`.
  ///
  /// Lee solo la fila propia (las politicas RLS lo permiten). Devuelve `null`
  /// si no hay sesion, no hay perfil o falla la red: la pantalla decide que
  /// mostrar en ese caso (estado vacio o de error).
  Future<
    ({
      String nombre,
      String correo,
      bool requiereAcompanante,
      String documento,
      String telefono,
      String direccion,
    })?
  >
  datosPaciente() async {
    try {
      final cliente = await _cliente;
      final id = await cliente.rpc('mi_usuario_id');
      if (id == null) return null;
      final idInt = id is int ? id : int.tryParse('$id');
      if (idInt == null) return null;

      final filaUsuario = await cliente
          .from('usuario')
          .select('nombre,email,documento,telefono')
          .eq('id_usuario', idInt)
          .maybeSingle();
      if (filaUsuario == null) return null;

      final nombre = (filaUsuario['nombre'] as String?) ?? '';
      final correo = (filaUsuario['email'] as String?) ?? '';
      final documento = (filaUsuario['documento'] as String?) ?? '';
      final telefono = (filaUsuario['telefono'] as String?) ?? '';

      // La columna `direccion` la crea la migracion 20261123. Se lee aparte
      // para que, si aun no esta aplicada, la ficha siga cargando.
      var direccion = '';
      try {
        final filaDireccion = await cliente
            .from('usuario')
            .select('direccion')
            .eq('id_usuario', idInt)
            .maybeSingle();
        direccion = (filaDireccion?['direccion'] as String?) ?? '';
      } catch (_) {}

      bool requiere = false;
      try {
        final filaPaciente = await cliente
            .from('paciente')
            .select('requiere_acompanante')
            .eq('id_paciente', idInt)
            .maybeSingle();
        if (filaPaciente != null) {
          requiere = (filaPaciente['requiere_acompanante'] as bool?) ?? false;
        }
      } catch (_) {}

      return (
        nombre: nombre,
        correo: correo,
        requiereAcompanante: requiere,
        documento: documento,
        telefono: telefono,
        direccion: direccion,
      );
    } on AppConfigException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _errorContacto;

  /// Motivo del ultimo fallo al guardar telefono/direccion.
  String? get errorContacto => _errorContacto;

  /// Actualiza el telefono y la direccion propios en `usuario`.
  ///
  /// Devuelve `true` si se guardo. La politica `usuario_update_own` permite
  /// escribir solo la fila propia; el trigger de la migracion 14 sigue
  /// bloqueando `rol` y `auth_id`, que no se tocan aqui.
  Future<bool> actualizarContacto({
    required String telefono,
    required String direccion,
  }) async {
    _errorContacto = null;
    try {
      final cliente = await _cliente;
      final id = await cliente.rpc('mi_usuario_id');
      final idInt = id is int ? id : int.tryParse('$id');
      if (idInt == null) {
        _errorContacto = 'Tu sesion expiro. Vuelve a iniciar sesion.';
        return false;
      }
      await cliente
          .from('usuario')
          .update(<String, dynamic>{
            'telefono': telefono.trim(),
            'direccion': direccion.trim(),
          })
          .eq('id_usuario', idInt);
      return true;
    } on PostgrestException catch (e) {
      _errorContacto = e.code == '42703'
          ? 'Falta aplicar la migracion de direccion en la base de datos.'
          : 'No se pudo guardar tu informacion. Intenta de nuevo.';
      return false;
    } on AppConfigException {
      _errorContacto = 'Sin conexion a la base de datos.';
      return false;
    } catch (_) {
      _errorContacto = 'No se pudo guardar tu informacion. Intenta de nuevo.';
      return false;
    }
  }

  /// Acompanante vinculado al paciente autenticado (si existe).
  Future<Map<String, dynamic>?> acompanantePropio() async {
    try {
      final id = await idPacienteActual();
      if (id == null) return null;
      final cliente = await _cliente;
      final filas = await cliente
          .from('acompanante')
          .select(
            'id_acompanante,nombre,parentesco,telefono,email,documento,usuario_id',
          )
          .eq('id_paciente', id)
          .limit(1);
      final lista = (filas as List).cast<Map<String, dynamic>>();
      return lista.isEmpty ? null : lista.first;
    } on AppConfigException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Tareas terapeuticas asignadas al paciente autenticado.
  Future<List<Map<String, dynamic>>> tareasPropias() async {
    try {
      final id = await idPacienteActual();
      if (id == null) return <Map<String, dynamic>>[];
      final cliente = await _cliente;
      final filas = await cliente
          .from('tarea_recomendada')
          .select(
            'id_tarea,descripcion,fecha_asignacion,completada,id_psicologo',
          )
          .eq('id_paciente', id)
          .order('fecha_asignacion', ascending: false);
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Evaluaciones (tests) del paciente autenticado, con el nombre del test.
  Future<List<Map<String, dynamic>>> evaluacionesPropias() async {
    try {
      final id = await idPacienteActual();
      if (id == null) return <Map<String, dynamic>>[];
      final cliente = await _cliente;
      final filas = await cliente
          .from('evaluacion_paciente')
          .select(
            'id_evaluacion,fecha_completado,respuestas,'
            'test_psicometrico(nombre,codigo)',
          )
          .eq('id_paciente', id)
          .order('fecha_completado', ascending: false);
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Permisos asignados al usuario autenticado (tabla `permiso`).
  Future<List<Map<String, dynamic>>> permisosPropios() async {
    try {
      final id = await idPacienteActual();
      if (id == null) return <Map<String, dynamic>>[];
      final cliente = await _cliente;
      final filas = await cliente
          .from('permiso')
          .select('tipo_recurso,nivel,ambito')
          .eq('id_sujeto', id)
          .eq('estado', 'ACTIVO');
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Catalogo de tests psicometricos (tabla `test_psicometrico`).
  ///
  /// Es lectura publica: no depende de la sesion. Devuelve vacio si falta la
  /// configuracion de base o falla la red, para que la pantalla avise en vez
  /// de inventar el catalogo.
  Future<List<Map<String, dynamic>>> catalogoTests() async {
    try {
      final cliente = await _cliente;
      final filas = await cliente
          .from('test_psicometrico')
          .select('id_test,codigo,nombre,descripcion')
          .order('nombre', ascending: true);
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// Empresa/convenio del paciente autenticado.
  Future<Map<String, dynamic>?> empresaPropia() async {
    try {
      final id = await idPacienteActual();
      if (id == null) return null;
      final cliente = await _cliente;
      final pac = await cliente
          .from('paciente')
          .select('id_empresa')
          .eq('id_paciente', id)
          .maybeSingle();
      if (pac == null || pac['id_empresa'] == null) return null;
      final emp = await cliente
          .from('empresa')
          .select('id_empresa,nombre,codigo,descripcion')
          .eq('id_empresa', pac['id_empresa'])
          .maybeSingle();
      return emp;
    } on AppConfigException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Proxima cita del paciente autenticado. Una cita cuya hora ya paso no es
  /// «cita programada»: se devuelve `null` para que no se pinte en el panel.
  Future<Map<String, dynamic>?> citaSiguiente() async {
    try {
      final id = await idPacienteActual();
      if (id == null) return null;
      final cliente = await _cliente;
      final filas = await cliente
          .from('cita')
          .select(
            'id_cita,id_psicologo,fecha_hora,estado_cita,modalidad,motivo_consulta',
          )
          .eq('id_paciente', id)
          .order('fecha_hora', ascending: false);
      final lista = (filas as List).cast<Map<String, dynamic>>();
      if (lista.isEmpty) return null;
      final ahora = DateTime.now();
      final futuras =
          lista.where((c) {
            final f = DateTime.tryParse('${c['fecha_hora']}');
            return f != null && !f.isBefore(ahora);
          }).toList()..sort(
            (a, b) => '${a['fecha_hora']}'.compareTo('${b['fecha_hora']}'),
          );
      return futuras.isNotEmpty ? futuras.first : null;
    } on AppConfigException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ultimos seguimientos del paciente (para racha de dias).
  Future<List<Map<String, dynamic>>> seguimientoPropio() async {
    try {
      final id = await idPacienteActual();
      if (id == null) return <Map<String, dynamic>>[];
      final cliente = await _cliente;
      final filas = await cliente
          .from('seguimiento_diario')
          .select(
            'id_registro,nivel_animo,es_critico,comentarios,fecha,fecha_registro',
          )
          .eq('id_paciente', id)
          .order('fecha', ascending: false)
          .limit(7);
      return (filas as List).cast<Map<String, dynamic>>();
    } on AppConfigException {
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  ResultadoLogin _traducir(AuthException e) {
    final codigo = e.code ?? '';
    final mensaje = e.message.toLowerCase();

    if (codigo == 'email_not_confirmed' || mensaje.contains('not confirmed')) {
      return const ResultadoLogin.error(
        FalloDeLogin.correoSinConfirmar,
        'Tu correo aun no esta confirmado. Revisa tu bandeja de entrada.',
      );
    }
    if (codigo == 'weak_password' ||
        mensaje.contains('weak') ||
        mensaje.contains('leaked') ||
        mensaje.contains('breached')) {
      return const ResultadoLogin.error(
        FalloDeLogin.contrasenaFiltrada,
        'Esa contrasena aparece en listas de filtradas. Cambiala por otra.',
      );
    }
    if (codigo == 'invalid_credentials' || mensaje.contains('invalid login')) {
      return const ResultadoLogin.error(
        FalloDeLogin.credenciales,
        'Correo o contrasena incorrectos.',
      );
    }
    if (mensaje.contains('socket') ||
        mensaje.contains('connection') ||
        mensaje.contains('failed to fetch') ||
        mensaje.contains('network') ||
        mensaje.contains('timeout')) {
      return const ResultadoLogin.error(
        FalloDeLogin.red,
        'Sin conexion a la base de datos.',
      );
    }
    return const ResultadoLogin.error(
      FalloDeLogin.desconocido,
      'No pudimos iniciar sesion. Intenta de nuevo.',
    );
  }
}
