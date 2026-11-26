
library;

class OpcionRespuesta {
  const OpcionRespuesta(this.etiqueta, this.valor);

  final String etiqueta;
  final int valor;
}

class ItemTest {
  const ItemTest(this.texto, {this.invertido = false, this.opcionesConPunto});

  final String texto;
  final bool invertido;
  final Set<int>? opcionesConPunto;
}

class InstrumentoTest {
  const InstrumentoTest({
    required this.codigo,
    required this.nombre,
    required this.dominio,
    required this.instruccion,
    required this.fuente,
    required this.opciones,
    required this.items,
    this.itemsPuntuables,
  });

  final String codigo;
  final String nombre;
  final String dominio;
  final String instruccion;

  final String fuente;
  final List<OpcionRespuesta> opciones;
  final List<ItemTest> items;

  final Set<int>? itemsPuntuables;

  int get total => items.length;

  bool _cuenta(int indice) =>
      itemsPuntuables == null || itemsPuntuables!.contains(indice);

  int get maximo {
    final maxOpcion = opciones.length - 1;
    var suma = 0;
    for (var i = 0; i < items.length; i++) {
      if (!_cuenta(i)) continue;
      suma += items[i].opcionesConPunto != null ? 1 : maxOpcion;
    }
    return suma;
  }

  int puntajeTotal(List<int?> respuestas) {
    var total = 0;
    for (var i = 0; i < items.length; i++) {
      if (!_cuenta(i)) continue;
      final respuesta = i < respuestas.length ? respuestas[i] : null;
      if (respuesta == null) continue;
      total += _puntos(items[i], respuesta);
    }
    return total;
  }

  int _puntos(ItemTest item, int respuesta) {
    final conPunto = item.opcionesConPunto;
    if (conPunto != null) return conPunto.contains(respuesta) ? 1 : 0;
    if (item.invertido) return (opciones.length - 1) - respuesta;
    return respuesta;
  }

  String? interpretar(int puntaje) {
    switch (codigo) {
      case 'PHQ-9':
        if (puntaje <= 4) return 'Depresión mínima';
        if (puntaje <= 9) return 'Depresión leve';
        if (puntaje <= 14) return 'Depresión moderada';
        if (puntaje <= 19) return 'Depresión moderadamente grave';
        return 'Depresión grave';
      case 'GAD-7':
        if (puntaje <= 4) return 'Ansiedad mínima';
        if (puntaje <= 9) return 'Ansiedad leve';
        if (puntaje <= 14) return 'Ansiedad moderada';
        return 'Ansiedad moderada a grave';
      case 'PSS-14':
        if (puntaje <= 18) return 'Estrés percibido bajo';
        if (puntaje <= 37) return 'Estrés percibido moderado';
        return 'Estrés percibido alto';
      case 'ASRS-18':
        if (puntaje <= 9) return 'Indicio de TDAH bajo';
        if (puntaje <= 13) return 'Indicio de TDAH moderado';
        if (puntaje <= 17) return 'Indicio de TDAH alto';
        return 'Indicio de TDAH muy alto';
      case 'AQ-10':
        return puntaje > 6
            ? 'Conviene remitir a valoración especializada'
            : 'Sin indicio de remisión';
      default:
        return null;
    }
  }

  bool requiereRevisionHumana(List<int?> respuestas) {
    if (codigo != 'PHQ-9') return false;
    final item9 = respuestas.length > 8 ? respuestas[8] : null;
    return (item9 ?? 0) > 0;
  }
}

const List<OpcionRespuesta> _frecuencia14Dias = <OpcionRespuesta>[
  OpcionRespuesta('Para nada', 0),
  OpcionRespuesta('Varios días', 1),
  OpcionRespuesta('Más de la mitad de los días', 2),
  OpcionRespuesta('Casi todos los días', 3),
];

const List<OpcionRespuesta> _frecuenciaMes = <OpcionRespuesta>[
  OpcionRespuesta('Nunca', 0),
  OpcionRespuesta('Casi nunca', 1),
  OpcionRespuesta('De vez en cuando', 2),
  OpcionRespuesta('A menudo', 3),
  OpcionRespuesta('Muy a menudo', 4),
];

const List<OpcionRespuesta> _acuerdo = <OpcionRespuesta>[
  OpcionRespuesta('Definitivamente de acuerdo', 0),
  OpcionRespuesta('Ligeramente de acuerdo', 1),
  OpcionRespuesta('Ligeramente en desacuerdo', 2),
  OpcionRespuesta('Definitivamente en desacuerdo', 3),
];

const List<OpcionRespuesta> _frecuencia6Meses = <OpcionRespuesta>[
  OpcionRespuesta('Nunca', 0),
  OpcionRespuesta('Rara vez', 1),
  OpcionRespuesta('Algunas veces', 2),
  OpcionRespuesta('Con frecuencia', 3),
  OpcionRespuesta('Muy frecuentemente', 4),
];

