/**
 * Script de validación de dataset ML
 * Verifica que hay suficientes datos históricos para entrenamiento
 */

const mongoose = require('mongoose');
require('dotenv').config();

// Importar modelo (simplificado para este script)
const asistenciaSchema = new mongoose.Schema({
  nombre: String,
  apellido: String,
  dni: String,
  codigo_universitario: String,
  siglas_facultad: String,
  siglas_escuela: String,
  tipo: String,
  fecha_hora: Date,
  entrada_tipo: String,
  puerta: String,
  guardia_id: String,
  guardia_nombre: String,
  autorizacion_manual: Boolean,
  estado: String,
  razon_decision: String,
  timestamp_decision: String,
  coordenadas: String,
  descripcion_ubicacion: String,
  version_registro: String,
  timestamp_creacion: String
}, { collection: 'asistencias' });

const Asistencia = mongoose.model('Asistencia', asistenciaSchema);

const DatasetCollector = require('../dataset_collector');

async function validateDataset() {
  try {
    console.log('🔍 Validando disponibilidad de dataset...');
    
    // Conectar a MongoDB
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      dbName: 'ASISTENCIA'
    });
    
    console.log('✅ Conectado a MongoDB');
    
    // Crear collector y validar
    const collector = new DatasetCollector(Asistencia);
    const validation = await collector.validateDatasetAvailability();
    
    console.log('\\n📊 RESULTADOS DE VALIDACIÓN:');
    console.log('==============================');
    console.log(`Disponible: ${validation.available ? '✅ SÍ' : '❌ NO'}`);
    console.log(`Registros en período: ${validation.recordsInPeriod}`);
    console.log(`Total de registros: ${validation.totalRecords}`);
    console.log(`Meses disponibles: ${validation.monthsAvailable}`);
    console.log(`Rango de fechas:`);
    console.log(`  Desde: ${new Date(validation.dateRange.desde).toLocaleDateString()}`);
    console.log(`  Hasta: ${new Date(validation.dateRange.hasta).toLocaleDateString()}`);
    
    if (validation.available) {
      console.log('\\n🎉 Dataset válido para entrenamiento ML');
      
      // Obtener estadísticas adicionales
      const stats = await collector.getDatasetStatistics();
      console.log('\\n📈 ESTADÍSTICAS ADICIONALES:');
      console.log('==============================');
      console.log(`Total de registros: ${stats.totalRecords}`);
      console.log('Distribución por tipo:');
      stats.typeDistribution.forEach(type => {
        console.log(`  ${type._id}: ${type.count} registros`);
      });
      console.log('Top 5 facultades:');
      stats.topFaculties.slice(0, 5).forEach(faculty => {
        console.log(`  ${faculty._id}: ${faculty.count} registros`);
      });
    } else {
      console.log('\\n❌ Dataset insuficiente para entrenamiento');
      console.log('Se requieren al menos 100 registros en los últimos 3 meses');
    }
    
    // Desconectar
    await mongoose.disconnect();
    console.log('\\n✅ Validación completada');
    
  } catch (error) {
    console.error('❌ Error validando dataset:', error.message);
    process.exit(1);
  }
}

// Ejecutar si es llamado directamente
if (require.main === module) {
  validateDataset();
}

module.exports = { validateDataset };