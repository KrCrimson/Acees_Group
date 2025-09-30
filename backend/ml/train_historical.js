'use strict';

const { extractHourlyFeaturesFromEvents } = require('./data_prep');
const { trainLinearRegression1D } = require('./regression');
const { trainKMeans1D } = require('./clustering');
const { movingAverage } = require('./timeseries');

function trainFromEvents(events) {
  const rows = extractHourlyFeaturesFromEvents(events);
  if (rows.length === 0) throw new Error('No hay datos suficientes para entrenar');
  const x = rows.map(r => r.weekday * 24 + r.hourSlot);
  const y = rows.map(r => r.count);
  const linModel = trainLinearRegression1D(x, y);
  const maSeries = movingAverage(y, 3);
  const kmeans = trainKMeans1D(y, Math.min(3, Math.max(1, Math.floor(Math.sqrt(y.length)))));
  const metadata = { updatedAt: new Date().toISOString(), n: rows.length, version: 1 };
  return { linModel, maSeries, kmeans, metadata };
}

module.exports = { trainFromEvents };


