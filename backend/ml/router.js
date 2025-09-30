'use strict';

const express = require('express');
const router = express.Router();

const { extractHourlyFeaturesFromEvents } = require('./data_prep');
const { trainFromEvents } = require('./train_historical');
const { runWeeklyUpdate, ARTIFACTS_FILE } = require('./weekly_update');
const { trainLinearRegression1D, predictLinear } = require('./regression');
const { trainKMeans1D } = require('./clustering');
const { movingAverage } = require('./timeseries');
const { topSuggestions } = require('./suggestions');
const fs = require('fs');

function loadArtifacts() {
  if (!fs.existsSync(ARTIFACTS_FILE)) return null;
  return JSON.parse(fs.readFileSync(ARTIFACTS_FILE, 'utf-8'));
}

// Expectativa: un inyector de modelos pasará la colección de asistencias en app.use
function createMlRouter(AsistenciaModel) {
  // Entrenar modelos con historial de asistencias (mín. 3 meses ideal, RF009.4)
  router.post('/train', async (req, res) => {
    try {
      const { from, to } = req.body || {};
      const query = {};
      if (from || to) {
        query.fecha_hora = {};
        if (from) query.fecha_hora.$gte = new Date(from);
        if (to) query.fecha_hora.$lte = new Date(to);
      }
      const events = await AsistenciaModel.find(query).select('fecha_hora tipo puerta').lean();
      const artifacts = trainFromEvents(events);
      fs.mkdirSync(require('path').dirname(ARTIFACTS_FILE), { recursive: true });
      fs.writeFileSync(ARTIFACTS_FILE, JSON.stringify(artifacts, null, 2), 'utf-8');
      res.json({ message: 'Modelo entrenado', artifactsPath: ARTIFACTS_FILE, metadata: artifacts.metadata });
    } catch (err) {
      res.status(500).json({ error: 'Error en entrenamiento', details: err.message });
    }
  });

  // Predicción para un día/hora concretos (RF008 y RF009)
  router.post('/predict', (req, res) => {
    try {
      const { weekday, hourSlot } = req.body || {};
      if (weekday === undefined || hourSlot === undefined) {
        return res.status(400).json({ error: 'weekday y hourSlot son requeridos' });
      }
      const artifacts = loadArtifacts();
      if (!artifacts) {
        return res.status(404).json({ error: 'Modelo no entrenado' });
      }
      const x = Number(weekday) * 24 + Number(hourSlot);
      const value = predictLinear(artifacts.linModel, x);
      // Etiqueta simple usando centroides entrenados
      let best = 0; let bestDist = Infinity;
      for (let c = 0; c < artifacts.kmeans.centroids.length; c++) {
        const d = Math.abs(value - artifacts.kmeans.centroids[c]);
        if (d < bestDist) { bestDist = d; best = c; }
      }
      const level = artifacts.kmeans.clusterLabels[best] || 'medium';
      const pred = { value, level };
      res.json({ prediction: pred, metadata: artifacts.metadata });
    } catch (err) {
      res.status(500).json({ error: 'Error en predicción', details: err.message });
    }
  });

  // Sugerencias de horarios de buses (simple: top-N horas con mayor valor predicho)
  router.get('/suggestions', (req, res) => {
    try {
      const artifacts = loadArtifacts();
      if (!artifacts) {
        return res.status(404).json({ error: 'Modelo no entrenado' });
      }
      const predictFn = ({ weekday, hourSlot }) => {
        const x = weekday * 24 + hourSlot;
        const value = predictLinear(artifacts.linModel, x);
        let best = 0; let bestDist = Infinity;
        for (let c = 0; c < artifacts.kmeans.centroids.length; c++) {
          const d = Math.abs(value - artifacts.kmeans.centroids[c]);
          if (d < bestDist) { bestDist = d; best = c; }
        }
        return { value, level: artifacts.kmeans.clusterLabels[best] || 'medium' };
      };
      const top = Number(req.query.top || 10);
      const list = topSuggestions(predictFn, { days: [1,2,3,4,5], hours: Array.from({length:17}, (_,i)=>i+6), top });
      res.json({ top: list });
    } catch (err) {
      res.status(500).json({ error: 'Error generando sugerencias', details: err.message });
    }
  });

  // Entrenamiento histórico directo (alias) y actualización semanal simulada
  router.post('/train-historical', async (req, res) => {
    try {
      const events = await AsistenciaModel.find().select('fecha_hora tipo puerta').lean();
      const artifacts = trainFromEvents(events);
      fs.mkdirSync(require('path').dirname(ARTIFACTS_FILE), { recursive: true });
      fs.writeFileSync(ARTIFACTS_FILE, JSON.stringify(artifacts, null, 2), 'utf-8');
      res.json({ message: 'Entrenamiento histórico completo', metadata: artifacts.metadata });
    } catch (err) {
      res.status(500).json({ error: 'Error en train-historical', details: err.message });
    }
  });

  router.post('/weekly-update', async (req, res) => {
    try {
      const { rangeDays } = req.body || {};
      const result = await runWeeklyUpdate(AsistenciaModel, Number(rangeDays) || 120);
      res.json({ message: 'Weekly update ejecutado', ...result });
    } catch (err) {
      res.status(500).json({ error: 'Error en weekly-update', details: err.message });
    }
  });

  return router;
}

module.exports = createMlRouter;


