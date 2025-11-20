/**
 * Servicio Integrado ETL para ML
 * Orquesta ETL completo con limpieza y validación
 */

const HistoricalDataETL = require('./historical_data_etl');
const DataCleaningService = require('./data_cleaning_service');
const DataQualityValidator = require('./data_quality_validator');
const MLDataStructure = require('./ml_data_structure');

class MLETLService {
  constructor(AsistenciaModel) {
    this.etl = new HistoricalDataETL(AsistenciaModel);
    this.cleaning = new DataCleaningService();
    this.validator = new DataQualityValidator();
    this.structure = new MLDataStructure();
  }

  /**
   * Ejecuta pipeline ETL completo para ML
   */
  async executeMLETLPipeline(options = {}) {
    const {
      months = 3,
      startDate = null,
      endDate = null,
      cleanData = true,
      validateData = true,
      aggregateByHour = true,
      normalizeStructure = true
    } = options;

    try {
      console.log('🚀 Iniciando pipeline ETL completo para ML...');

      // 1. EXTRACT - Extraer datos históricos
      console.log('📥 Paso 1: Extrayendo datos históricos...');
      const rawData = await this.etl.extractHistoricalData({
        months,
        startDate,
        endDate
      });

      console.log(`✅ Extraídos ${rawData.length} registros`);

      // 2. VALIDATE RAW - Validar datos raw
      console.log('🔍 Paso 2: Validando datos raw...');
      const rawValidation = await this.validator.validateDataQuality(rawData);
      
      if (!rawValidation.isValid && rawValidation.overallScore < 0.5) {
        throw new Error(`Datos raw de baja calidad (score: ${rawValidation.overallScore})`);
      }

      console.log(`✅ Validación raw: ${rawValidation.overallScore * 100}%`);

      // 3. TRANSFORM - Transformar datos
      console.log('🔧 Paso 3: Transformando datos...');
      let transformedData = await this.etl.transformData(rawData, {
        aggregateByHour
      });

      console.log(`✅ Transformados ${transformedData.length} registros`);

      // 4. CLEAN - Limpiar datos
      let cleanedData = transformedData;
      let cleaningReport = null;

      if (cleanData) {
        console.log('🧹 Paso 4: Limpiando datos...');
        const cleaningResult = await this.cleaning.cleanDataset(transformedData, {
          removeOutliers: true,
          handleMissing: true,
          normalize: false,
          encodeCategorical: false,
          validateAfterCleaning: true
        });

        cleanedData = cleaningResult.cleanedData;
        cleaningReport = cleaningResult.report;

        console.log(`✅ Limpieza completada: ${cleanedData.length} registros finales`);
      }

      // 5. NORMALIZE STRUCTURE - Normalizar a estructura ML
      let mlData = cleanedData;
      if (normalizeStructure) {
        console.log('📐 Paso 5: Normalizando a estructura ML...');
        mlData = this.structure.normalizeToMLStructure(cleanedData);
        console.log(`✅ Estructura ML normalizada`);
      }

      // 6. VALIDATE ML - Validar estructura ML
      let mlValidation = null;
      if (validateData) {
        console.log('✅ Paso 6: Validando estructura ML...');
        const structureValidation = this.structure.validateStructure(mlData);
        mlValidation = await this.validator.validateForML(mlData);

        if (!structureValidation.isValid) {
          console.warn(`⚠️ Estructura ML: ${structureValidation.errors.length} errores`);
        }

        console.log(`✅ Validación ML: ${mlValidation.readyForML ? 'LISTO' : 'NO LISTO'}`);
      }

      // 7. LOAD - Guardar datos procesados
      console.log('💾 Paso 7: Guardando datos procesados...');
      const processedPath = await this.etl.loadProcessedData(mlData);

      // 8. Generar reporte final
      const finalValidation = await this.validator.validateDataQuality(mlData);

      const report = {
        success: true,
        pipeline: {
          extract: {
            records: rawData.length,
            validation: rawValidation
          },
          transform: {
            records: transformedData.length,
            aggregated: aggregateByHour
          },
          clean: cleaningReport,
          normalize: {
            records: mlData.length,
            structure: normalizeStructure
          },
          validate: {
            quality: finalValidation,
            ml: mlValidation
          },
          load: {
            path: processedPath
          }
        },
        finalMetrics: {
          totalRecords: mlData.length,
          qualityScore: finalValidation.overallScore,
          readyForML: mlValidation?.readyForML || false
        },
        timestamp: new Date().toISOString()
      };

      console.log('✅ Pipeline ETL completado exitosamente');
      console.log(`📊 Calidad final: ${(finalValidation.overallScore * 100).toFixed(1)}%`);
      console.log(`🤖 Listo para ML: ${mlValidation?.readyForML ? 'SÍ' : 'NO'}`);

      return report;
    } catch (error) {
      throw new Error(`Error en pipeline ETL para ML: ${error.message}`);
    }
  }

  /**
   * Obtiene estadísticas del dataset procesado
   */
  async getDatasetStatistics(dataPath = null) {
    return await this.etl.getDatasetStatistics(dataPath);
  }

  /**
   * Valida calidad de dataset existente
   */
  async validateExistingDataset(dataPath) {
    try {
      const fs = require('fs').promises;
      const content = await fs.readFile(dataPath, 'utf8');
      const data = JSON.parse(content);

      const qualityValidation = await this.validator.validateDataQuality(data);
      const mlValidation = await this.validator.validateForML(data);
      const structureValidation = this.structure.validateStructure(data);

      return {
        quality: qualityValidation,
        ml: mlValidation,
        structure: structureValidation,
        readyForML: mlValidation.readyForML && structureValidation.isValid
      };
    } catch (error) {
      throw new Error(`Error validando dataset: ${error.message}`);
    }
  }

  /**
   * Obtiene estructura ML definida
   */
  getMLStructure() {
    return this.structure.defineMLStructure();
  }

  /**
   * Genera reporte de calidad completo
   */
  async generateQualityReport(data) {
    const qualityValidation = await this.validator.validateDataQuality(data, {
      generateReport: true
    });

    return qualityValidation.report;
  }
}

module.exports = MLETLService;