const InstrumentoTest phq9 = InstrumentoTest(
  codigo: 'PHQ-9',
  nombre: 'PHQ-9',
  dominio: 'Depresión',
  instruccion:
      'Durante las últimas 2 semanas, ¿con qué frecuencia ha sentido '
      'molestias por los siguientes problemas?',
  fuente: 'PHQ9_Spanish for Colombia.pdf',
  opciones: _frecuencia14Dias,
  items: <ItemTest>[
    ItemTest('Poco interés o placer en hacer las cosas'),
    ItemTest('Sentirse desanimado/a, deprimido/a o sin esperanzas'),
    ItemTest(
      'Problemas para dormir o mantenerse el sueño o dormir demasiado',
    ),
    ItemTest('Sentirse cansado/a o con poca energía'),
    ItemTest('Sentir poco apetito o comer en exceso'),
    ItemTest(
      'Sentirse mal acerca de sí mismo o tener un sentimiento de fracaso o '
      'de abandono propio o de la familia',
    ),
    ItemTest(
      'Dificultad para concentrarse en diferentes actividades tales como '
      'leer el periódico o ver televisión',
    ),
    ItemTest(
      'Moverse o hablar tan despacio que otras personas lo han notado o '
      'bien, por el contrario, estar tan inquieto/a o intranquilo/a que se '
      'mueve mucho más de lo normal',
    ),
    ItemTest(
      'Pensamientos acerca de que sería mejor estar muerto/a o deseos de '
      'lastimarse de alguna forma',
    ),
  ],
);

const InstrumentoTest gad7 = InstrumentoTest(
  codigo: 'GAD-7',
  nombre: 'GAD-7',
  dominio: 'Ansiedad',
  instruccion:
      'Durante las últimas 2 semanas, ¿con qué frecuencia le han molestado '
      'los siguientes problemas?',
  fuente: 'GAD-7-spanish-pdf.pdf',
  opciones: <OpcionRespuesta>[
    OpcionRespuesta('De nada', 0),
    OpcionRespuesta('Varios días', 1),
    OpcionRespuesta('Más de la mitad de los días', 2),
    OpcionRespuesta('Casi todos los días', 3),
  ],
  items: <ItemTest>[
    ItemTest('Sentirse nervioso, ansioso o nervioso'),
    ItemTest('No poder detenerse o controlar la preocupación'),
    ItemTest('Preocuparse demasiado por cosas diferentes'),
    ItemTest('Dificultad para relajarse'),
    ItemTest('Ser tan inquieto que es difícil quedarse quieto'),
    ItemTest('Molestarse o irritarse con facilidad'),
    ItemTest('Sentir miedo, como si algo horrible pudiera suceder'),
  ],
);

const InstrumentoTest pss14 = InstrumentoTest(
  codigo: 'PSS-14',
  nombre: 'PSS-14',
  dominio: 'Estrés',
  instruccion:
      'Las preguntas hacen referencia a sus sentimientos y pensamientos '
      'durante el último mes. Indique cómo se ha sentido en cada situación.',
  fuente: 'Escala-de-Estres-Percibido.pdf',
  opciones: _frecuenciaMes,
  items: <ItemTest>[
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha estado afectado por algo que '
      'ha ocurrido inesperadamente?',
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia se ha sentido incapaz de '
      'controlar las cosas importantes en su vida?',
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia se ha sentido nervioso o '
      'estresado?',
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha manejado con éxito los '
      'pequeños problemas irritantes de la vida?',
      invertido: true,
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha sentido que ha afrontado '
      'efectivamente los cambios importantes que han estado ocurriendo en su '
      'vida?',
      invertido: true,
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha estado seguro sobre su '
      'capacidad para manejar sus problemas personales?',
      invertido: true,
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha sentido que las cosas le van '
      'bien?',
      invertido: true,
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha sentido que no podía '
      'afrontar todas las cosas que tenía que hacer?',
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha podido controlar las '
      'dificultades de su vida?',
      invertido: true,
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia se ha sentido que tenía todo '
      'bajo control?',
      invertido: true,
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha estado enfadado porque las '
      'cosas que le han ocurrido estaban fuera de su control?',
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha pensado sobre las cosas que '
      'le quedan por hacer?',
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha podido controlar la forma de '
      'pasar el tiempo?',
      invertido: true,
    ),
    ItemTest(
      'En el último mes, ¿con qué frecuencia ha sentido que las dificultades '
      'se acumulan tanto que no puede superarlas?',
    ),
  ],
);

