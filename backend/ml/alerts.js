'use strict';

function buildCongestionAlerts(predictions, thresholdLevel = 'high') {
  const levels = { low: 0, medium: 1, high: 2 };
  const minLevel = levels[thresholdLevel] ?? 2;
  return predictions.filter(p => (levels[p.level] ?? 0) >= minLevel)
    .map(p => ({ type: 'congestion', weekday: p.weekday, hourSlot: p.hourSlot, expected: p.value, level: p.level }));
}

module.exports = { buildCongestionAlerts };


