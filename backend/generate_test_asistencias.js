/**
 * Generador de datos de prueba para asistencias - Acees Group
 * USA EXACTAMENTE LOS DATOS EXISTENTES DE ALUMNOS SIN CAMBIAR NADA
 */

const mongoose = require('mongoose');

// DATOS OFICIALES DE FACULTADES Y ESCUELAS
const FACULTADES_ESCUELAS = {
  "FAEDCOH": {
    nombre: "Facultad de Educación, Ciencias de la Comunicación y Humanidades",
    escuelas: ["EPCC", "EPE", "EPHP"]
  },
  "FACEM": {
    nombre: "Facultad de Ciencias Empresariales", 
    escuelas: ["EPANI", "EPCCF", "EPAM", "EPEM", "EPICL", "EPATH"]
  },
  "FADE": {
    nombre: "Facultad de Derecho y Ciencias Políticas",
    escuelas: ["EPD"]
  },
  "FACSA": {
    nombre: "Facultad de Ciencias de la Salud",
    escuelas: ["EPMH", "EPO", "EPTM"]
  },
  "FAU": {
    nombre: "Facultad de Arquitectura y Urbanismo",
    escuelas: ["EPA"]
  },
  "FAING": {
    nombre: "Facultad de Ingenieria",
    escuelas: ["EPIC", "EPIA", "EPIAM", "EPIE", "EPII", "EPIS"]
  }
};

const ESCUELAS_INFO = {
  "EPCC": "Escuela Profesional de Ciencias de la Comunicación",
  "EPE": "Escuela Profesional de Educación", 
  "EPHP": "Escuela Profesional de Humanidades - Psicología",
  "EPANI": "Escuela Profesional de Administración de Negocios Internacionales",
  "EPCCF": "Escuela Profesional de Ciencias Contables y Financieras",
  "EPAM": "Escuela Profesional de Administración",
  "EPEM": "Escuela Profesional de Economía y Microfinanzas", 
  "EPICL": "Escuela Profesional de Ingeniería Comercial",
  "EPATH": "Escuela Profesional de Administración Turístico-Hotelera",
  "EPD": "Escuela Profesional de Derecho",
  "EPMH": "Escuela Profesional de Medicina Humana",
  "EPO": "Escuela Profesional de Odontología",
  "EPTM": "Escuela Profesional de Tecnología Médica",
  "EPA": "Escuela Profesional de Arquitectura",
  "EPIC": "Escuela Profesional de Ingeniería Civil",
  "EPIA": "Escuela Profesional de Ingeniería Agroindustrial", 
  "EPIAM": "Escuela Profesional de Ingeniería Ambiental",
  "EPIE": "Escuela Profesional de Ingeniería Electrónica",
  "EPII": "Escuela Profesional de Ingeniería Industrial",
  "EPIS": "escuela profesional de ingeniería en sistemas"
};

// URI de conexión directa (reemplaza con tu URI)
const MONGODB_URI = "mongodb+srv://Angel:angel12345@cluster0.pas0twe.mongodb.net/ASISTENCIA?retryWrites=true&w=majority&appName=Cluster0";

// Modelos
const AsistenciaSchema = new mongoose.Schema({
  _id: String,
  nombre: String,
  apellido: String,
  dni: String,
  codigo_universitario: String,
  siglas_facultad: String,
  siglas_escuela: String,
  tipo: String, // "entrada" o "salida"
  fecha_hora: String, // formato ISO string
  entrada_tipo: String, // "nfc"
  puerta: String, // "fatag"
  guardia_id: String,
  guardia_nombre: String,
  autorizacion_manual: Boolean,
  razon_decision: { type: mongoose.Schema.Types.Mixed, default: null },
  timestamp_decision: { type: mongoose.Schema.Types.Mixed, default: null },
  coordenadas: { type: mongoose.Schema.Types.Mixed, default: null },
  descripcion_ubicacion: String,
  estado: String, // "autorizado"
  version_registro: String, // "v2_con_guardia"
  timestamp_creacion: String
}, { collection: 'asistencias', _id: false });

const AlumnoSchema = new mongoose.Schema({
  _id: String,
  nombre: String,
  apellido: String,
  dni: String,
  codigo_universitario: String,
  escuela_profesional: String,
  facultad: String,
  siglas_escuela: String,
  siglas_facultad: String,
  estado: Boolean
}, { collection: 'alumnos', _id: false });

const Asistencia = mongoose.model('Asistencia', AsistenciaSchema);
const Alumno = mongoose.model('Alumno', AlumnoSchema);

// Datos fijos del sistema
const GUARDIA_DATA = {
  id: "UMCxDys-WTYHEqHeCZshETthAaK2",
  nombre: "sebastian arce"
};

const UBICACION_DATA = {
  descripcion: "Acceso salida - Punto: fatag - Guardia: sebastian arce",
  puerta: "fatag"
};

