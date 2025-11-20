class AcademicData {
  static const List<Map<String, String>> facultades = [
    {
      '_id': 'FAEDCOH',
      'siglas': 'FAEDCOH',
      'nombre': 'Facultad de Educación, Ciencias de la Comunicación y Humanidades'
    },
    {
      '_id': 'FACSA',
      'siglas': 'FACSA',
      'nombre': 'Facultad de Ciencias de la Salud'
    },
    {
      '_id': 'FADE',
      'siglas': 'FADE',
      'nombre': 'Facultad de Derecho y Ciencias Políticas'
    },
    {
      '_id': 'FACEM',
      'siglas': 'FACEM',
      'nombre': 'Facultad de Ciencias Empresariales'
    },
    {
      '_id': 'FAU',
      'siglas': 'FAU',
      'nombre': 'Facultad de Arquitectura y Urbanismo'
    },
    {
      '_id': 'FAING',
      'siglas': 'FAING',
      'nombre': 'Facultad de Ingenieria'
    },
  ];

  static const List<Map<String, String>> escuelas = [
    {
      '_id': 'epcc',
      'nombre': 'Escuela Profesional de Ciencias de la Comunicación',
      'siglas_facultad': 'FAEDCOH',
      'siglas': 'EPCC'
    },
    {
      '_id': 'epani',
      'nombre': 'Escuela Profesional de Administración de Negocios Internacionales',
      'siglas_facultad': 'FACEM',
      'siglas': 'EPANI'
    },
    {
      '_id': 'epccf',
      'nombre': 'Escuela Profesional de Ciencias Contables y Financieras',
      'siglas_facultad': 'FACEM',
      'siglas': 'EPCCF'
    },
    {
      '_id': 'epam',
      'nombre': 'Escuela Profesional de Administración',
      'siglas_facultad': 'FACEM',
      'siglas': 'EPAM'
    },
    {
      '_id': 'epe',
      'nombre': 'Escuela Profesional de Educación',
      'siglas_facultad': 'FAEDCOH',
      'siglas': 'EPE'
    },
    {
      '_id': 'epem',
      'nombre': 'Escuela Profesional de Economía y Microfinanzas',
      'siglas_facultad': 'FACEM',
      'siglas': 'EPEM'
    },
    {
      '_id': 'ephp',
      'nombre': 'Escuela Profesional de Humanidades - Psicología',
      'siglas_facultad': 'FAEDCOH',
      'siglas': 'EPHP'
    },
    {
      '_id': 'epd',
      'nombre': 'Escuela Profesional de Derecho',
      'siglas_facultad': 'FADE',
      'siglas': 'EPD'
    },
    {
      '_id': 'epic',
      'nombre': 'Escuela Profesional de Ingeniería Civil',
      'siglas_facultad': 'FAING',
      'siglas': 'EPIC'
    },
    {
      '_id': 'epia',
      'nombre': 'Escuela Profesional de Ingeniería Agroindustrial',
      'siglas_facultad': 'FAING',
      'siglas': 'EPIA'
    },
    {
      '_id': 'epiam',
      'nombre': 'Escuela Profesional de Ingeniería Ambiental',
      'siglas_facultad': 'FAING',
      'siglas': 'EPIAM'
    },
    {
      '_id': 'epie',
      'nombre': 'Escuela Profesional de Ingeniería Electrónica',
      'siglas_facultad': 'FAING',
      'siglas': 'EPIE'
    },
    {
      '_id': 'epicl',
      'nombre': 'Escuela Profesional de Ingeniería Comercial',
      'siglas_facultad': 'FACEM',
      'siglas': 'EPICL'
    },
    {
      '_id': 'epii',
      'nombre': 'Escuela Profesional de Ingeniería Industrial',
      'siglas_facultad': 'FAING',
      'siglas': 'EPII'
    },
    {
      '_id': 'epa',
      'nombre': 'Escuela Profesional de Arquitectura',
      'siglas_facultad': 'FAU',
      'siglas': 'EPA'
    },
    {
      '_id': 'epath',
      'nombre': 'Escuela Profesional de Administración Turístico-Hotelera',
      'siglas_facultad': 'FACEM',
      'siglas': 'EPATH'
    },
    {
      '_id': 'epmh',
      'nombre': 'Escuela Profesional de Medicina Humana',
      'siglas_facultad': 'FACSA',
      'siglas': 'EPMH'
    },
    {
      '_id': 'epis',
      'nombre': 'escuela profesional de ingeniería en sistemas',
      'siglas_facultad': 'FAING',
      'siglas': 'EPIS'
    },
    {
      '_id': 'epo',
      'nombre': 'Escuela Profesional de Odontología',
      'siglas_facultad': 'FACSA',
      'siglas': 'EPO'
    },
    {
      '_id': 'eptm',
      'nombre': 'Escuela Profesional de Tecnología Médica',
      'siglas_facultad': 'FACSA',
      'siglas': 'EPTM'
    },
  ];

  static List<Map<String, String>> getEscuelasPorFacultad(String siglasFacultad) {
    return escuelas.where((e) => e['siglas_facultad'] == siglasFacultad).toList();
  }
}
