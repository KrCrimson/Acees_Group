/**
 * Script para generar datos de prueba para el sistema ML
 * Crea registros históricos simulados de asistencias
 */

const mongoose = require('mongoose');
require('dotenv').config();

// Esquema de Asistencia (igual al del proyecto)
const asistenciaSchema = new mongoose.Schema({
  alumno_id: { type: mongoose.Schema.Types.ObjectId, required: true },
  nombre_completo: { type: String, required: true },
  carrera: { type: String, required: true },
  facultad: { type: String, required: true },
  fecha: { type: Date, required: true },
  hora: { type: String, required: true },
  tipo: { type: String, enum: ['entrada', 'salida'], required: true },
  puerta: { type: String, required: true },
  metodo_acceso: { type: String, default: 'NFC' }
});

const Asistencia = mongoose.model('Asistencia', asistenciaSchema);

// Datos de ejemplo
const facultades = ['Ingeniería', 'Ciencias', 'Medicina', 'Derecho', 'Administración'];
const carreras = {
  'Ingeniería': ['Sistemas', 'Civil', 'Industrial', 'Electrónica'],
  'Ciencias': ['Matemáticas', 'Física', 'Química', 'Biología'],
  'Medicina': ['Medicina General', 'Enfermería', 'Odontología'],
  'Derecho': ['Derecho', 'Ciencias Políticas'],
  'Administración': ['Administración', 'Contabilidad', 'Marketing']
};
const puertas = ['Puerta A', 'Puerta B', 'Puerta C', 'Puerta Principal'];
const nombres = [
  'Juan Pérez', 'María García', 'Carlos López', 'Ana Martínez',
  'Luis Rodríguez', 'Elena Fernández', 'Diego Silva', 'Carmen Ruiz',
  'Pedro González', 'Laura Torres', 'Miguel Herrera', 'Sofía Castro',
  'Andrés Morales', 'Patricia Vargas', 'Roberto Jiménez', 'Isabel Mendoza'
];

function getRandomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function generateRandomDate(daysBack) {
  const now = new Date();
  const pastDate = new Date(now.getTime() - (daysBack * 24 * 60 * 60 * 1000));
  return pastDate;
}

function generateRandomHour() {
  // Horas más probables: 7-9, 12-14, 17-19
  const peakHours = [7, 8, 9, 12, 13, 14, 17, 18, 19];
  const normalHours = [10, 11, 15, 16, 20];
  
  const hour = Math.random() < 0.7 
    ? getRandomItem(peakHours) 
    : getRandomItem(normalHours);
    
  const minute = Math.floor(Math.random() * 60);
  return `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
}

async function generateTestData() {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      dbName: 'ASISTENCIA'
    });

    console.log('🔗 Conectado a MongoDB');

    // Limpiar datos existentes (opcional)
    // await Asistencia.deleteMany({});
    // console.log('🗑️ Datos existentes eliminados');

    const testData = [];
    const alumnoIds = [];

    // Generar IDs de alumnos únicos
    for (let i = 0; i < 50; i++) {
      alumnoIds.push(new mongoose.Types.ObjectId());
    }

    // Generar datos para los últimos 120 días
    for (let day = 0; day < 120; day++) {
      const fecha = generateRandomDate(day);
      
      // Skip weekends (less activity)
      if (fecha.getDay() === 0 || fecha.getDay() === 6) {
        if (Math.random() > 0.3) continue; // 70% skip weekends
      }

      // Generate 20-80 records per day
      const recordsPerDay = Math.floor(Math.random() * 60) + 20;
      
      for (let i = 0; i < recordsPerDay; i++) {
        const alumno_id = getRandomItem(alumnoIds);
        const facultad = getRandomItem(facultades);
        const carrera = getRandomItem(carreras[facultad]);
        const nombre_completo = getRandomItem(nombres);
        const hora = generateRandomHour();
        const tipo = Math.random() > 0.5 ? 'entrada' : 'salida';
        const puerta = getRandomItem(puertas);

        testData.push({
          alumno_id,
          nombre_completo,
          carrera,
          facultad,
          fecha,
          hora,
          tipo,
          puerta,
          metodo_acceso: 'NFC'
        });
      }
    }

    console.log(`📊 Generando ${testData.length} registros de prueba...`);

    // Insertar en lotes de 1000
    const batchSize = 1000;
    for (let i = 0; i < testData.length; i += batchSize) {
      const batch = testData.slice(i, i + batchSize);
      await Asistencia.insertMany(batch);
      console.log(`✅ Insertados ${i + batch.length} de ${testData.length} registros`);
    }

    // Verificar resultados
    const totalCount = await Asistencia.countDocuments();
    const entradaCount = await Asistencia.countDocuments({ tipo: 'entrada' });
    const salidaCount = await Asistencia.countDocuments({ tipo: 'salida' });

    console.log('🎉 ¡Datos de prueba generados exitosamente!');
    console.log(`📈 Total registros: ${totalCount}`);
    console.log(`🚪 Entradas: ${entradaCount}`);
    console.log(`🚶 Salidas: ${salidaCount}`);

  } catch (error) {
    console.error('❌ Error generando datos:', error);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Desconectado de MongoDB');
  }
}

generateTestData();