'use strict';

const fs = require('fs');
const path = require('path');
const { trainLinearRegression1D, predictLinearRegression1D, trainKMeans1D, movingAverage } = require('./models');

const ARTIFACTS_DIR = path.join(__dirname, 'artifacts');
const ARTIFACTS_FILE = path.join(ARTIFACTS_DIR, 'model.json');

function ensureArtifactsDir() {
  if (!fs.existsSync(ARTIFACTS_DIR)) {
    fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
  }
}

function extractFeaturesFromEvents(events) {
  // Espera eventos con campos: fecha_hora (Date), tipo ('entrada'/'salida'), puerta
  // Salida: arreglo de { hourSlot: 0..23, weekday: 0..6, count }
  const buckets = new Map();
  for (const e of events) {
    if (!e.fecha_hora) continue;
    const d = new Date(e.fecha_hora);
    const hour = d.getHours();
    const day = d.getDay();
    const key = `${day}-${hour}`;
    buckets.set(key, (buckets.get(key) || 0) + 1);
  }
  const rows = [];
  for (const [key, count] of buckets.entries()) {
    const [weekdayStr, hourStr] = key.split('-');
    rows.push({ weekday: Number(weekdayStr), hourSlot: Number(hourStr), count });
  }
  return rows.sort((a, b) => a.weekday - b.weekday || a.hourSlot - b.hourSlot);
}

function trainAllModels(events) {
  // Feature principal para regresión: hourIndex = weekday*24 + hour
  const rows = extractFeaturesFromEvents(events);
  if (rows.length === 0) {
    throw new Error('No hay datos suficientes para entrenar');
  }
  const x = rows.map(r => r.weekday * 24 + r.hourSlot);
  const y = rows.map(r => r.count);
  const linModel = trainLinearRegression1D(x, y);
  const maSeries = movingAverage(y, 3);
  const kmeans = trainKMeans1D(y, Math.min(3, Math.max(1, Math.floor(Math.sqrt(y.length)))));
  const metadata = { updatedAt: new Date().toISOString(), n: rows.length, version: 1 };
  return { linModel, maSeries, kmeans, metadata };
}

function saveArtifacts(artifacts) {
  ensureArtifactsDir();
  fs.writeFileSync(ARTIFACTS_FILE, JSON.stringify(artifacts, null, 2), 'utf-8');
}

function loadArtifacts() {
  if (!fs.existsSync(ARTIFACTS_FILE)) return null;
  const raw = fs.readFileSync(ARTIFACTS_FILE, 'utf-8');
  return JSON.parse(raw);
}

function predictFlow({ weekday, hourSlot }, artifacts) {
  const { linModel, kmeans } = artifacts;
  const x = weekday * 24 + hourSlot;
  const value = predictLinearRegression1D(linModel, x);
  // Etiqueta por k-means usando centroides más cercanos
  let best = 0;
  let bestDist = Infinity;
  for (let c = 0; c < kmeans.centroids.length; c++) {
    const d = Math.abs(value - kmeans.centroids[c]);
    if (d < bestDist) {
      bestDist = d;
      best = c;
    }
  }
  const level = kmeans.clusterLabels[best] || 'medium';
  return { value, level };
}

module.exports = {
  extractFeaturesFromEvents,
  trainAllModels,
  saveArtifacts,
  loadArtifacts,
  predictFlow,
  ARTIFACTS_FILE
};


