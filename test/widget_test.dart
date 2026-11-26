import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mindjora_pacientes/design_system.dart';
import 'package:mindjora_pacientes/main.dart';
import 'package:mindjora_pacientes/paciente_auth.dart';
import 'package:mindjora_pacientes/paciente_agenda.dart';
import 'package:mindjora_pacientes/paciente_detalle_sesion.dart';
import 'package:mindjora_pacientes/paciente_diario.dart';
import 'package:mindjora_pacientes/paciente_inicio.dart';
import 'package:mindjora_pacientes/paciente_notificaciones.dart';
import 'package:mindjora_pacientes/paciente_perfil.dart';
import 'package:mindjora_pacientes/paciente_sala.dart';
import 'package:mindjora_pacientes/paciente_registro.dart';
import 'package:mindjora_pacientes/paciente_tests.dart';
import 'package:mindjora_pacientes/paciente_acompanante.dart';
import 'package:mindjora_pacientes/paciente_chats.dart';
import 'package:mindjora_pacientes/widgets.dart';

/// Directorio que devolvería el RPC cuando la migración está aplicada.
const Map<int, ({String nombre, String? avatarUrl})> directorioPrueba = {
  19: (nombre: 'Dra. Yani Casiani', avatarUrl: null),
  22: (nombre: 'Dr. Andrés Rojas', avatarUrl: null),
  23: (nombre: 'Dra. Laura Méndez', avatarUrl: null),
};

class FakePacienteAuth extends PacienteAuth {
  FakePacienteAuth({
    this.rol = 'PACIENTE',
    this.demo = true,
    this.cita,
    this.tareas = const [],
    this.evaluaciones = const [],
    this.mensajes = const [],
    this.mensajesStream = const Stream<Map<String, dynamic>>.empty(),
    this.acompanante,
    this.empresa,
    this.seguimiento = const [],
    this.catalogo = const [],
    this.psicologos = const [],
    this.disponibilidad = const {},
    this.reserva,
    this.fallarEvaluacion = false,
    this.evaluacionEnEspera,
    this.citas = const [],
    this.permisos = const [],
    this.sinDatos = false,
    this.datosCustom,
    this.directorio = directorioPrueba,
    this.haySesion = false,
  });

  final String? rol;

  /// `true` = la cuenta ve los mockups; `false` = modo real con datos de base.
  final bool demo;

  final Map<String, dynamic>? cita;
  final List<Map<String, dynamic>> tareas;
  final List<Map<String, dynamic>> evaluaciones;
  final List<Map<String, dynamic>> mensajes;
  final Stream<Map<String, dynamic>> mensajesStream;
  final Map<String, dynamic>? acompanante;
  final Map<String, dynamic>? empresa;
  final List<Map<String, dynamic>> seguimiento;
  final List<Map<String, dynamic>> catalogo;
  final List<Map<String, dynamic>> psicologos;
  final Map<int, List<Map<String, dynamic>>> disponibilidad;
  final List<Map<String, dynamic>> permisos;
  final bool sinDatos;
  final ({
    String nombre,
    String correo,
    bool requiereAcompanante,
    String documento,
    String telefono,
    String direccion,
  })?
  datosCustom;

  /// Nombres del directorio del RPC; vacio = sin migracion aplicada.
  final Map<int, ({String nombre, String? avatarUrl})> directorio;

  /// Valor que devuelve la comprobación de sesión guardada al abrir la app.
  final bool haySesion;

  /// Resultado de `reservarSlot`: mapa = cita creada; null = fallo.
  final Map<String, dynamic>? reserva;

  /// Última llamada a `reservarSlot`, para mirar qué ids viajaron de verdad.
  ({int idPsicologo, int idDisponibilidad})? ultimaReserva;

  @override
  Future<ResultadoLogin> iniciarSesion(String correo, String contrasena) async {
    return const ResultadoLogin.ok();
  }

  @override
  Future<String?> rolActual() async => rol;

  @override
  Future<bool> esCuentaDemo() async => demo;

  @override
  Future<void> cerrarSesion() async {}

  @override
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
    cargasDatosPaciente++;
    if (sinDatos) return null;
    return datosCustom ??
        (
          nombre: 'Karen Lucía',
          correo: 'karen.zapata@empresa.com',
          requiereAcompanante: false,
          documento: '',
          telefono: '',
          direccion: '',
        );
  }

  /// Contactos guardados desde el aviso «Completar información».
  final List<({String telefono, String direccion})> contactosGuardados = [];

  /// Mensajes enviados desde la sala.
  final List<({int idPsicologo, String texto})> mensajesEnviados = [];

  @override
  Future<bool> haySesionDePaciente() async => haySesion;

  @override
  Future<Map<int, ({String nombre, String? avatarUrl})>>
  directorioPsicologos() async => directorio;

  @override
  Future<List<Map<String, dynamic>>> mensajesCon(int idPsicologo) async =>
      mensajes
          .where(
            (mensaje) =>
                int.tryParse('${mensaje['id_psicologo'] ?? ''}') == idPsicologo,
          )
          .toList();

  @override
  Future<List<Map<String, dynamic>>> mensajesPaciente() async => mensajes;

  @override
  Stream<Map<String, dynamic>> mensajesEntrantes() => mensajesStream;

  @override
  Future<bool> enviarMensaje(int idPsicologo, String texto) async {
    mensajesEnviados.add((idPsicologo: idPsicologo, texto: texto));
    return true;
  }

  @override
  Future<bool> actualizarContacto({
    required String telefono,
    required String direccion,
  }) async {
    contactosGuardados.add((telefono: telefono, direccion: direccion));
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> permisosPropios() async => permisos;

  /// Veces que se pidió el catálogo; sube con el deslizar para actualizar.
  int cargasCatalogo = 0;

  /// Veces que se pidieron los datos del panel; ídem.
  int cargasDatosPaciente = 0;

  @override
  Future<Map<String, dynamic>?> citaSiguiente() async {
    final proxima = citas.isEmpty ? cita : citas.first;
    if (proxima == null) return null;
    final fecha = DateTime.tryParse('${proxima['fecha_hora'] ?? ''}');
    if (fecha == null || fecha.isBefore(DateTime.now())) return null;
    return proxima;
  }

  @override
  Future<List<Map<String, dynamic>>> tareasPropias() async => tareas;

  @override
  Future<List<Map<String, dynamic>>> evaluacionesPropias() async =>
      <Map<String, dynamic>>[...evaluaciones, ...evaluacionesRegistradas];

  @override
  Future<Map<String, dynamic>?> acompanantePropio() async => acompanante;

  @override
  Future<Map<String, dynamic>?> empresaPropia() async => empresa;

  @override
  Future<String?> avatarPropio() async => avatarRuta;

  @override
  Future<String?> subirAvatar({
    required List<int> bytes,
    required String extension,
  }) async {
    avatarRuta = 'avatar-de-prueba.png';
    return avatarRuta;
  }

  String? avatarRuta;

  @override
  Future<List<Map<String, dynamic>>> seguimientoPropio() async => seguimiento;

  @override
  Future<List<Map<String, dynamic>>> catalogoTests() async {
    cargasCatalogoTests++;
    return catalogo;
  }

  /// Veces que se leyó el catálogo de tests; muestra qué `auth` se usó.
  int cargasCatalogoTests = 0;

  @override
  Future<List<Map<String, dynamic>>> catalogoPsicologos() async {
    cargasCatalogo++;
    return psicologos;
  }

  @override
  Future<List<Map<String, dynamic>>> disponibilidadDe(int idPsicologo) async =>
      disponibilidad[idPsicologo] ?? const [];

  @override
  Future<Map<String, dynamic>?> reservarSlot({
    required int idPsicologo,
    required int idDisponibilidad,
    String modalidad = 'PRESENCIAL',
    String? motivo,
  }) async {
    ultimaReserva = (
      idPsicologo: idPsicologo,
      idDisponibilidad: idDisponibilidad,
    );
    return reserva;
  }

  /// Niveles de ánimo guardados por `guardarSeguimiento`.
  final List<int> animosGuardados = <int>[];

  /// Si se fuerza a false, `guardarEvaluacion` simula un fallo de red.
  final bool fallarEvaluacion;
  final Completer<bool>? evaluacionEnEspera;

  /// Evaluaciones guardadas por `guardarEvaluacion`.
  final List<String> evaluacionesGuardadas = <String>[];
  final List<Map<String, dynamic>> evaluacionesRegistradas =
      <Map<String, dynamic>>[];
  final List<String> tareasTestCompletadas = <String>[];

  String? ultimoComentario;

  @override
  Future<bool> guardarSeguimiento({
    required int nivelAnimo,
    String? comentarios,
    bool esCritico = false,
  }) async {
    animosGuardados.add(nivelAnimo);
    ultimoComentario = comentarios;
    return true;
  }

  /// Citas propias que devuelve `citasPropias()` en modo real.
  final List<Map<String, dynamic>> citas;

  @override
  Future<List<Map<String, dynamic>>> citasPropias() async => citas;

  @override
  Future<bool> guardarEvaluacion({
    required String nombreTest,
    required int puntajeTotal,
    List<int?>? respuestas,
  }) async {
    evaluacionesGuardadas.add(nombreTest);
    final espera = evaluacionEnEspera;
    final guardado = espera == null ? !fallarEvaluacion : await espera.future;
    if (!guardado) return false;
    evaluacionesRegistradas.add(<String, dynamic>{
      'completado': false,
      'fecha_completado': DateTime.now().toIso8601String(),
      'respuestas': respuestas,
      'test_psicometrico': <String, dynamic>{'nombre': nombreTest},
    });
    return true;
  }

  @override
  Future<bool> completarTareaTest(String nombreTest) async {
    final descripcionEsperada = 'Completar test $nombreTest'.toLowerCase();
    final tareasEncontradas = tareas.where(
      (tarea) =>
          '${tarea['descripcion'] ?? ''}'.trim().toLowerCase() ==
          descripcionEsperada,
    );
    if (tareasEncontradas.isEmpty) return false;
    for (final tarea in tareasEncontradas) {
      tarea['completada'] = true;
    }
    tareasTestCompletadas.add(nombreTest);
    return true;
  }
}

