.pragma library

function relative(iso, nowMs) {
  const min = Math.floor((nowMs - Date.parse(iso)) / 60000);
  if (!(min >= 1)) return { key: "time.now", n: 0 };
  if (min < 60) return { key: "time.minutes", n: min };
  if (min < 1440) return { key: "time.hours", n: Math.floor(min / 60) };
  return { key: "time.days", n: Math.floor(min / 1440) };
}