// Función para generar ID único similar al formato existente
function generateUniqueId() {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-';
  let result = '';
  for (let i = 0; i < 28; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// Función para generar fecha aleatoria en los últimos 90 días
function generateRandomDate() {
  const now = new Date();
  const pastDays = Math.floor(Math.random() * 90); // Últimos 90 días
  const randomHour = Math.floor(Math.random() * 14) + 6; // Entre 6 AM y 8 PM
  const randomMinute = Math.floor(Math.random() * 60);
  const randomSecond = Math.floor(Math.random() * 60);
  
  const date = new Date(now);
  date.setDate(date.getDate() - pastDays);
  date.setHours(randomHour, randomMinute, randomSecond, 0);
  
  return date;
}

// Función para generar timestamp en formato específico
function generateTimestamp(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}T${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}.${String(date.getMilliseconds()).padStart(3, '0')}Z`;
}

// Función para seleccionar facultad y escuela aleatoria (respetando la jerarquía)
function seleccionarFacultadEscuela() {
  const facultades = Object.keys(FACULTADES_ESCUELAS);
  const facultadSeleccionada = facultades[Math.floor(Math.random() * facultades.length)];
  const escuelasDisponibles = FACULTADES_ESCUELAS[facultadSeleccionada].escuelas;
  const escuelaSeleccionada = escuelasDisponibles[Math.floor(Math.random() * escuelasDisponibles.length)];
  
  return {
    siglas_facultad: facultadSeleccionada,
    nombre_facultad: FACULTADES_ESCUELAS[facultadSeleccionada].nombre,
    siglas_escuela: escuelaSeleccionada,
    nombre_escuela: ESCUELAS_INFO[escuelaSeleccionada]
  };
}

// Función para decidir tipo de acceso (entrada/salida) de forma realista
function decideTipoAcceso(hora) {
  // Horarios de entrada más probables: 6-10 AM
  // Horarios de salida más probables: 12-8 PM
  if (hora >= 6 && hora <= 10) {
    return Math.random() < 0.7 ? 'entrada' : 'salida';
  } else if (hora >= 12 && hora <= 20) {
    return Math.random() < 0.7 ? 'salida' : 'entrada';
  } else {
    return Math.random() < 0.5 ? 'entrada' : 'salida';
  }
}

// Función principal para generar asistencias
async function generateAsistencias(cantidad = 500) {
  try {
    console.log('🔌 Conectando a MongoDB Atlas...');
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Conectado a MongoDB Atlas');

    // Obtener todos los alumnos
    console.log('📚 Obteniendo lista de alumnos...');
    const alumnos = await Alumno.find({ estado: true });
    console.log(`📊 Encontrados ${alumnos.length} alumnos activos`);

    if (alumnos.length === 0) {
      console.log('❌ No hay alumnos en la base de datos');
      return;
    }

    // Verificar asistencias existentes
    const existingCount = await Asistencia.countDocuments();
    console.log(`📋 Asistencias existentes: ${existingCount}`);

    console.log(`🚀 Generando ${cantidad} nuevas asistencias...`);
    
    const asistencias = [];
    
    for (let i = 0; i < cantidad; i++) {
      // Seleccionar alumno aleatorio
      const alumno = alumnos[Math.floor(Math.random() * alumnos.length)];
      
      // Generar fecha y hora aleatoria
      const fechaHora = generateRandomDate();
      const tipo = decideTipoAcceso(fechaHora.getHours());
      
      const asistencia = {
        _id: generateUniqueId(),
        // USAR EXACTAMENTE LOS DATOS DEL ALUMNO SIN MODIFICAR NADA
        nombre: alumno.nombre,
        apellido: alumno.apellido,
        dni: alumno.dni,
        codigo_universitario: alumno.codigo_universitario,
        siglas_facultad: alumno.siglas_facultad, // EXACTO como está en BD
        siglas_escuela: alumno.siglas_escuela,   // EXACTO como está en BD
        // SOLO CAMBIAR ESTOS CAMPOS:
        tipo: tipo, // entrada o salida
        fecha_hora: generateTimestamp(fechaHora), // fecha/hora aleatoria
        entrada_tipo: "nfc",
        puerta: UBICACION_DATA.puerta,
        guardia_id: GUARDIA_DATA.id,
        guardia_nombre: GUARDIA_DATA.nombre,
        autorizacion_manual: false,
        razon_decision: null,
        timestamp_decision: null,
        coordenadas: null,
        descripcion_ubicacion: UBICACION_DATA.descripcion,
        estado: "autorizado",
        version_registro: "v2_con_guardia",
        timestamp_creacion: generateTimestamp(new Date())
      };
      
      asistencias.push(asistencia);
    }

    // Insertar en lotes para mejor rendimiento
    console.log('💾 Insertando asistencias en la base de datos...');
    const batchSize = 100;
    for (let i = 0; i < asistencias.length; i += batchSize) {
      const batch = asistencias.slice(i, i + batchSize);
      await Asistencia.insertMany(batch);
      console.log(`✅ Insertado lote ${Math.floor(i/batchSize) + 1}/${Math.ceil(asistencias.length/batchSize)}`);
    }

    // Verificar resultados
    const newCount = await Asistencia.countDocuments();
    console.log(`🎉 Proceso completado!`);
    console.log(`📊 Total de asistencias ahora: ${newCount}`);
    console.log(`➕ Nuevas asustencias generadas: ${newCount - existingCount}`);

    // Mostrar estadísticas por tipo
    const entradas = await Asistencia.countDocuments({ tipo: 'entrada' });
    const salidas = await Asistencia.countDocuments({ tipo: 'salida' });
    console.log(`📈 Estadísticas:`);
    console.log(`   - Entradas: ${entradas}`);
    console.log(`   - Salidas: ${salidas}`);

    console.log('\n🤖 ¡Los datos están listos para entrenar el modelo ML!');

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Conexión cerrada');
  }
}

// Ejecutar si se llama directamente
if (require.main === module) {
  const cantidad = process.argv[2] ? parseInt(process.argv[2]) : 500;
  console.log(`🎯 Generando ${cantidad} asistencias de prueba...`);
  generateAsistencias(cantidad);
}

module.exports = { generateAsistencias };