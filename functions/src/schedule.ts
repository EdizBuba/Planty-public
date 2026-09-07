const MINUTES_PER_DAY = 24 * 60;

/** Invalid historical data must not accidentally trigger a notification. */
export function notificationMinute(time: unknown, delay: unknown): number | null {
  if (typeof time !== "string" || !/^\d{2}:\d{2}$/.test(time)) return null;
  const [hours, minutes] = time.split(":").map(Number);
  if (hours > 23 || minutes > 59) return null;

  const rawDelay = delay ?? 30;
  if (typeof rawDelay !== "number" && typeof rawDelay !== "string") return null;
  if (typeof rawDelay === "string" && !/^\d+$/.test(rawDelay)) return null;
  const parsedDelay = Number(rawDelay);
  if (!Number.isInteger(parsedDelay) || parsedDelay < 0 || parsedDelay >= MINUTES_PER_DAY) return null;
  return (hours * 60 + minutes - parsedDelay + MINUTES_PER_DAY) % MINUTES_PER_DAY;
}

export function parisMinute(now: Date): number {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Paris",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);
  const hour = Number(parts.find((part) => part.type === "hour")?.value);
  const minute = Number(parts.find((part) => part.type === "minute")?.value);
  return hour * 60 + minute;
}

/** Opt-in guard: disabled means no database reads or notification sends. */
export async function runWhenEnabled(enabled: boolean, task: () => Promise<void>): Promise<void> {
  if (!enabled) return;
  await task();
}
