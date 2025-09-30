'use strict';

function extractHourlyFeaturesFromEvents(events) {
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

module.exports = { extractHourlyFeaturesFromEvents };


