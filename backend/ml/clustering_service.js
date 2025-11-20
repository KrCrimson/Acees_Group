/**
 * Servicio de Clustering
 * Implementa K-means para agrupar patrones similares
 * US042 - Clustering
 */

const DatasetCollector = require('./dataset_collector');

class ClusteringService {
  constructor(AsistenciaModel) {
    this.collector = new DatasetCollector(AsistenciaModel);
    this.maxIterations = 100;
    this.convergenceThreshold = 0.001;
  }

  /**
   * Ejecuta clustering K-means en los datos
   */
  async performClustering(options = {}) {
    const {
      months = 3,
      k = null, // Si es null, se calcula óptimo
      features = ['hora', 'dia_semana', 'tipo_movimiento'],
      maxK = 10,
      calculateOptimalK = true
    } = options;

    try {
      // 1. Recopilar datos
      const dataset = await this.collector.collectHistoricalDataset({
        months,
        includeFeatures: true,
        outputFormat: 'json'
      });

      const datasetContent = await require('fs').promises.readFile(dataset.filepath, 'utf8');
      const data = JSON.parse(datasetContent);

      // 2. Preparar características
      const featuresData = this.prepareFeatures(data, features);

      // 3. Normalizar datos
      const normalizedData = this.normalizeData(featuresData);

      // 4. Calcular K óptimo si es necesario
      let optimalK = k;
      if (calculateOptimalK || !k) {
        optimalK = await this.findOptimalK(normalizedData, maxK);
      }

      // 5. Ejecutar K-means
      const clusters = this.kmeans(normalizedData, optimalK);

      // 6. Calcular métricas de validación
      const silhouette = this.calculateSilhouette(normalizedData, clusters);
      const inertia = this.calculateInertia(normalizedData, clusters);

      // 7. Analizar clusters
      const clusterAnalysis = this.analyzeClusters(clusters, features);

      return {
        success: true,
        k: optimalK,
        clusters: clusters,
        metrics: {
          silhouette: silhouette,
          inertia: inertia,
          elbow: await this.calculateElbowMethod(normalizedData, maxK)
        },
        analysis: clusterAnalysis,
        features: features,
        totalSamples: normalizedData.length
      };
    } catch (error) {
      throw new Error(`Error ejecutando clustering: ${error.message}`);
    }
  }

  /**
   * Prepara características para clustering
   */
  prepareFeatures(data, features) {
    return data.map(record => {
      const featureVector = [];
      features.forEach(feature => {
        if (feature === 'tipo_movimiento') {
          featureVector.push(record.tipo_movimiento === 'entrada' ? 1 : 0);
        } else if (record[feature] !== undefined) {
          featureVector.push(record[feature]);
        } else {
          featureVector.push(0);
        }
      });
      return {
        originalIndex: data.indexOf(record),
        features: featureVector,
        originalData: record
      };
    });
  }

  /**
   * Normaliza datos (Z-score)
   */
  normalizeData(data) {
    if (data.length === 0) return [];

    const featureCount = data[0].features.length;
    const means = [];
    const stds = [];

    // Calcular medias
    for (let i = 0; i < featureCount; i++) {
      const values = data.map(d => d.features[i]);
      const mean = values.reduce((a, b) => a + b, 0) / values.length;
      means.push(mean);
      
      const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
      const std = Math.sqrt(variance);
      stds.push(std || 1); // Evitar división por cero
    }

    // Normalizar
    return data.map(d => ({
      ...d,
      features: d.features.map((val, i) => (val - means[i]) / stds[i])
    }));
  }

  /**
   * Encuentra K óptimo usando método Elbow
   */
  async findOptimalK(data, maxK) {
    const inertias = [];
    
    for (let k = 2; k <= maxK; k++) {
      const clusters = this.kmeans(data, k);
      const inertia = this.calculateInertia(data, clusters);
      inertias.push({ k, inertia });
    }

    // Calcular puntos de inflexión
    const optimalK = this.findElbowPoint(inertias);
    return optimalK;
  }

  /**
   * Encuentra punto de codo (elbow point)
   */
  findElbowPoint(inertias) {
    if (inertias.length < 3) return 2;

    // Calcular tasa de cambio
    const rates = [];
    for (let i = 1; i < inertias.length; i++) {
      const rate = inertias[i - 1].inertia - inertias[i].inertia;
      rates.push(rate);
    }

    // Encontrar mayor cambio (elbow)
    let maxRate = 0;
    let optimalK = 2;
    
    for (let i = 0; i < rates.length; i++) {
      if (rates[i] > maxRate) {
        maxRate = rates[i];
        optimalK = inertias[i + 1].k;
      }
    }

    return optimalK;
  }

  /**
   * Algoritmo K-means
   */
  kmeans(data, k) {
    if (data.length === 0) return [];

    const featureCount = data[0].features.length;
    
    // Inicializar centroides aleatoriamente
    let centroids = this.initializeCentroids(data, k, featureCount);
    let clusters = [];
    let previousInertia = Infinity;

    for (let iteration = 0; iteration < this.maxIterations; iteration++) {
      // Asignar puntos a clusters
      clusters = this.assignToClusters(data, centroids);

      // Actualizar centroides
      const newCentroids = this.updateCentroids(clusters, featureCount);

      // Calcular inercia
      const inertia = this.calculateInertia(data, clusters);

      // Verificar convergencia
      if (Math.abs(previousInertia - inertia) < this.convergenceThreshold) {
        break;
      }

      previousInertia = inertia;
      centroids = newCentroids;
    }

    return clusters;
  }