void main() {
  /// Monta la app en el tamaño de un móvil y restaura el viewport al final.
  Future<void> pumpOnPhone(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
  }

  /// Monta solo el dashboard, sin pasar por el login.
  ///
  /// Por defecto usa la cuenta demo, que es la que ve los mockups. Para ver la
  /// vista real se le pasa un `FakePacienteAuth` con `demo: false`.
  ///
  /// El dashboard decide el modo y pinta el contenido en `initState`, así que
  /// hace falta un frame más: sin él se queda en el indicador de carga.
  Future<void> pumpDashboard(WidgetTester tester, [PacienteAuth? auth]) async {
    await pumpOnPhone(
      tester,
      MaterialApp(home: PacienteInicioPage(auth: auth ?? FakePacienteAuth())),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Monta solo el perfil, sin pasar por el login. Igual que el dashboard,
  /// decide el modo en `initState` y necesita un frame más.
  Future<void> pumpProfile(WidgetTester tester, [PacienteAuth? auth]) async {
    await pumpOnPhone(
      tester,
      MaterialApp(home: PacientePerfilPage(auth: auth ?? FakePacienteAuth())),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Monta solo el directorio de especialistas (cuenta demo por defecto).
  Future<void> pumpSpecialists(
    WidgetTester tester, [
    PacienteAuth? auth,
  ]) async {
    await pumpOnPhone(
      tester,
      MaterialApp(home: PacienteAgendaPage(auth: auth ?? FakePacienteAuth())),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Monta solo el diario emocional, sin pasar por el login.
  ///
  /// Por defecto usa la cuenta demo, que es la que ve los mockups. Para ver la
  /// vista real se le pasa un `FakePacienteAuth` con `demo: false`. El diario
  /// decide el modo en `initState`, así que necesita un frame más.
  Future<void> pumpDiary(WidgetTester tester, [PacienteAuth? auth]) async {
    await pumpOnPhone(
      tester,
      MaterialApp(home: PacienteDiarioPage(auth: auth ?? FakePacienteAuth())),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Monta solo la batería de tests. Igual que el diario: decide el modo en
  /// `initState` y por defecto usa la cuenta demo.
  Future<void> pumpTests(WidgetTester tester, [PacienteAuth? auth]) async {
    await pumpOnPhone(
      tester,
      MaterialApp(home: PacienteTestsPage(auth: auth ?? FakePacienteAuth())),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpCompanion(WidgetTester tester, [PacienteAuth? auth]) async {
    await pumpOnPhone(
      tester,
      MaterialApp(
        home: PacienteAcompanantePage(auth: auth ?? FakePacienteAuth()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpSala(WidgetTester tester, [PacienteAuth? auth]) async {
    await pumpOnPhone(
      tester,
      MaterialApp(home: PacienteSalaPage(auth: auth ?? FakePacienteAuth())),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Tinta con la que se está pintando un texto, para leer la selección de un
  /// chip, de un día o de una hora sin depender del widget que los envuelve.
  Color? inkOf(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets('el contenido se limita en web y ocupa el ancho del teléfono', (
    WidgetTester tester,
  ) async {
    final childKey = GlobalKey();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveContent(child: SizedBox.expand(key: childKey)),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(childKey)).width, 1120);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.getSize(find.byKey(childKey)).width, 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el panel no desborda en una ventana web amplia', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: PacienteInicioPage(auth: FakePacienteAuth())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Hola, Karen Lucía'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// Tema y tokens con los que está pintándose el saludo del dashboard.
  ({ThemeData theme, PanelTokens tokens}) panelTheme(WidgetTester tester) {
    final context = tester.element(find.text('Hola, Karen Lucía'));
    return (theme: Theme.of(context), tokens: PanelTokens.of(context));
  }

  testWidgets('el login muestra la marca, el acceso y el aviso', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(tester, const MindjoraApp());

    expect(find.text('PORTAL PACIENTE'), findsOneWidget);
    expect(find.text('Mindjora'), findsOneWidget);
    expect(
      find.text('Tu espacio seguro para el bienestar emocional'),
      findsOneWidget,
    );
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('ejemplo@gmail.com'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Recordar sesión en este dispositivo'), findsOneWidget);
    expect(find.text('Iniciar Sesión como Paciente'), findsOneWidget);
    expect(find.text('O continúa con'), findsNothing);
    expect(find.text('Google'), findsNothing);
    expect(
      find.text('¿Problemas para acceder a tu sesión? Contactar soporte'),
      findsNothing,
    );
    expect(find.text('¿Aún no tienes cuenta?'), findsOneWidget);
    expect(find.text('Regístrate como Paciente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una sesión guardada entra al panel sin pedir login', (
    WidgetTester tester,
  ) async {
    final auth = FakePacienteAuth(demo: false, haySesion: true);
    expect(await auth.haySesionDePaciente(), isTrue);

    await pumpOnPhone(tester, MindjoraApp(auth: auth, sesionActiva: true));
    await tester.pumpAndSettle();

    expect(find.text('PORTAL PACIENTE'), findsNothing);
    expect(find.text('¿Cómo te sientes en este momento?'), findsOneWidget);
    expect(find.text('Cita Programada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el login usa el archivo de logo del proyecto', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(tester, const MindjoraApp());

    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as AssetImage).assetName, 'assets/images/logo.jpg');
  });

  testWidgets(
    'el login marca la casilla de sesión y el ojo revela la contraseña',
    (WidgetTester tester) async {
      await pumpOnPhone(tester, const MindjoraApp());

      // Llega marcada, como en el diseño, y la fila entera la alterna.
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(find.text('Recordar sesión en este dispositivo'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

      await tester.enterText(find.byType(TextFormField).last, 'contrasena123');
      await tester.pumpAndSettle();
      // El campo de contraseña es un `EditableText`: ahí vive la propiedad.
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isTrue,
      );

      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el enlace de alta abre el registro de paciente', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(tester, const MindjoraApp());

    // El alta cae por debajo del pliegue: hay que traerla a la vista.
    await tester.ensureVisible(find.text('Regístrate como Paciente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regístrate como Paciente'));
    await tester.pumpAndSettle();

    expect(find.text('Registro de Paciente'), findsOneWidget);
    expect(find.text('Información del Paciente'), findsOneWidget);
    expect(find.text('¿Requiere registro de acompañante?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el registro muestra los datos de cuenta y al acompañante', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(tester, const MaterialApp(home: PacienteRegistroPage()));

    expect(find.text('Registro de Paciente'), findsOneWidget);
    expect(find.text('Paso 1 de 2: Datos de Cuenta'), findsOneWidget);
    expect(find.text('Información del Paciente'), findsOneWidget);
    expect(find.text(' (solo números, máx. 10)'), findsNWidgets(3));
    expect(find.text('Crear Contraseña'), findsOneWidget);
    expect(
      find.text('Reglas: alfanumérico, mínimo 8 caracteres'),
      findsOneWidget,
    );
    expect(find.text('¿Requiere registro de acompañante?'), findsOneWidget);
    expect(find.text('Datos de la persona autorizada'), findsOneWidget);
    expect(find.text('Relación con el paciente'), findsOneWidget);
    expect(find.text('Completar Registro de Paciente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('documentos y teléfono aceptan solo 10 dígitos como máximo', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(tester, const MaterialApp(home: PacienteRegistroPage()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    final documento = tester.widget<TextFormField>(fields.at(1));
    final telefono = tester.widget<TextFormField>(fields.at(3));
    final documentoAcompanante = tester.widget<TextFormField>(fields.at(6));

    await tester.enterText(fields.at(1), '12a345678901');
    await tester.enterText(fields.at(3), '+57 30012345678');
    await tester.enterText(fields.at(6), '14.520.118-2');

    expect(documento.controller!.text, '1234567890');
    expect(telefono.controller!.text, '5730012345');
    expect(documentoAcompanante.controller!.text, '145201182');
    expect(tester.takeException(), isNull);
  });

  testWidgets('el registro rechaza correos con formato inválido', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(tester, const MaterialApp(home: PacienteRegistroPage()));
    await tester.pumpAndSettle();

    final correo = find.byType(TextFormField).at(2);
    await tester.enterText(correo, 'persona@dominio');
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);

    await tester.enterText(correo, 'persona@dominio.com');
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo válido'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al apagar el acompañante se oculta su bloque', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(tester, const MaterialApp(home: PacienteRegistroPage()));

    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Datos de la persona autorizada'), findsNothing);
    expect(find.text('¿Requiere registro de acompañante?'), findsOneWidget);
  });

  testWidgets('el login entra al dashboard con credenciales válidas', (
    WidgetTester tester,
  ) async {
    final fake = FakePacienteAuth();
    await pumpOnPhone(tester, MindjoraApp(auth: fake));

    await tester.enterText(
      find.byType(TextFormField).first,
      'karen@correo.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'contrasena123');
    await tester.tap(find.text('Iniciar Sesión como Paciente'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Karen Lucía'), findsOneWidget);
    expect(find.text('Cita Programada'), findsOneWidget);
    expect(find.text('Estado y Evaluaciones'), findsOneWidget);
    expect(find.text('Tareas Terapéuticas de Hoy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el dashboard muestra la cita, el estado y las tareas', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    // Cabecera y saludo.
    expect(find.text('MINDJORA'), findsOneWidget);
    // «Inicio» sale dos veces: el título de la cabecera y la pestaña inferior.
    expect(find.text('Inicio'), findsNWidgets(2));
    expect(find.text('¿Cómo te sientes en este momento?'), findsOneWidget);

    // Los cinco niveles de ánimo, con «En calma» seleccionado de inicio.
    for (final mood in [
      'Radiante',
      'En calma',
      'Neutral',
      'Sobrecarga',
      'Inquietud',
    ]) {
      expect(find.text(mood), findsOneWidget);
    }

    // Cita programada.
    expect(find.text('En 3 horas'), findsOneWidget);
    expect(find.text('Terapia Individual'), findsOneWidget);
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Psicóloga Clínica • Enfoque TCC'), findsOneWidget);
    expect(find.text('Hoy, 18:30 hrs'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
    expect(
      find.text('Test pre-consulta completado correctamente'),
      findsOneWidget,
    );
    expect(find.text('Entrar a Sala Virtual'), findsOneWidget);
    expect(find.text('Detalles de la cita'), findsOneWidget);

    // Estado y evaluaciones.
    expect(find.text('Septiembre 2026'), findsOneWidget);
    expect(
      find.text(
        'Los resultados de tus tests son confidenciales y serán revisados '
        'por tu psicólogo.',
      ),
      findsOneWidget,
    );
    expect(find.text('6 / 27'), findsNothing);
    expect(find.text('4 / 21'), findsNothing);
    expect(find.text('Batería psicométrica periódica'), findsOneWidget);
    expect(find.text('En 4 días'), findsOneWidget);

    // Tareas terapéuticas.
    expect(find.text('1 de 2 listas'), findsOneWidget);
    expect(find.text('Respiración diafrágmica'), findsOneWidget);
    expect(find.text('Completado • 5 min'), findsOneWidget);
    expect(find.text('Registro de pensamiento'), findsOneWidget);
    expect(find.text('Técnica ABC de reestructuración'), findsOneWidget);
    expect(find.text('Realizar'), findsOneWidget);

    // Acompañante vinculado.
    expect(find.text('Acompañante Vinculado'), findsOneWidget);
    expect(find.text('ACTIVO'), findsOneWidget);

    // Navegación inferior («Inicio» ya se comprobó arriba).
    for (final tab in ['Agenda', 'Diario', 'Perfil']) {
      expect(find.text(tab), findsOneWidget);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('notificaciones y sala muestran las citas reales', (
    WidgetTester tester,
  ) async {
    final cita = <String, dynamic>{
      'id_cita': 7,
      'id_psicologo': 19,
      'fecha_hora': '2030-01-01T10:30:00+00:00',
      'estado_cita': 'CONFIRMADA',
      'modalidad': 'VIDEO',
      'motivo_consulta': 'Sesión de prueba',
    };
    final auth = FakePacienteAuth(
      demo: false,
      citas: <Map<String, dynamic>>[cita],
    );

    await pumpOnPhone(
      tester,
      MaterialApp(home: PacienteNotificacionesPage(auth: auth)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('ALERTA PRIORITARIA • INASISTENCIA'), findsNothing);
    expect(find.textContaining('Cita confirmada'), findsOneWidget);

    await pumpOnPhone(tester, MaterialApp(home: PacienteSalaPage(auth: auth)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Profesional #19'), findsNothing);
    expect(find.textContaining('01/01'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('el ánimo del panel se guarda en modo real', (
    WidgetTester tester,
  ) async {
    final auth = FakePacienteAuth(demo: false);
    await pumpDashboard(tester, auth);

    await tester.ensureVisible(find.text('Inquietud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inquietud'));
    await tester.pumpAndSettle();

    expect(auth.animosGuardados, isNotEmpty);
    expect(auth.ultimoComentario, isNull);
    expect(find.text('Ánimo guardado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al tocar un ánimo se selecciona y descuenta los anteriores', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    /// Fondo del chip: el seleccionado usa la tinta de acento.
    Color moodBg(String label) => tester
        .widget<Material>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        )
        .color!;

    const accent = AppColors.brandSoft;
    // Los chips sin seleccionar no tienen fondo propio: se ve la tarjeta.
    const unselected = Colors.transparent;
    expect(moodBg('En calma'), accent);
    expect(moodBg('Neutral'), unselected);

    // «Inquietud» queda fuera de pantalla: hay que traerlo a la vista.
    await tester.ensureVisible(find.text('Inquietud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inquietud'));
    await tester.pumpAndSettle();

    expect(moodBg('Inquietud'), accent);
    expect(moodBg('En calma'), unselected);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el panel no muestra botones de tema ni acceso al perfil', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    expect(panelTheme(tester).theme.brightness, Brightness.light);
    expect(panelTheme(tester).tokens.canvas, AppColors.canvas);
    expect(find.byTooltip('Cambiar a modo oscuro'), findsNothing);
    expect(find.byTooltip('Cambiar a modo claro'), findsNothing);
    expect(find.byTooltip('Mi perfil'), findsNothing);
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- Directorio de especialistas ----------------------------------------

  testWidgets('el directorio muestra los dos especialistas de la captura', (
    WidgetTester tester,
  ) async {
    await pumpSpecialists(tester);

    // Cabecera y bloque de entrada.
    expect(find.text('MINDJORA'), findsOneWidget);
    expect(find.text('Especialistas'), findsOneWidget);
    expect(find.text('CUIDADO CLÍNICO'), findsOneWidget);
    expect(find.text('24 especialistas disponibles'), findsOneWidget);
    expect(find.text('Especialistas verificados'), findsOneWidget);
    expect(find.text('Buscar por nombre, motivo o enfoque...'), findsOneWidget);

    // Modalidad y especialidades.
    expect(find.text('En línea (Videollamada)'), findsOneWidget);
    expect(find.text('Presencial'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Ansiedad y Estrés'), findsOneWidget);
    // «TCC» sale dos veces: en el filtro y en las etiquetas de la primera
    // tarjeta, así que aquí no se puede afirmar que aparezca una sola vez.
    expect(find.text('TCC'), findsNWidgets(2));
    expect(find.text('Autoestima'), findsOneWidget);

    // Tira de fechas.
    expect(find.text('Seleccionar fecha preferida'), findsOneWidget);
    expect(find.text('Septiembre 2026'), findsOneWidget);
    for (final day in ['24', '25', '26', '27', '28', '29']) {
      expect(find.text(day), findsOneWidget);
    }

    // Tarjetas.
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('(128)'), findsOneWidget);
    expect(
      find.text('Psicóloga Clínica Sanitaria • 8 años exp.'),
      findsOneWidget,
    );
    expect(find.text('Convenio Empresa Disponible'), findsOneWidget);
    expect(find.text('Disponibilidad hoy (Mar 25):'), findsOneWidget);
    expect(find.text('Zona horaria local'), findsOneWidget);
    expect(find.text('+2 más'), findsOneWidget);
    expect(find.text('\$40 Mil COP'), findsOneWidget);
    expect(find.text('/ sesión'), findsNWidgets(2));
    expect(find.text('\$45.000 COP aprox.'), findsOneWidget);
    expect(find.text('Lic. Oscar Flerez'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('(94)'), findsOneWidget);
    expect(
      find.text('Psicoterapeuta Integrativo • 6 años exp.'),
      findsOneWidget,
    );
    expect(find.text('Enfoque Contextual y ACT'), findsOneWidget);
    expect(find.text('Disponibilidad mañana (Mié 26):'), findsOneWidget);
    expect(find.text('Sesión 50 min'), findsOneWidget);
    expect(find.text('\$30 Mil COP'), findsOneWidget);
    expect(find.text('\$42.000 COP aprox.'), findsOneWidget);
    expect(find.text('Reservar Cita'), findsNWidgets(2));

    // Navegación con «Agenda» marcada.
    for (final tab in ['Inicio', 'Agenda', 'Diario', 'Perfil']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(inkOf(tester, 'Agenda'), AppColors.brand);
    expect(inkOf(tester, 'Inicio'), AppColors.textFaint);

    expect(tester.takeException(), isNull);
  });

  testWidgets('el buscador filtra por nombre, motivo o enfoque', (
    WidgetTester tester,
  ) async {
    await pumpSpecialists(tester);

    // Por nombre.
    await tester.enterText(find.byType(TextField), 'casiani');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Lic. Oscar Flerez'), findsNothing);

    // Por enfoque: «Depresión» solo aparece en las etiquetas de la segunda.
    await tester.enterText(find.byType(TextField), 'depresión');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Yani Casiani'), findsNothing);
    expect(find.text('Lic. Oscar Flerez'), findsOneWidget);

    // Por rol.
    await tester.enterText(find.byType(TextField), 'integrativo');
    await tester.pumpAndSettle();
    expect(find.text('Lic. Oscar Flerez'), findsOneWidget);

    // Sin coincidencias: estado vacío con su salida.
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Sin especialistas'), findsOneWidget);
    expect(find.text('Dra. Yani Casiani'), findsNothing);

    await tester.ensureVisible(find.text('Limpiar búsqueda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar búsqueda'));
    await tester.pumpAndSettle();
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Lic. Oscar Flerez'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el directorio real muestra los psicólogos de la base y filtra', (
    WidgetTester tester,
  ) async {
    await pumpSpecialists(
      tester,
      FakePacienteAuth(
        demo: false,
        psicologos: <Map<String, dynamic>>[
          <String, dynamic>{
            'id_psicologo': 19,
            'tarifa_base': 32585,
            'es_independiente': true,
            'id_empresa': null,
          },
          <String, dynamic>{
            'id_psicologo': 23,
            'tarifa_base': 0,
            'es_independiente': false,
            'id_empresa': null,
          },
        ],
        disponibilidad: <int, List<Map<String, dynamic>>>{
          19: <Map<String, dynamic>>[
            <String, dynamic>{
              'id_disponibilidad': 9,
              'fecha_hora_inicio': '2026-11-20T19:00:00Z',
              'estado': 'DISPONIBLE',
            },
          ],
        },
      ),
    );

    // Los profesionales reales salen con nombre y foto del directorio.
    expect(find.text('2 especialistas disponibles'), findsOneWidget);
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Dra. Laura Méndez'), findsOneWidget);
    expect(find.text('Profesional #19'), findsNothing);
    expect(find.text('Septiembre 2026'), findsNothing);
    expect(
      find.text(
        'Catálogo real de la base, con el nombre y la foto del '
        'directorio de psicólogos.',
      ),
      findsOneWidget,
    );
    expect(find.text('19:00'), findsOneWidget);
    expect(find.text(r'$32585'), findsOneWidget);

    // El buscador filtra también sobre los datos reales (horas incluidas).
    await tester.enterText(find.byType(TextField), 'Yani');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Dra. Laura Méndez'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Laura');
    await tester.pumpAndSettle();
    expect(find.text('Dra. Laura Méndez'), findsOneWidget);
    expect(find.text('Dra. Yani Casiani'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('reservar de verdad crea la cita y vuelve a la agenda', (
    WidgetTester tester,
  ) async {
    final auth = FakePacienteAuth(
      demo: false,
      reserva: <String, dynamic>{'id_cita': 7},
    );
    await pumpOnPhone(
      tester,
      MaterialApp(
        home: PacienteDetalleSesionPage(
          auth: auth,
          reserva: SesionReserva(
            specialistName: 'Profesional #19',
            initials: 'P19',
            role: 'Psicólogo/a de la base',
            rating: '',
            reviews: '',
            focus: 'General',
            dateLabel: 'Profesional #19',
            startTime: '19:00',
            idPsicologo: 19,
            idDisponibilidad: 9,
            modalidad: 'VIDEO',
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Confirmar y Congelar Cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar y Congelar Cita'));
    await tester.pumpAndSettle();
    expect(
      find.text('Cita reservada: Profesional #19, 19:00 hrs.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el detalle real muestra la tarifa de la base, sin datos de pago inventados',
    (WidgetTester tester) async {
      await pumpOnPhone(
        tester,
        MaterialApp(
          home: PacienteDetalleSesionPage(
            auth: FakePacienteAuth(demo: false),
            reserva: SesionReserva(
              specialistName: 'Profesional #19',
              initials: 'P19',
              role: 'Psicólogo/a de la base',
              rating: '',
              reviews: '',
              focus: 'General',
              dateLabel: 'Profesional #19',
              startTime: '19:00',
              idPsicologo: 19,
              idDisponibilidad: 9,
              tarifa: 50000,
            ),
          ),
        ),
      );

      expect(find.text(r'$50.000 COP'), findsOneWidget);
      expect(find.text('Tarifa de la consulta'), findsOneWidget);
      expect(find.text('InnovaTech S.A.'), findsNothing);
      expect(find.text('Beneficio Corporativo Activo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reservar de verdad avisa el fallo y no finge éxito', (
    WidgetTester tester,
  ) async {
    await pumpOnPhone(
      tester,
      MaterialApp(
        home: PacienteDetalleSesionPage(
          auth: FakePacienteAuth(demo: false),
          reserva: SesionReserva(
            specialistName: 'Profesional #19',
            initials: 'P19',
            role: 'Psicólogo/a de la base',
            rating: '',
            reviews: '',
            focus: 'General',
            dateLabel: 'Profesional #19',
            startTime: '19:00',
            idPsicologo: 19,
            idDisponibilidad: 9,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Confirmar y Congelar Cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar y Congelar Cita'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo reservar la cita. El horario puede estar tomado.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el directorio real avisa cuando la base está vacía', (
    WidgetTester tester,
  ) async {
    await pumpSpecialists(tester, FakePacienteAuth(demo: false));
    expect(
      find.text('No hay profesionales registrados en la base de datos.'),
      findsOneWidget,
    );
    expect(find.text('24 especialistas disponibles'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  /// Catálogo real con dos días libres (25 nov y 1 dic) y un profesional
  /// sin huecos, que es lo que deja la herramienta de horarios semanales.
  FakePacienteAuth agendaConDias() => FakePacienteAuth(
    demo: false,
    psicologos: <Map<String, dynamic>>[
      <String, dynamic>{
        'id_psicologo': 19,
        'tarifa_base': 32585,
        'es_independiente': true,
        'id_empresa': null,
      },
      <String, dynamic>{
        'id_psicologo': 23,
        'tarifa_base': 0,
        'es_independiente': false,
        'id_empresa': null,
      },
    ],
    disponibilidad: <int, List<Map<String, dynamic>>>{
      19: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_disponibilidad': 41,
          'fecha_hora_inicio': '2026-11-25T15:00:00Z',
          'estado': 'DISPONIBLE',
        },
        <String, dynamic>{
          'id_disponibilidad': 42,
          'fecha_hora_inicio': '2026-11-25T16:00:00Z',
          'estado': 'DISPONIBLE',
        },
        <String, dynamic>{
          'id_disponibilidad': 51,
          'fecha_hora_inicio': '2026-12-01T10:00:00Z',
          'estado': 'DISPONIBLE',
        },
      ],
    },
    reserva: <String, dynamic>{'id_cita': 9},
  );

  testWidgets('la tira real ofrece solo los días con huecos y cada día '
      'muestra sus horas', (WidgetTester tester) async {
    await pumpSpecialists(tester, agendaConDias());

    // La tira trae los días que tienen huecos, no los de la captura.
    expect(find.text('Septiembre 2026'), findsNothing);
    expect(find.text('Noviembre 2026'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('24'), findsNothing);

    // Primer día (25 nov): sus dos horas y no la del día siguiente. El
    // rótulo es igual en las dos tarjetas (comparten el día elegido).
    expect(find.text('Disponibilidad MIÉ 25:'), findsNWidgets(2));
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
    expect(find.text('10:00'), findsNothing);

    // El profesional sin huecos lo dice en vez de ofrecer horas.
    expect(find.text('Este día no tiene horas libres.'), findsOneWidget);

    // Cambiar de día reescribe las horas con las del día elegido.
    await tester.ensureVisible(find.text('01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();
    expect(find.text('Diciembre 2026'), findsOneWidget);
    expect(find.text('Disponibilidad MAR 1:'), findsNWidgets(2));
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('15:00'), findsNothing);
    expect(find.text('16:00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la reserva del día elegido viaja con su id_disponibilidad y '
      'su fecha', (WidgetTester tester) async {
    final auth = agendaConDias();
    await pumpSpecialists(tester, auth);

    // Elegir una hora del 25 nov.
    await tester.ensureVisible(find.text('15:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15:00'));
    await tester.pumpAndSettle();

    // Cambiar de día borra la hora elegida: era de otro día.
    await tester.ensureVisible(find.text('01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('01'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reservar Cita').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar Cita').first);
    await tester.pumpAndSettle();
    expect(find.text('Elige una hora para reservar tu cita.'), findsOneWidget);
    // Se va solo: tapa la parte baja y los siguientes toques irían al aviso.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Con hora del 1 dic, el detalle nombra ese día.
    await tester.ensureVisible(find.text('10:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reservar Cita').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar Cita').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Martes 1 de Diciembre • 10:00 - 10:50 hrs'),
      findsOneWidget,
    );

    // Confirmar manda el id del hueco de ese día, no el de otro.
    await tester.ensureVisible(find.text('Confirmar y Congelar Cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar y Congelar Cita'));
    await tester.pumpAndSettle();
    expect(
      find.text('Cita reservada: Martes 1 de Diciembre, 10:00 hrs.'),
      findsOneWidget,
    );
    expect(auth.ultimaReserva, (idPsicologo: 19, idDisponibilidad: 51));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la tira real avisa si ningún profesional dejó huecos', (
    WidgetTester tester,
  ) async {
    await pumpSpecialists(
      tester,
      FakePacienteAuth(
        demo: false,
        psicologos: <Map<String, dynamic>>[
          <String, dynamic>{
            'id_psicologo': 19,
            'tarifa_base': 32585,
            'es_independiente': true,
            'id_empresa': null,
          },
        ],
      ),
    );
    expect(
      find.text('Ningún profesional tiene horarios libres por ahora.'),
      findsOneWidget,
    );
    expect(find.text('Seleccionar fecha preferida'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deslizar para actualizar vuelve a consultar la agenda', (
    WidgetTester tester,
  ) async {
    final auth = agendaConDias();
    await pumpSpecialists(tester, auth);
    expect(auth.cargasCatalogo, 1);

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 400),
      1500,
    );
    await tester.pumpAndSettle();
    expect(auth.cargasCatalogo, greaterThan(1));
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deslizar para actualizar vuelve a consultar el panel', (
    WidgetTester tester,
  ) async {
    final auth = FakePacienteAuth(demo: false);
    await pumpDashboard(tester, auth);
    expect(auth.cargasDatosPaciente, 1);

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 400),
      1500,
    );
    await tester.pumpAndSettle();
    expect(auth.cargasDatosPaciente, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('actualizar los tests no borra lo que ibas respondiendo', (
    WidgetTester tester,
  ) async {
    await pumpTests(
      tester,
      FakePacienteAuth(
        demo: false,
        tareas: <Map<String, dynamic>>[
          <String, dynamic>{
            'descripcion': 'Completar test PHQ-9',
            'completada': false,
          },
        ],
        catalogo: <Map<String, dynamic>>[
          <String, dynamic>{
            'id_test': 4,
            'nombre': 'PHQ-9',
            'descripcion': 'Índice de depresión',
          },
        ],
      ),
    );
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);

    await tester.ensureVisible(find.text('Varios días'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Varios días'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siguiente Pregunta'));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 400),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 2 de 9'), findsOneWidget);
    await tester.ensureVisible(find.text('Anterior'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(inkOf(tester, 'Varios días'), AppColors.brandDark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inicio del directorio vuelve al panel y Perfil no rompe nada', (
    WidgetTester tester,
  ) async {
    // Desde el login, que es la primera ruta: es donde se colgaba «Inicio» y
    // devolvía al login en vez de al panel.
    final fake = FakePacienteAuth();
    await pumpOnPhone(tester, MindjoraApp(auth: fake));
    await tester.enterText(
      find.byType(TextFormField).first,
      'karen@correo.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'contrasena123');
    await tester.tap(find.text('Iniciar Sesión como Paciente'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Especialistas verificados'), findsOneWidget);

    // «Inicio» deshace solo el empuje del directorio: queda el panel, no el login.
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Karen Lucía'), findsOneWidget);
    expect(find.text('Especialistas verificados'), findsNothing);
    expect(find.text('Iniciar Sesión como Paciente'), findsNothing);

    // «Perfil» abre el perfil del paciente sin apilar rutas.
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Mi Perfil'), findsOneWidget);
    expect(inkOf(tester, 'Perfil'), AppColors.brand);
    expect(tester.takeException(), isNull);

    expect(find.text('Red de Apoyo y Acompañante'), findsNothing);
    expect(find.text('Portal del Acompañante'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modalidad, especialidad, día y hora mueven su selección', (
    WidgetTester tester,
  ) async {
    await pumpSpecialists(tester);

    // Modalidad: «Online (Videollamada)» sale marcada.
    expect(inkOf(tester, 'En línea (Videollamada)'), AppColors.ink);
    expect(inkOf(tester, 'Presencial'), AppColors.inkSoft);
    await tester.tap(find.text('Presencial'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, 'Presencial'), AppColors.ink);
    expect(inkOf(tester, 'En línea (Videollamada)'), AppColors.inkSoft);

    // Especialidad: llega marcada «Ansiedad y Estrés».
    expect(inkOf(tester, 'Ansiedad y Estrés'), Colors.white);
    expect(inkOf(tester, 'Autoestima'), AppColors.ink);
    await tester.ensureVisible(find.text('Autoestima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Autoestima'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, 'Autoestima'), Colors.white);
    expect(inkOf(tester, 'Ansiedad y Estrés'), AppColors.ink);

    // Día: llega marcado el 25.
    expect(inkOf(tester, '25'), Colors.white);
    expect(inkOf(tester, '26'), AppColors.ink);
    await tester.ensureVisible(find.text('26'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('26'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, '26'), Colors.white);
    expect(inkOf(tester, '25'), AppColors.ink);

    // Hora: elegirla la marca en verde y solo una por tarjeta.
    expect(inkOf(tester, '16:00'), AppColors.ink);
    await tester.ensureVisible(find.text('16:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('16:00'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, '16:00'), AppColors.brandDark);
    expect(inkOf(tester, '18:30'), AppColors.ink);
    await tester.tap(find.text('18:30'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, '18:30'), AppColors.brandDark);
    expect(inkOf(tester, '16:00'), AppColors.ink);

    expect(tester.takeException(), isNull);
  });

  // --- Diario emocional ---------------------------------------------------

  testWidgets('el diario muestra la semana, el registro y la evolución', (
    WidgetTester tester,
  ) async {
    await pumpDiary(tester);

    // Cabecera y entrada. «Diario» sale dos veces: el título y la pestaña.
    expect(find.text('MINDJORA'), findsOneWidget);
    expect(find.text('Diario'), findsNWidgets(2));
    expect(find.text('Fase 4 · Acompañamiento Activo'), findsOneWidget);
    expect(find.text('Diario Emocional y Actividades'), findsOneWidget);

    // Semana en curso.
    expect(find.text('Semana en curso'), findsOneWidget);
    expect(find.text('5 días constantes'), findsOneWidget);
    for (final day in ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM']) {
      expect(find.text(day), findsOneWidget);
    }
    for (final mood in ['Calma', 'Sereno', 'Bajo', 'Vital']) {
      expect(find.text(mood), findsOneWidget);
    }
    // «Hoy» sale dos veces: la casilla del viernes y la píldora del registro.
    expect(find.text('Hoy'), findsNWidgets(2));

    // Registro rápido.
    expect(find.text('Registro Rápido de Ánimo'), findsOneWidget);
    expect(find.text('¿Cómo se percibe tu cuerpo hoy?'), findsOneWidget);
    expect(find.text('Nivel de energía anímica'), findsOneWidget);
    expect(find.text('Calma moderada'), findsOneWidget);
    expect(find.text('Agotamiento'), findsOneWidget);
    expect(find.text('Equilibrio'), findsOneWidget);
    expect(find.text('Vitalidad alta'), findsOneWidget);
    expect(find.text('Desencadenantes y emociones sentidas'), findsOneWidget);
    for (final feeling in [
      'Ansiedad laboral',
      'Gratitud',
      'Cansancio',
      'Logro personal',
      'Sobrecarga',
    ]) {
      expect(find.text(feeling), findsOneWidget);
    }
    expect(find.text('Reflexión breve'), findsOneWidget);
    expect(find.text('Opcional'), findsOneWidget);
    expect(find.text('Anotar pensamientos del momento...'), findsOneWidget);
    expect(find.text('Guardar Registro de Hoy'), findsOneWidget);

    // Las tareas se gestionan desde el panel, no desde el diario.
    expect(find.text('Tareas Asignadas'), findsNothing);
    expect(
      find.text('Registro de Pensamiento Disfuncional (Modelo ABC)'),
      findsNothing,
    );
    expect(find.text('Caminata consciente y grounding'), findsNothing);
    expect(find.text('Higiene de sueño y descanso'), findsNothing);

    // Evolución, con el mismo eje que la tira de la semana.
    expect(find.text('Evolución del Estado de Ánimo'), findsOneWidget);
    expect(
      find.text('Tendencia semanal de serenidad y valencia'),
      findsOneWidget,
    );
    for (final day in ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

    // Navegación con «Diario» marcado: usa el icono activo de la barra común.
    for (final tab in ['Inicio', 'Agenda', 'Perfil']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('en el diario se eligen las emociones y el nivel de energía', (
    WidgetTester tester,
  ) async {
    await pumpDiary(tester);

    // «Gratitud» llega marcada, como en el diseño; el resto, no.
    await tester.ensureVisible(find.text('Cansancio'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, 'Gratitud'), Colors.white);
    expect(inkOf(tester, 'Cansancio'), AppColors.ink);
    await tester.tap(find.text('Cansancio'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, 'Cansancio'), Colors.white);
    await tester.tap(find.text('Gratitud'));
    await tester.pumpAndSettle();
    expect(inkOf(tester, 'Gratitud'), AppColors.ink);

    // El deslizador llega en «Calma moderada»; arrastrarlo al final lo cambia.
    await tester.ensureVisible(find.byType(Slider));
    await tester.pumpAndSettle();
    expect(find.text('Calma moderada'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Calma moderada'), findsNothing);
    // «Vitalidad alta» sale dos veces: el extremo de la escala y la píldora.
    expect(find.text('Vitalidad alta'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('guardar el registro de hoy avisa con un mensaje', (
    WidgetTester tester,
  ) async {
    await pumpDiary(tester);

    await tester.ensureVisible(find.text('Guardar Registro de Hoy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar Registro de Hoy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Registro de hoy guardado.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'las pestañas llevan al diario, a la agenda y de vuelta al panel',
    (WidgetTester tester) async {
      await pumpDashboard(tester);

      await tester.tap(find.text('Diario'));
      await tester.pumpAndSettle();
      expect(find.text('Diario Emocional y Actividades'), findsOneWidget);

      // «Agenda» sustituye al diario en vez de apilarse sobre él.
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Especialistas verificados'), findsOneWidget);
      expect(find.text('Diario Emocional y Actividades'), findsNothing);

      await tester.tap(find.text('Diario'));
      await tester.pumpAndSettle();
      expect(find.text('Diario Emocional y Actividades'), findsOneWidget);
      expect(find.text('Especialistas verificados'), findsNothing);

      // «Inicio» deshace un solo empuje: queda el panel, no la agenda.
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, Karen Lucía'), findsOneWidget);
      expect(find.text('Diario Emocional y Actividades'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la pestaña Agenda del panel abre el directorio', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    expect(find.text('Especialistas verificados'), findsOneWidget);
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(inkOf(tester, 'Agenda'), AppColors.brand);
    expect(tester.takeException(), isNull);
  });

  // --- Modo demo y modo real ---------------------------------------------

  testWidgets('la cuenta demo del panel sigue viendo los mockups', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, FakePacienteAuth(demo: true));

    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Septiembre 2026'), findsOneWidget);
    expect(find.text('En 3 horas'), findsOneWidget);
    expect(find.text('Aún no tienes citas programadas.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el modo real del panel avisa donde antes había datos inventados',
    (WidgetTester tester) async {
      await pumpDashboard(tester, FakePacienteAuth(demo: false));

      // Sin cita futura, la sección de cita desaparece por completo.
      expect(find.text('Aún no tienes citas programadas.'), findsNothing);
      expect(find.text('Cita Programada'), findsNothing);
      expect(
        find.text('Aún no tienes evaluaciones registradas.'),
        findsOneWidget,
      );
      expect(find.text('No tienes tareas pendientes.'), findsOneWidget);
      expect(find.text('Aún no tienes acompañante vinculado.'), findsOneWidget);

      // Nada de la captura.
      expect(find.text('Dra. Yani Casiani'), findsNothing);
      expect(find.text('Septiembre 2026'), findsNothing);
      expect(find.textContaining('Oscar Flerez'), findsNothing);
      expect(find.text('Sin conexion a la base de datos.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'las respuestas completas cierran las tareas aunque el estado no se actualice',
    (WidgetTester tester) async {
      final tests = ['AQ-10', 'GAD-7', 'PHQ-9'];
      final totalPreguntas = [10, 7, 9];
      await pumpDashboard(
        tester,
        FakePacienteAuth(
          demo: false,
          tareas: [
            for (var i = 0; i < tests.length; i++)
              <String, dynamic>{
                'id_tarea': i + 1,
                'descripcion': 'Completar test ${tests[i]}',
                'completada': false,
                'fecha_asignacion': '2026-11-24T10:00:00Z',
              },
          ],
          evaluaciones: [
            for (var i = 0; i < tests.length; i++)
              <String, dynamic>{
                'id_evaluacion': i + 1,
                'completado': false,
                'fecha_completado': '2026-11-25T10:00:00Z',
                'respuestas': List<int>.filled(totalPreguntas[i], 0),
                'test_psicometrico': <String, dynamic>{'nombre': tests[i]},
              },
          ],
        ),
      );

      expect(find.text('No tienes tareas pendientes.'), findsOneWidget);
      expect(find.textContaining('Completar test '), findsNothing);
      expect(find.text('Pendiente'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'una evaluación anterior a la asignación no completa una tarea nueva',
    (WidgetTester tester) async {
      await pumpDashboard(
        tester,
        FakePacienteAuth(
          demo: false,
          tareas: <Map<String, dynamic>>[
            <String, dynamic>{
              'descripcion': 'Completar test PHQ-9',
              'completada': false,
              'fecha_asignacion': '2026-11-26T10:00:00Z',
            },
          ],
          evaluaciones: <Map<String, dynamic>>[
            <String, dynamic>{
              'completado': true,
              'fecha_completado': '2026-11-25T10:00:00Z',
              'respuestas': List<int>.filled(9, 0),
              'test_psicometrico': <String, dynamic>{'nombre': 'PHQ-9'},
            },
          ],
        ),
      );

      expect(find.text('Completar test PHQ-9'), findsOneWidget);
      expect(find.text('Pendiente'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'una evaluación del mismo día completa la tarea pese al desfase horario',
    (WidgetTester tester) async {
      await pumpDashboard(
        tester,
        FakePacienteAuth(
          demo: false,
          tareas: <Map<String, dynamic>>[
            <String, dynamic>{
              'descripcion': 'Completar test PHQ-9',
              'completada': false,
              'fecha_asignacion': '2026-11-26T14:00:00Z',
            },
          ],
          evaluaciones: <Map<String, dynamic>>[
            <String, dynamic>{
              'completado': true,
              'fecha_completado': '2026-11-26T09:19:00Z',
              'respuestas': List<int>.filled(9, 0),
              'test_psicometrico': <String, dynamic>{'nombre': 'PHQ-9'},
            },
          ],
        ),
      );

      expect(find.text('No tienes tareas pendientes.'), findsOneWidget);
      expect(find.textContaining('Completar test '), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'una respuesta sin contestar mantiene pendiente la tarea del test',
    (WidgetTester tester) async {
      await pumpDashboard(
        tester,
        FakePacienteAuth(
          demo: false,
          tareas: <Map<String, dynamic>>[
            <String, dynamic>{
              'descripcion': 'Completar test PHQ-9',
              'completada': true,
              'fecha_asignacion': '2026-11-24T10:00:00Z',
            },
          ],
          evaluaciones: <Map<String, dynamic>>[
            <String, dynamic>{
              'completado': true,
              'fecha_completado': '2026-11-25T10:00:00Z',
              'respuestas': <int?>[0, 0, 0, 0, 0, 0, 0, 0, null],
              'test_psicometrico': <String, dynamic>{'nombre': 'PHQ-9'},
            },
          ],
        ),
      );

      expect(find.text('Completar test PHQ-9'), findsOneWidget);
      expect(find.text('Pendiente'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('una lista incompleta de respuestas no cierra el test', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      FakePacienteAuth(
        demo: false,
        tareas: <Map<String, dynamic>>[
          <String, dynamic>{
            'descripcion': 'Completar test PHQ-9',
            'completada': true,
            'fecha_asignacion': '2026-11-24T10:00:00Z',
          },
        ],
        evaluaciones: <Map<String, dynamic>>[
          <String, dynamic>{
            'completado': true,
            'fecha_completado': '2026-11-25T10:00:00Z',
            'respuestas': List<int>.filled(8, 0),
            'test_psicometrico': <String, dynamic>{
              'nombre': 'PHQ-9',
              'codigo': 'PHQ-9',
            },
          },
        ],
      ),
    );

    expect(find.text('Completar test PHQ-9'), findsOneWidget);
    expect(find.text('No tienes tareas pendientes.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una cita cuya hora ya pasó desaparece del panel', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      FakePacienteAuth(
        demo: false,
        cita: <String, dynamic>{
          'id_cita': 1,
          'id_psicologo': 19,
          'fecha_hora': '2020-01-01T10:00:00+00:00',
        },
      ),
    );

    expect(find.text('Cita Programada'), findsNothing);
    expect(find.textContaining('00/00/00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el panel pide completar información y guarda teléfono y dirección',
    (WidgetTester tester) async {
      final auth = FakePacienteAuth(demo: false);
      await pumpDashboard(tester, auth);

      expect(find.text('Completar información'), findsNWidgets(2));
      await tester.tap(find.text('Completar información').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '3001234567');
      await tester.enterText(find.byType(TextFormField).at(1), 'Calle 1 # 2-3');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(auth.contactosGuardados.single, (
        telefono: '3001234567',
        direccion: 'Calle 1 # 2-3',
      ));
      expect(find.text('Completar información'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el modo real del panel pinta lo que trae la base', (
    WidgetTester tester,
  ) async {
    final fake = FakePacienteAuth(
      demo: false,
      cita: <String, dynamic>{
        'id_cita': 7,
        'fecha_hora': '2030-01-01T10:00:00+00:00',
        'estado_cita': 'CONFIRMADA',
        'modalidad': 'TELECONSULTA',
        'motivo_consulta': 'Sesión de seguimiento',
      },
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_tarea': 1,
          'descripcion': 'Completar ficha de admisión',
          'completada': false,
        },
      ],
      evaluaciones: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_evaluacion': 2,
          'puntaje_total': 11,
          'completado': true,
          'respuestas': List<int>.filled(14, 0),
          'test_psicometrico': <String, dynamic>{
            'nombre': 'Escala de ansiedad de Hamilton',
          },
        },
      ],
      acompanante: <String, dynamic>{
        'nombre': 'Oscar Pérez',
        'parentesco': 'Padre',
        'telefono': '+56 9 1111 1111',
      },
    );

    await pumpDashboard(tester, fake);

    expect(find.text('Sesión de seguimiento'), findsOneWidget);
    expect(find.text('Teleconsulta'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Nombre del profesional no disponible.'), findsOneWidget);
    expect(find.text('Escala de ansiedad de Hamilton'), findsOneWidget);
    expect(find.text('11'), findsNothing);
    expect(find.text('Completado'), findsOneWidget);
    expect(find.text('Completar ficha de admisión'), findsOneWidget);
    expect(find.text('Oscar Pérez'), findsOneWidget);
    expect(find.text('Aún no tienes citas programadas.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la bandeja agrupa los chats por psicólogo', (
    WidgetTester tester,
  ) async {
    final auth = FakePacienteAuth(
      demo: false,
      mensajes: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_psicologo': 19,
          'id_paciente': 1,
          'autor_id': 1,
          'texto': 'Primer mensaje',
          'fecha_envio': '2026-11-24T10:00:00Z',
        },
        <String, dynamic>{
          'id_psicologo': 22,
          'id_paciente': 1,
          'autor_id': 22,
          'texto': 'Hablemos mañana',
          'fecha_envio': '2026-11-24T11:00:00Z',
        },
        <String, dynamic>{
          'id_psicologo': 19,
          'id_paciente': 1,
          'autor_id': 19,
          'texto': 'Última respuesta',
          'fecha_envio': '2026-11-24T12:00:00Z',
        },
      ],
    );
    await pumpDashboard(tester, auth);
    await tester.tap(find.byTooltip('Chats'));
    await tester.pumpAndSettle();

    expect(find.byType(PacienteChatsPage), findsOneWidget);
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Dr. Andrés Rojas'), findsOneWidget);
    expect(find.text('Última respuesta'), findsOneWidget);
    expect(find.text('Primer mensaje'), findsNothing);

    await tester.tap(find.text('Dra. Yani Casiani'));
    await tester.pumpAndSettle();
    expect(find.text('Mensaje a Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Primer mensaje'), findsOneWidget);
    expect(find.text('Última respuesta'), findsNWidgets(2));
    final mensajePaciente = tester.widget<Align>(
      find
          .ancestor(
            of: find.text('Primer mensaje'),
            matching: find.byType(Align),
          )
          .first,
    );
    final mensajePsicologo = tester.widget<Align>(
      find
          .ancestor(
            of: find.text('Última respuesta'),
            matching: find.byType(Align),
          )
          .first,
    );
    expect(mensajePaciente.alignment, Alignment.centerRight);
    expect(mensajePsicologo.alignment, Alignment.centerLeft);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un mensaje entrante genera una notificación en el panel', (
    WidgetTester tester,
  ) async {
    final stream = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(stream.close);
    await pumpDashboard(
      tester,
      FakePacienteAuth(demo: false, mensajesStream: stream.stream),
    );

    stream.add(<String, dynamic>{
      'id_psicologo': 19,
      'autor_id': 19,
      'texto': 'Hola',
    });
    await tester.pumpAndSettle();

    expect(find.text('Nuevo mensaje de Dra. Yani Casiani.'), findsOneWidget);
    expect(find.byTooltip('Chats, mensajes nuevos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la cuenta demo del perfil conserva los datos de la captura', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, FakePacienteAuth(demo: true));

    expect(find.text('RUT 14.520.118-2'), findsOneWidget);
    expect(find.text('Ficha #SV-2049'), findsOneWidget);
    expect(find.text('InnovaTech Solutions S.A.'), findsOneWidget);
    expect(find.text('Oscar Flerez'), findsOneWidget);
    expect(find.text('Gestión y Documentación'), findsNothing);
    expect(find.text('MINDJORA • PORTAL DEL PACIENTE • V2.4.1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el modo real del perfil avisa sin convenio ni acompañante', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, FakePacienteAuth(demo: false));

    expect(find.text('Sin convenio corporativo'), findsOneWidget);
    expect(find.text('Aún no tienes convenio asociado.'), findsOneWidget);
    expect(find.text('Aún no hay indicadores de tu proceso.'), findsOneWidget);
    expect(find.text('Red de Apoyo y Acompañante'), findsNothing);
    expect(
      find.text('Configurar Notificaciones del Acompañante'),
      findsNothing,
    );
    expect(find.text('Portal del Acompañante'), findsNothing);
    expect(find.text('Desvincular Acompañante'), findsNothing);
    expect(find.text('Gestión y Documentación'), findsNothing);
    expect(find.text('MINDJORA • PORTAL DEL PACIENTE • V2.4.1'), findsNothing);
    expect(
      find.textContaining('Gestión de perfil y red de apoyo'),
      findsNothing,
    );
    expect(find.text('Cerrar Sesión'), findsOneWidget);
    expect(find.text('RUT 14.520.118-2'), findsNothing);
    expect(find.text('Ficha #SV-2049'), findsNothing);
    expect(find.text('InnovaTech Solutions S.A.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el modo real del perfil pinta el convenio y el acompañante', (
    WidgetTester tester,
  ) async {
    final fake = FakePacienteAuth(
      demo: false,
      empresa: <String, dynamic>{
        'id_empresa': 3,
        'nombre': 'Consultorio Demo Mindjora',
        'codigo': 'DEMO-MINDJORA',
      },
      acompanante: <String, dynamic>{
        'nombre': 'Oscar Pérez',
        'parentesco': 'Padre',
        'telefono': '+56 9 1111 1111',
      },
    );

    await pumpProfile(tester, fake);

    expect(find.text('Consultorio Demo Mindjora'), findsWidgets);
    expect(find.text('DEMO-MINDJORA'), findsWidgets);
    expect(find.text('Oscar Pérez'), findsOneWidget);
    expect(find.text('Red de Apoyo y Acompañante'), findsOneWidget);
    expect(find.text('Portal del Acompañante'), findsOneWidget);
    expect(find.text('Aún no tienes convenio asociado.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // --- Modo demo y modo real: diario y tests -------------------------------

  testWidgets('la cuenta demo del diario conserva solo sus datos emocionales', (
    WidgetTester tester,
  ) async {
    await pumpDiary(tester, FakePacienteAuth(demo: true));

    expect(find.text('Fase 4 · Acompañamiento Activo'), findsOneWidget);
    expect(find.text('5 días constantes'), findsOneWidget);
    expect(find.text('Tareas Asignadas'), findsNothing);
    expect(find.text('Dra. Yani Casiani'), findsNothing);
    expect(
      find.text('Registro de Pensamiento Disfuncional (Modelo ABC)'),
      findsNothing,
    );
    expect(find.text('Caminata consciente y grounding'), findsNothing);
    expect(find.text('Higiene de sueño y descanso'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el modo real del diario avisa donde antes había datos inventados',
    (WidgetTester tester) async {
      await pumpDiary(tester, FakePacienteAuth(demo: false));

      expect(find.text('Tareas Asignadas'), findsNothing);
      expect(find.text('Aún no tienes tareas asignadas.'), findsNothing);
      // La tarjeta de la semana y la de la evolución, ambas.
      expect(find.text('Aún no hay registros esta semana.'), findsNWidgets(2));

      // Nada de la captura.
      expect(find.text('Fase 4 · Acompañamiento Activo'), findsNothing);
      expect(find.text('5 días constantes'), findsNothing);
      expect(find.text('Dra. Yani Casiani'), findsNothing);
      expect(
        find.text('Registro de Pensamiento Disfuncional (Modelo ABC)'),
        findsNothing,
      );
      expect(find.text('Terapia Cognitivo-Conductual'), findsNothing);
      expect(find.text('Caminata consciente y grounding'), findsNothing);
      expect(find.text('Higiene de sueño y descanso'), findsNothing);
      expect(find.text('8 minutos aprox.'), findsNothing);
      expect(find.text('Comenzar'), findsNothing);
      expect(find.text('Leer ficha'), findsNothing);
      expect(find.textContaining('18%', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el diario real oculta tareas y muestra registros reales', (
    WidgetTester tester,
  ) async {
    final hoy = DateTime.now();
    final fecha =
        '${hoy.year}-'
        '${hoy.month.toString().padLeft(2, '0')}-'
        '${hoy.day.toString().padLeft(2, '0')}';
    final fake = FakePacienteAuth(
      demo: false,
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_tarea': 1,
          'descripcion': 'Completar ficha de sueño',
          'completada': false,
        },
      ],
      seguimiento: <Map<String, dynamic>>[
        <String, dynamic>{'id_registro': 1, 'nivel_animo': 75, 'fecha': fecha},
      ],
    );

    await pumpDiary(tester, fake);

    expect(find.text('Completar ficha de sueño'), findsNothing);
    expect(find.text('Pendiente'), findsNothing);
    expect(find.text('Tareas Asignadas'), findsNothing);
    // Solo hoy registrado: la racha es de un día.
    expect(find.text('1 día con registro'), findsOneWidget);
    expect(find.text('Aún no hay registros esta semana.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una tarea «Completar test X» abre ese cuestionario', (
    WidgetTester tester,
  ) async {
    final fake = FakePacienteAuth(
      demo: false,
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Completar test PHQ-9',
          'completada': false,
        },
        <String, dynamic>{
          'descripcion': 'Registro de animo diario',
          'completada': false,
        },
      ],
      catalogo: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_test': 4,
          'nombre': 'PHQ-9',
          'descripcion': 'Índice de depresión',
        },
        <String, dynamic>{
          'id_test': 5,
          'nombre': 'GAD-7',
          'descripcion': 'Índice de ansiedad',
        },
      ],
    );
    await pumpDashboard(tester, fake);
    expect(fake.cargasCatalogoTests, 0);

    await tester.ensureVisible(find.text('Completar test PHQ-9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completar test PHQ-9'));
    await tester.pumpAndSettle();

    // La tarea mandó el nombre y abrió la pantalla con esa pestaña.
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(inkOf(tester, 'PHQ-9 (Depresión)'), AppColors.brandDark);
    expect(find.text('GAD-7 (Ansiedad)'), findsNothing);
    // El `auth` del panel viajó a la pantalla de tests.
    expect(fake.cargasCatalogoTests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una tarea que no es test no abre nada', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      FakePacienteAuth(
        demo: false,
        tareas: <Map<String, dynamic>>[
          <String, dynamic>{
            'descripcion': 'Registro de animo diario',
            'completada': false,
          },
        ],
      ),
    );
    await tester.ensureVisible(find.text('Registro de animo diario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registro de animo diario'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Karen Lucía'), findsOneWidget);
    expect(find.text('Batería de Tests Pre-consulta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un testInicial que no está en el catálogo cae a la primera '
      'pestaña', (WidgetTester tester) async {
    final fake = FakePacienteAuth(
      demo: false,
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Completar test PHQ-9',
          'completada': false,
        },
        <String, dynamic>{
          'descripcion': 'Completar test GAD-7',
          'completada': false,
        },
      ],
      catalogo: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_test': 4,
          'nombre': 'PHQ-9',
          'descripcion': 'Índice de depresión',
        },
        <String, dynamic>{
          'id_test': 5,
          'nombre': 'GAD-7',
          'descripcion': 'Índice de ansiedad',
        },
      ],
    );
    await pumpOnPhone(
      tester,
      MaterialApp(
        home: PacienteTestsPage(auth: fake, testInicial: 'No existe'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(inkOf(tester, 'PHQ-9 (Depresión)'), AppColors.brandDark);
    expect(inkOf(tester, 'GAD-7 (Ansiedad)'), AppColors.inkSoft);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo se muestran los tests asignados por el psicólogo', (
    WidgetTester tester,
  ) async {
    await pumpTests(
      tester,
      FakePacienteAuth(
        demo: false,
        tareas: <Map<String, dynamic>>[
          <String, dynamic>{
            'descripcion': 'Completar test PHQ-9',
            'completada': false,
          },
          <String, dynamic>{
            'descripcion': 'Completar test PSS-14',
            'completada': false,
          },
        ],
        catalogo: <Map<String, dynamic>>[
          <String, dynamic>{
            'id_test': 4,
            'nombre': 'PHQ-9',
            'descripcion': 'Depresión',
          },
          <String, dynamic>{
            'id_test': 5,
            'nombre': 'GAD-7',
            'descripcion': 'Ansiedad',
          },
          <String, dynamic>{
            'id_test': 6,
            'nombre': 'PSS-14',
            'descripcion': 'Estrés',
          },
        ],
      ),
    );

    // El asignado con ítems se puede responder.
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);

    // Los tests no asignados ni siquiera aparecen en la batería.
    expect(find.text('GAD-7 (Ansiedad)'), findsNothing);
    expect(
      find.text('Tu psicólogo aún no ha asignado este test.'),
      findsNothing,
    );

    // El asignado con ítems propios también se puede responder.
    await tester.ensureVisible(find.text('PSS-14 (Estrés)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PSS-14 (Estrés)'));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta 1 de 14'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin tareas asignadas ningún test se puede abrir', (
    WidgetTester tester,
  ) async {
    await pumpTests(
      tester,
      FakePacienteAuth(
        demo: false,
        catalogo: <Map<String, dynamic>>[
          <String, dynamic>{
            'id_test': 4,
            'nombre': 'PHQ-9',
            'descripcion': 'Depresión',
          },
        ],
      ),
    );
    expect(find.text('Aún no hay tests disponibles.'), findsOneWidget);
    expect(find.text('PHQ-9 (Depresión)'), findsNothing);
    expect(find.text('Pregunta 1 de 9'), findsNothing);
    expect(find.text('Siguiente Pregunta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la cuenta demo de los tests conserva la captura', (
    WidgetTester tester,
  ) async {
    await pumpTests(tester, FakePacienteAuth(demo: true));

    expect(find.text('Faltan 4h 15m'), findsOneWidget);
    expect(find.text('PHQ-9 (Depresión)'), findsOneWidget);
    expect(find.text('GAD-7 (Ansiedad)'), findsOneWidget);
    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('Pregunta 3 de 9'), findsOneWidget);
    expect(find.text('Aún no hay tests disponibles.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el modo real de los tests lee el catálogo y avisa sin datos', (
    WidgetTester tester,
  ) async {
    await pumpTests(tester, FakePacienteAuth(demo: false));

    expect(find.text('Aún no hay tests disponibles.'), findsOneWidget);
    expect(find.text('Aún no tienes una sesión programada.'), findsOneWidget);
    expect(find.text('Nombre del profesional no disponible.'), findsOneWidget);

    // Nada de la captura.
    expect(find.text('Faltan 4h 15m'), findsNothing);
    expect(find.text('PHQ-9 (Depresión)'), findsNothing);
    expect(find.text('GAD-7 (Ansiedad)'), findsNothing);
    expect(find.text('Dra. Yani Casiani'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el modo real de los tests abre el cuestionario del catálogo', (
    WidgetTester tester,
  ) async {
    final fake = FakePacienteAuth(
      demo: false,
      cita: <String, dynamic>{
        'id_cita': 1,
        'fecha_hora': '2030-01-01T10:00:00+00:00',
        'estado_cita': 'CONFIRMADA',
        'modalidad': 'PRESENCIAL',
        'motivo_consulta': 'Primera sesión',
      },
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Completar test PHQ-9',
          'completada': false,
        },
        <String, dynamic>{
          'descripcion': 'Completar test Test de sueño',
          'completada': false,
        },
      ],
      catalogo: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_test': 1,
          'nombre': 'PHQ-9',
          'descripcion': 'Índice de depresión',
        },
        <String, dynamic>{
          'id_test': 2,
          'nombre': 'Test de sueño',
          'descripcion': 'Calidad del sueño',
        },
      ],
    );

    await pumpTests(tester, fake);

    // El catálogo manda: dos pestañas y el límite con la cita real.
    expect(find.text('PHQ-9 (Depresión)'), findsOneWidget);
    expect(find.text('Test de sueño'), findsOneWidget);
    expect(find.text('LÍMITE CLÍNICO'), findsOneWidget);
    expect(find.text('Faltan 4h 15m'), findsNothing);
    // Sin respuestas prefijadas: se arranca en la primera pregunta.
    expect(find.text('Pregunta 1 de 9'), findsOneWidget);

    // El test sin ítems en la app avisa en vez de inventar preguntas.
    await tester.tap(find.text('Test de sueño'));
    await tester.pumpAndSettle();
    expect(
      find.text('Este test aún no está disponible en la app.'),
      findsOneWidget,
    );
    expect(find.text('Calidad del sueño'), findsOneWidget);
    expect(find.text('Siguiente Pregunta'), findsNothing);
    expect(find.text('Ítem 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ocho pestañas de tests no desbordan horizontalmente', (
    WidgetTester tester,
  ) async {
    final nombres = List<String>.generate(8, (i) => 'Test ${i + 1}');
    final fake = FakePacienteAuth(
      demo: false,
      tareas: <Map<String, dynamic>>[
        for (final nombre in nombres)
          <String, dynamic>{
            'descripcion': 'Completar test $nombre',
            'completada': true,
          },
      ],
      catalogo: <Map<String, dynamic>>[
        for (var i = 0; i < nombres.length; i++)
          <String, dynamic>{
            'id_test': i + 1,
            'nombre': nombres[i],
            'descripcion': 'Evaluación psicológica',
          },
      ],
      evaluaciones: <Map<String, dynamic>>[
        for (var i = 0; i < nombres.length; i++)
          <String, dynamic>{
            'id_evaluacion': i + 1,
            'completado': true,
            'respuestas': <int>[0],
            'test_psicometrico': <String, dynamic>{'nombre': nombres[i]},
          },
      ],
    );
    await pumpOnPhone(
      tester,
      MaterialApp(
        home: PacienteTestsPage(auth: fake, testInicial: 'Test 8'),
      ),
    );
    tester.view.physicalSize = const Size(384, 853);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Test 8'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    final selectedTabRect = tester.getRect(find.text('Test 8').first);
    expect(selectedTabRect.left, greaterThanOrEqualTo(0));
    expect(selectedTabRect.right, lessThanOrEqualTo(384));
    expect(
      tester.widget<Text>(find.text('Test 8').first).style?.color,
      AppColors.brandDark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el cuestionario no desborda en una pantalla compacta', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetViewPadding();
    });
    final fake = FakePacienteAuth(
      demo: false,
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Completar test PHQ-9',
          'completada': false,
        },
      ],
      catalogo: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_test': 1,
          'nombre': 'PHQ-9',
          'descripcion': 'Depresión',
        },
      ],
    );
    await pumpTests(tester, fake);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();

    for (var i = 0; i < 8; i++) {
      await tester.ensureVisible(find.text('Para nada').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Para nada').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Siguiente Pregunta'));
      await tester.tap(find.text('Siguiente Pregunta'));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(find.text('Para nada').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Para nada').last);
    await tester.pumpAndSettle();
    expect(find.text('Finalizar cuestionario'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abrir el test desde el panel no produce desbordamiento', (
    WidgetTester tester,
  ) async {
    final fake = FakePacienteAuth(
      demo: false,
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Completar test PHQ-9',
          'completada': false,
        },
      ],
      catalogo: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_test': 1,
          'nombre': 'PHQ-9',
          'descripcion': 'Depresión',
        },
      ],
    );
    await pumpDashboard(tester, fake);
    tester.view.physicalSize = const Size(384, 853);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Completar test PHQ-9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completar test PHQ-9'));
    await tester.pumpAndSettle();

    expect(find.text('Pregunta 1 de 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si falla el guardado del test no se dice que fue enviado', (
    WidgetTester tester,
  ) async {
    final fake = FakePacienteAuth(
      demo: false,
      fallarEvaluacion: true,
      tareas: <Map<String, dynamic>>[
        <String, dynamic>{
          'descripcion': 'Completar test PHQ-9',
          'completada': false,
        },
      ],
      catalogo: <Map<String, dynamic>>[
        <String, dynamic>{
          'id_test': 1,
          'nombre': 'PHQ-9',
          'descripcion': 'Índice de depresión',
        },
      ],
    );
    await pumpTests(tester, fake);

    // Respondemos el cuestionario completo (9 ítems, opción «Para nada»).
    for (var i = 0; i < 9; i++) {
      await tester.tap(find.text('Para nada').last);
      await tester.pumpAndSettle();
      final boton = find.text(
        i == 8 ? 'Finalizar cuestionario' : 'Siguiente Pregunta',
      );
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();
    }

    expect(
      find.text('No se pudo guardar el resultado. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Tests enviados. Tu terapeuta los revisará antes de la sesión.',
      ),
      findsNothing,
    );
    expect(fake.evaluacionesGuardadas, contains('PHQ-9'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'al completar un test se cierra la tarea y no se muestra el resultado',
    (WidgetTester tester) async {
      final guardarEvaluacion = Completer<bool>();
      final fake = FakePacienteAuth(
        demo: false,
        evaluacionEnEspera: guardarEvaluacion,
        tareas: <Map<String, dynamic>>[
          <String, dynamic>{
            'descripcion': 'Completar test PHQ-9',
            'completada': false,
          },
        ],
        catalogo: <Map<String, dynamic>>[
          <String, dynamic>{
            'id_test': 1,
            'nombre': 'PHQ-9',
            'descripcion': 'Depresión',
          },
        ],
      );
      await pumpDashboard(tester, fake);
      await tester.ensureVisible(find.text('Completar test PHQ-9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completar test PHQ-9'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 9; i++) {
        final opcion = i == 8 ? 'Varios días' : 'Para nada';
        await tester.tap(find.text(opcion).last);
        await tester.pumpAndSettle();
        final boton = find.text(
          i == 8 ? 'Finalizar cuestionario' : 'Siguiente Pregunta',
        );
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        if (i == 8) {
          await tester.tap(boton);
          await tester.pump();
          expect(find.text('Enviando...'), findsOneWidget);

          await tester.tap(find.text('Enviando...'));
          await tester.pump();
          expect(
            fake.evaluacionesGuardadas
                .where((nombre) => nombre == 'PHQ-9')
                .length,
            1,
          );
          guardarEvaluacion.complete(true);
        } else {
          await tester.tap(boton);
        }
        await tester.pumpAndSettle();
      }

      expect(fake.evaluacionesGuardadas, contains('PHQ-9'));
      expect(fake.tareasTestCompletadas, contains('PHQ-9'));
      expect(fake.tareas.single['completada'], isTrue);
      expect(find.text('No tienes tareas pendientes.'), findsOneWidget);
      expect(find.text('Completar test PHQ-9'), findsNothing);
      expect(find.text('Completado'), findsOneWidget);
      expect(find.text('Pendiente'), findsNothing);
      expect(find.text('Resultado de PHQ-9'), findsNothing);
      expect(find.text('Puntaje: 1 / 27'), findsNothing);
      expect(find.text('Depresión mínima'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el portal del acompañante en modo demo conserva los datos de la captura',
    (WidgetTester tester) async {
      await pumpCompanion(tester, FakePacienteAuth(demo: true));

      expect(find.text('Sin conexión a la base de datos.'), findsOneWidget);
      expect(
        find.text('Consulta autorizada para Oscar Flerez'),
        findsOneWidget,
      );
      expect(find.text('Karen Lucía'), findsOneWidget);
      expect(find.text('KL'), findsOneWidget);
      expect(find.text('Hoy, 18:30 - 19:20'), findsOneWidget);
      expect(
        find.text('Sesión en línea con la Dra. Yani Casiani'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el portal del acompañante en modo real muestra los datos de la base',
    (WidgetTester tester) async {
      final auth = FakePacienteAuth(
        demo: false,
        acompanante: <String, dynamic>{
          'nombre': 'Roberto Gómez',
          'parentesco': 'Hermano',
        },
        cita: <String, dynamic>{
          'id_cita': 1,
          'id_psicologo': 22,
          'fecha_hora': '2030-05-15T16:00:00+00:00',
          'estado_cita': 'CONFIRMADA',
        },
      );
      await pumpCompanion(tester, auth);

      expect(find.text('Sin conexion a la base de datos.'), findsNothing);
      expect(
        find.text('Consulta autorizada para Roberto Gómez'),
        findsOneWidget,
      );
      expect(find.text('Karen Lucía'), findsOneWidget);
      expect(find.text('KL'), findsOneWidget);
      expect(find.textContaining('15/05, 16:00 hrs'), findsOneWidget);
      expect(find.text('Sesión con Dr. Andrés Rojas'), findsOneWidget);
      expect(find.text('Oscar Flerez'), findsNothing);
      expect(find.text('Dra. Yani Casiani'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el portal del acompañante en modo real avisa cuando no hay datos',
    (WidgetTester tester) async {
      final auth = FakePacienteAuth(demo: false, sinDatos: true);
      await pumpCompanion(tester, auth);

      expect(find.text('Sin conexion a la base de datos.'), findsNothing);
      expect(find.text('Aún no tienes acompañante vinculado.'), findsOneWidget);
      expect(
        find.text('No se encontraron datos del paciente.'),
        findsOneWidget,
      );
      expect(find.text('Aún no tienes citas programadas.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la matriz de permisos del perfil en modo real muestra los permisos activos y vínculo registrado',
    (WidgetTester tester) async {
      final auth = FakePacienteAuth(
        demo: false,
        acompanante: <String, dynamic>{
          'nombre': 'Oscar Flerez',
          'parentesco': 'Padre',
        },
        permisos: <Map<String, dynamic>>[
          <String, dynamic>{
            'tipo_recurso': 'ALERTA',
            'nivel': 'LECTURA',
            'ambito': 'PROPIO',
          },
          <String, dynamic>{
            'tipo_recurso': 'CITA',
            'nivel': 'LECTURA',
            'ambito': 'PROPIO',
          },
        ],
      );
      await pumpProfile(tester, auth);

      expect(find.text('Vínculo registrado'), findsOneWidget);
      expect(find.text('VINCULACIÓN ACTIVA (OPER 1)'), findsNothing);
      expect(
        find.text('Alertas de inasistencia o contingencia (OPER 1)'),
        findsOneWidget,
      );
      expect(
        find.text('Calendario de próximas sesiones y horarios'),
        findsOneWidget,
      );
      expect(
        find.text('Notas de terapia, diario íntimo y tests clínicos (OPER 2)'),
        findsNothing,
      );
      expect(
        find.text('Configuración de seguridad y acceso a la cuenta'),
        findsNothing,
      );
      expect(find.text('Protección biométrica y 2FA activo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la matriz de permisos del perfil en modo real avisa si no hay permisos',
    (WidgetTester tester) async {
      final auth = FakePacienteAuth(
        demo: false,
        acompanante: <String, dynamic>{
          'nombre': 'Oscar Flerez',
          'parentesco': 'Padre',
        },
        permisos: const <Map<String, dynamic>>[],
      );
      await pumpProfile(tester, auth);

      expect(find.text('Aún no tienes permisos registrados.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la sala real muestra el profesional y envía un mensaje', (
    WidgetTester tester,
  ) async {
    final auth = FakePacienteAuth(
      demo: false,
      cita: <String, dynamic>{
        'id_cita': 1,
        'id_psicologo': 19,
        'estado_cita': 'CONFIRMADA',
        'fecha_hora': '2030-01-01T10:00:00+00:00',
      },
    );
    await pumpSala(tester, auth);

    expect(find.text('Dra. Yani Casiani'), findsOneWidget);
    expect(find.text('YC'), findsOneWidget);
    expect(find.text('P19'), findsNothing);
    expect(find.text('Unirse a la Videollamada Ahora'), findsOneWidget);
    expect(find.text('Enviar mensaje breve al profesional'), findsOneWidget);
    expect(find.text('Válido'), findsNothing);

    await tester.tap(find.text('Enviar mensaje breve al profesional'));
    await tester.pumpAndSettle();
    expect(find.text('Mensaje a Dra. Yani Casiani'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '¿Sigue la cita?');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(auth.mensajesEnviados.single, (
      idPsicologo: 19,
      texto: '¿Sigue la cita?',
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la sala avisa si no hay cita en vez de inventar profesional', (
    WidgetTester tester,
  ) async {
    await pumpSala(tester, FakePacienteAuth(demo: false));

    expect(find.text('Profesional no disponible'), findsOneWidget);
    expect(find.text('Sin cita programada.'), findsOneWidget);
    expect(enlaceVideollamada(19), 'https://meet.jit.si/mindjora-psicologo-19');

    await tester.tap(find.text('Unirse a la Videollamada Ahora'));
    await tester.pump();
    expect(
      find.text('No tienes una cita programada para entrar a la sala.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el detalle real muestra la duración calculada y sin duración no inventa 50',
    (WidgetTester tester) async {
      const reservaConDuracion = SesionReserva(
        specialistName: 'Profesional #19',
        initials: 'P19',
        role: 'Psicólogo',
        rating: '5.0',
        reviews: '10',
        focus: 'General',
        dateLabel: 'Lunes 10',
        startTime: '10:00',
        idPsicologo: 19,
        idDisponibilidad: 1,
        tarifa: 50000,
        duracionMinutos: 45,
      );
      await pumpOnPhone(
        tester,
        const MaterialApp(
          home: PacienteDetalleSesionPage(reserva: reservaConDuracion),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Tarifa base consulta (45 min)'), findsOneWidget);

      const reservaSinDuracion = SesionReserva(
        specialistName: 'Profesional #19',
        initials: 'P19',
        role: 'Psicólogo',
        rating: '5.0',
        reviews: '10',
        focus: 'General',
        dateLabel: 'Lunes 10',
        startTime: '10:00',
        idPsicologo: 19,
        idDisponibilidad: 1,
        tarifa: 50000,
        duracionMinutos: null,
      );
      await pumpOnPhone(
        tester,
        const MaterialApp(
          home: PacienteDetalleSesionPage(reserva: reservaSinDuracion),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Tarifa base consulta'), findsOneWidget);
      expect(find.text('Tarifa base consulta (50 min)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
