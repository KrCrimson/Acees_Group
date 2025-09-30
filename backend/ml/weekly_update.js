'use strict';

const fs = require('fs');
const path = require('path');
const { trainFromEvents } = require('./train_historical');

const ARTIFACTS_DIR = path.join(__dirname, 'artifacts');
const ARTIFACTS_FILE = path.join(ARTIFACTS_DIR, 'model.json');

function ensureArtifactsDir() {
  if (!fs.existsSync(ARTIFACTS_DIR)) fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
}

async function runWeeklyUpdate(AsistenciaModel, rangeDays = 120) {
  const to = new Date();
  const from = new Date(to.getTime() - rangeDays * 24 * 60 * 60 * 1000);
  const events = await AsistenciaModel.find({ fecha_hora: { $gte: from, $lte: to } }).select('fecha_hora tipo puerta').lean();
  const artifacts = trainFromEvents(events);
  ensureArtifactsDir();
  fs.writeFileSync(ARTIFACTS_FILE, JSON.stringify(artifacts, null, 2), 'utf-8');
  return { artifactsPath: ARTIFACTS_FILE, metadata: artifacts.metadata };
}

module.exports = { runWeeklyUpdate, ARTIFACTS_FILE };