  /**
   * Inicializa centroides aleatoriamente
   */
  initializeCentroids(data, k, featureCount) {
    const centroids = [];
    const usedIndices = new Set();

    for (let i = 0; i < k; i++) {
      let randomIndex;
      do {
        randomIndex = Math.floor(Math.random() * data.length);
      } while (usedIndices.has(randomIndex));
      
      usedIndices.add(randomIndex);
      centroids.push([...data[randomIndex].features]);
    }

    return centroids;
  }

  /**
   * Asigna puntos al cluster más cercano
   */
  assignToClusters(data, centroids) {
    const clusters = centroids.map(() => ({ points: [], centroid: null }));

    data.forEach(point => {
      let minDistance = Infinity;
      let closestCluster = 0;

      centroids.forEach((centroid, index) => {
        const distance = this.euclideanDistance(point.features, centroid);
        if (distance < minDistance) {
          minDistance = distance;
          closestCluster = index;
        }
      });

      clusters[closestCluster].points.push(point);
    });

    // Actualizar centroides
    clusters.forEach((cluster, index) => {
      cluster.centroid = centroids[index];
    });

    return clusters;
  }

  /**
   * Actualiza centroides
   */
  updateCentroids(clusters, featureCount) {
    return clusters.map(cluster => {
      if (cluster.points.length === 0) {
        return new Array(featureCount).fill(0);
      }

      const newCentroid = new Array(featureCount).fill(0);
      cluster.points.forEach(point => {
        point.features.forEach((val, i) => {
          newCentroid[i] += val;
        });
      });

      return newCentroid.map(sum => sum / cluster.points.length);
    });
  }

  /**
   * Calcula distancia euclidiana
   */
  euclideanDistance(point1, point2) {
    let sum = 0;
    for (let i = 0; i < point1.length; i++) {
      sum += Math.pow(point1[i] - point2[i], 2);
    }
    return Math.sqrt(sum);
  }

  /**
   * Calcula inercia (within-cluster sum of squares)
   */
  calculateInertia(data, clusters) {
    let inertia = 0;

    clusters.forEach(cluster => {
      if (cluster.points.length === 0) return;

      cluster.points.forEach(point => {
        const distance = this.euclideanDistance(point.features, cluster.centroid);
        inertia += distance * distance;
      });
    });

    return inertia;
  }

  /**
   * Calcula coeficiente de silhouette
   */
  calculateSilhouette(data, clusters) {
    if (data.length === 0) return 0;

    let totalSilhouette = 0;

    clusters.forEach((cluster, clusterIndex) => {
      cluster.points.forEach(point => {
        // Distancia promedio intra-cluster (a)
        const a = cluster.points.length > 1
          ? cluster.points
              .filter(p => p !== point)
              .reduce((sum, p) => sum + this.euclideanDistance(point.features, p.features), 0) /
            (cluster.points.length - 1)
          : 0;

        // Distancia promedio al cluster más cercano (b)
        let minB = Infinity;
        clusters.forEach((otherCluster, otherIndex) => {
          if (otherIndex !== clusterIndex && otherCluster.points.length > 0) {
            const avgDistance = otherCluster.points.reduce(
              (sum, p) => sum + this.euclideanDistance(point.features, p.features), 0
            ) / otherCluster.points.length;
            minB = Math.min(minB, avgDistance);
          }
        });

        // Silhouette para este punto
        const silhouette = minB !== Infinity && (a + minB) > 0
          ? (minB - a) / Math.max(a, minB)
          : 0;

        totalSilhouette += silhouette;
      });
    });

    return totalSilhouette / data.length;
  }

  /**
   * Calcula métricas del método Elbow
   */
  async calculateElbowMethod(data, maxK) {
    const results = [];
    
    for (let k = 2; k <= maxK; k++) {
      const clusters = this.kmeans(data, k);
      const inertia = this.calculateInertia(data, clusters);
      const silhouette = this.calculateSilhouette(data, clusters);
      
      results.push({
        k,
        inertia,
        silhouette
      });
    }

    return results;
  }

  /**
   * Analiza clusters encontrados
   */
  analyzeClusters(clusters, features) {
    return clusters.map((cluster, index) => {
      if (cluster.points.length === 0) {
        return {
          clusterId: index,
          size: 0,
          characteristics: {}
        };
      }

      // Analizar características promedio
      const characteristics = {};
      features.forEach((feature, featureIndex) => {
        const values = cluster.points.map(p => p.originalData[feature]);
        if (values.length > 0) {
          if (typeof values[0] === 'number') {
            characteristics[feature] = {
              average: values.reduce((a, b) => a + b, 0) / values.length,
              min: Math.min(...values),
              max: Math.max(...values)
            };
          } else {
            // Contar frecuencias para valores categóricos
            const freq = {};
            values.forEach(v => {
              freq[v] = (freq[v] || 0) + 1;
            });
            characteristics[feature] = {
              distribution: freq,
              mostCommon: Object.entries(freq).sort((a, b) => b[1] - a[1])[0][0]
            };
          }
        }
      });

      return {
        clusterId: index,
        size: cluster.points.length,
        centroid: cluster.centroid,
        characteristics: characteristics
      };
    });
  }
}

module.exports = ClusteringService;

