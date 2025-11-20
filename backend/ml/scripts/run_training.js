/**
 * Script de entrenamiento ML
 * Ejecuta el pipeline completo de entrenamiento de modelos
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

const PeakHoursPredictiveModel = require('../peak_hours_predictive_model');
const MLETLService = require('../ml_etl_service');
const CongestionAlertSystem = require('../congestion_alert_system');

async function runTraining() {
  try {
    console.log('🚀 Iniciando entrenamiento completo del sistema ML...');
    console.log('='.repeat(60));
    
    // Conectar a MongoDB
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      dbName: 'ASISTENCIA'
    });
    
    console.log('✅ Conectado a MongoDB');
    
    // 1. Ejecutar pipeline ETL
    console.log('\\n📥 PASO 1: Pipeline ETL');
    console.log('-'.repeat(30));
    const etlService = new MLETLService(Asistencia);
    const etlResult = await etlService.runETLPipeline({
      months: 3,
      validateData: true,
      cleanData: true,
      outputFormat: 'json'
    });
    
    console.log(`✅ ETL completado: ${etlResult.transform.records} registros procesados`);
    
    // 2. Entrenar modelo de horarios pico
    console.log('\\n🧠 PASO 2: Entrenamiento de modelo predictivo');
    console.log('-'.repeat(45));
    const peakModel = new PeakHoursPredictiveModel(Asistencia);
    const trainingResult = await peakModel.trainPeakHoursModel({
      months: 3,
      testSize: 0.2
    });
    
    console.log('📊 Métricas del modelo:');
    console.log(`  Entrada - Precisión: ${(trainingResult.metrics.entrance.accuracy * 100).toFixed(2)}%`);
    console.log(`  Salida - Precisión: ${(trainingResult.metrics.exit.accuracy * 100).toFixed(2)}%`);
    console.log(`  Promedio general: ${(trainingResult.metrics.overall.accuracy * 100).toFixed(2)}%`);
    
    // 3. Configurar sistema de alertas
    console.log('\\n🚨 PASO 3: Configuración del sistema de alertas');
    console.log('-'.repeat(50));
    const alertSystem = new CongestionAlertSystem(Asistencia);
    await alertSystem.initialize();
    
    // Verificar alertas actuales
    const alertCheck = await alertSystem.checkAndGenerateAlerts();
    console.log(`✅ Sistema de alertas configurado: ${alertCheck.alertsGenerated} alertas generadas`);
    
    // 4. Generar predicciones de prueba
    console.log('\\n🔮 PASO 4: Generando predicciones de prueba');
    console.log('-'.repeat(45));
    const predictions = await peakModel.predictNext24Hours();
    
    const peakHours = predictions.predictions.filter(p => p.es_pico.general);
    console.log(`🎯 Próximas horas pico predichas: ${peakHours.length} horas`);
    
    if (peakHours.length > 0) {
      console.log('Horarios pico predichos:');
      peakHours.slice(0, 5).forEach(hour => {
        console.log(`  ${hour.hora}:00 - Total: ${hour.predicciones.total} accesos`);
      });
    }
    
    // 5. Resumen final
    console.log('\\n📋 RESUMEN DEL ENTRENAMIENTO');
    console.log('='.repeat(60));
    console.log(`✅ ETL: ${etlResult.transform.records} registros procesados`);
    console.log(`✅ Modelo: ${(trainingResult.metrics.overall.accuracy * 100).toFixed(2)}% precisión promedio`);
    console.log(`✅ Alertas: Sistema configurado y funcional`);
    console.log(`✅ Predicciones: ${predictions.predictions.length} horas predichas`);
    
    const meetsRequirement = trainingResult.metrics.overall.accuracy > 0.8;
    console.log(`\\n🎯 Requisito de precisión >80%: ${meetsRequirement ? '✅ CUMPLIDO' : '❌ NO CUMPLIDO'}`);
    
    if (meetsRequirement) {
      console.log('\\n🎉 ¡ENTRENAMIENTO EXITOSO! Sistema ML listo para producción');
    } else {
      console.log('\\n⚠️ Precisión insuficiente. Considerar:');
      console.log('   • Aumentar cantidad de datos históricos');
      console.log('   • Ajustar hiperparámetros del modelo');
      console.log('   • Mejorar calidad de los datos');
    }
    
    // Desconectar
    await mongoose.disconnect();
    console.log('\\n✅ Entrenamiento completado y desconectado de BD');
    
  } catch (error) {
    console.error('❌ Error durante el entrenamiento:', error.message);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

// Función para mostrar ayuda
function showHelp() {
  console.log('🤖 Script de Entrenamiento ML - Sistema Acees Group');
  console.log('================================================');
  console.log('');
  console.log('Uso: npm run ml:train');
  console.log('');
  console.log('Este script ejecuta:');
  console.log('1. Pipeline ETL para preparar datos');
  console.log('2. Entrenamiento de modelo predictivo de horarios pico');
  console.log('3. Configuración del sistema de alertas de congestión');
  console.log('4. Validación y generación de predicciones de prueba');
  console.log('');
  console.log('Requisitos:');
  console.log('• MongoDB Atlas conexión configurada (.env)');
  console.log('• Mínimo 100 registros de asistencias');
  console.log('• Datos de al menos 3 meses');
  console.log('');
}

// Manejar argumentos de línea de comandos
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  showHelp();
  process.exit(0);
}

// Ejecutar si es llamado directamente
if (require.main === module) {
  runTraining();
}

module.exports = { runTraining };