const InstrumentoTest aq10 = InstrumentoTest(
  codigo: 'AQ-10',
  nombre: 'AQ-10',
  dominio: 'Autismo',
  instruccion: 'Marque únicamente una opción por pregunta.',
  fuente: 'AQ10-Adult_Spanish.pdf',
  opciones: _acuerdo,
  items: <ItemTest>[
    ItemTest(
      'Con frecuencia percibo pequeños sonidos cuando los demás no lo hacen',
      opcionesConPunto: <int>{0, 1},
    ),
    ItemTest(
      'Usualmente me concentro en toda la película en lugar de pequeños '
      'detalles',
      opcionesConPunto: <int>{2, 3},
    ),
    ItemTest(
      'Se me facilita hacer más de una cosa a la vez',
      opcionesConPunto: <int>{2, 3},
    ),
    ItemTest(
      'Si hay una interrupción, puedo volver inmediatamente a donde estaba',
      opcionesConPunto: <int>{2, 3},
    ),
    ItemTest(
      'Se me facilita "leer entre líneas" cuando alguien me habla',
      opcionesConPunto: <int>{2, 3},
    ),
    ItemTest(
      'Puedo decir cuando alguien me está escuchando o cuando se está '
      'aburriendo',
      opcionesConPunto: <int>{2, 3},
    ),
    ItemTest(
      'Cuando estoy leyendo una historia, se me dificulta identificar las '
      'intenciones de los personajes',
      opcionesConPunto: <int>{0, 1},
    ),
    ItemTest(
      'Me gusta coleccionar información acerca de categorías de cosas '
      '(ejemplo: tipos de autos, de aves, de trenes, tipos de plantas, etc.)',
      opcionesConPunto: <int>{0, 1},
    ),
    ItemTest(
      'Se me facilita saber lo que alguien está pensando o sintiendo '
      'simplemente mirándole a la cara',
      opcionesConPunto: <int>{2, 3},
    ),
    ItemTest(
      'Se me dificulta distinguir las intenciones de la gente',
      opcionesConPunto: <int>{0, 1},
    ),
  ],
);

const InstrumentoTest asrs18 = InstrumentoTest(
  codigo: 'ASRS-18',
  nombre: 'ASRS-18',
  dominio: 'TDA-TDAH',
  instruccion:
      'Mídase a sí mismo en cada criterio según cómo se ha sentido y '
      'comportado en los pasados seis meses.',
  fuente: 'TDA-TDAH.pdf (Anexo 1)',
  opciones: _frecuencia6Meses,
  itemsPuntuables: <int>{0, 1, 2, 3, 4, 5},
  items: <ItemTest>[
    ItemTest(
      'Con cuánta frecuencia tienes problemas para terminar los detalles '
      'finales de un proyecto, una vez que las partes más difíciles fueron '
      'concluidas?',
    ),
    ItemTest(
      'Con cuanta frecuencia tienes dificultad para tener las cosas en orden '
      'cuando tienes que hacer una tarea que requiere organización?',
    ),
    ItemTest(
      'Con cuánta frecuencia tienes problemas para recordar juntas de '
      'trabajo u otras obligaciones?',
    ),
    ItemTest(
      'Cuando tienes una tarea que requiere mucha concentración, con cuánta '
      'frecuencia evitas o retrasas empezarla?',
    ),
    ItemTest(
      'Con cuanta frecuencia mueves o retuerces tus manos o pies cuando estás '
      'sentado por mucho tiempo?',
    ),
    ItemTest(
      'Con cuanta frecuencia te sientes sobre-activo e impulsado a hacer '
      'cosas, como si te moviera un motor?',
    ),
    ItemTest(
      'Con cuanta frecuencia cometes errores por falta de cuidado cuando '
      'estás trabajando en un proyecto aburrido o difícil?',
    ),
    ItemTest(
      'Con cuanta frecuencia tienes dificultad para mantener atención cuando '
      'estás haciendo trabajos aburridos o repetitivos?',
    ),
    ItemTest(
      'Con cuánta frecuencia tienes dificultad para concentrarte en lo que '
      'la gente te dice, aún cuando estén hablando contigo directamente?',
    ),
    ItemTest(
      'Con cuanta frecuencia pierdes o tienes dificultad para encontrar '
      'cosas en la casa o en el trabajo?',
    ),
    ItemTest(
      'Con cuanta frecuencia te distraes por ruidos o actividades alrededor '
      'de ti?',
    ),
    ItemTest(
      'Con cuánta frecuencia te paras de tu asiento en juntas o en otras '
      'situaciones en las que se supone debes permanecer sentado?',
    ),
    ItemTest('Con cuánta frecuencia te sientes inquieto o nervioso?'),
    ItemTest(
      'Con cuanta frecuencia tienes dificultades para relajarte cuando '
      'tienes tiempo para ti?',
    ),
    ItemTest(
      'Con cuánta frecuencia sientes que hablas demasiado cuando estás en '
      'reuniones sociales?',
    ),
    ItemTest(
      'Cuando estás en una conversación, con cuánta frecuencia te descubres '
      'terminando las oraciones de la gente que está hablando, antes de que '
      'ellos terminen?',
    ),
    ItemTest(
      'Con cuánta frecuencia tienes dificultad para esperar tu turno en '
      'situaciones en que debes de hacerlo?',
    ),
    ItemTest(
      'Con cuanta frecuencia interrumpes a otros cuando están ocupados?',
    ),
  ],
);

const List<InstrumentoTest> instrumentos = <InstrumentoTest>[
  phq9,
  gad7,
  pss14,
  asrs18,
  aq10,
];

InstrumentoTest? instrumentoPorCodigo(String? codigo) {
  for (final instrumento in instrumentos) {
    if (instrumento.codigo == codigo) return instrumento;
  }
  return null;
}

