/**
 * Script de Ejecución del Pipeline de Entrenamiento
 * Ejecuta el pipeline completo desde línea de comandos
 */

require('dotenv').config();
const mongoose = require('mongoose');
const TrainingPipeline = require('./ml/training_pipeline');
const DatasetCollector = require('./ml/dataset_collector');

// Conectar a MongoDB
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
  dbName: 'ASISTENCIA'
});

const db = mongoose.connection;
db.on('error', console.error.bind(console, 'Error de conexión a MongoDB:'));
db.once('open', async () => {
  console.log('✅ Conectado a MongoDB Atlas');
  
  // Modelo de Asistencia
  const AsistenciaSchema = new mongoose.Schema({
    _id: String,
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
    razon_decision: String,
    timestamp_decision: Date,
    coordenadas: String,
    descripcion_ubicacion: String
  }, { collection: 'asistencias', strict: false, _id: false });
  
  const Asistencia = mongoose.model('asistencias', AsistenciaSchema);
  
  // Configuración del pipeline
  const config = {
    months: parseInt(process.argv[2]) || 3,
    testSize: parseFloat(process.argv[3]) || 0.2,
    modelType: process.argv[4] || 'logistic_regression',
    stratify: 'target'
  };
  
  console.log('\n🚀 Iniciando Pipeline de Entrenamiento de Modelo ML');
  console.log('📊 Configuración:');
  console.log(`   - Meses de datos: ${config.months}`);
  console.log(`   - Test size: ${config.testSize}`);
  console.log(`   - Tipo de modelo: ${config.modelType}`);
  console.log('');
  
  try {
    // Crear pipeline con modelo
    const collector = new DatasetCollector(Asistencia);
    const pipeline = new TrainingPipeline({ collector });
    
    // Ejecutar pipeline
    const result = await pipeline.executePipeline({
      ...config
    });
    
    console.log('\n✅ Pipeline completado exitosamente!');
    console.log(`📁 Modelo guardado en: ${result.modelPath}`);
    console.log(`📊 Reporte guardado en: ${result.reportPath}`);
    
    // Cerrar conexión
    await mongoose.connection.close();
    process.exit(0);
    
  } catch (error) {
    console.error('\n❌ Error en pipeline:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
});

