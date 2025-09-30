'use strict';

function topSuggestions(predictFn, opts = { days: [1,2,3,4,5], hours: [6,7,8,9,12,13,17,18,19,20], top: 10 }) {
  const suggestions = [];
  for (const d of opts.days) {
    for (const h of opts.hours) {
      const pred = predictFn({ weekday: d, hourSlot: h });
      suggestions.push({ weekday: d, hourSlot: h, value: pred.value, level: pred.level });
    }
  }
  suggestions.sort((a, b) => b.value - a.value);
  return suggestions.slice(0, opts.top || 10);
}

module.exports = { topSuggestions };


