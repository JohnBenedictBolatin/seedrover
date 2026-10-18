// Each mounted consumer owns one timer. No work is queued while hidden/offline.
export function startVisiblePolling({ task, intervalMs, runOnStart = true }) {
  const browser = window;
  const page = document;
  const network = navigator;
  let stopped = false;
  let timer;
  let running = false;
  let lastStarted = -Infinity;
  const available = () => !stopped && page.visibilityState === 'visible' && network.onLine;
  const clear = () => browser.clearTimeout(timer);
  const schedule = () => {
    clear();
    if (available() && !running) timer = browser.setTimeout(() => void run(), intervalMs);
  };
  const run = async () => {
    if (!available() || running) return;
    clear();
    running = true;
    lastStarted = Date.now();
    try {
      await task();
    } finally {
      running = false;
      schedule();
    }
  };
  const wake = () => {
    clear();
    if (!available() || running) return;
    // Visibility and online often arrive together; one check is sufficient.
    if (Date.now() - lastStarted < 1000) schedule();
    else void run();
  };
  page.addEventListener('visibilitychange', wake);
  browser.addEventListener('online', wake);
  browser.addEventListener('offline', clear);
  if (runOnStart) void run();
  else schedule();
  return {
    run,
    stop() {
      stopped = true;
      clear();
      page.removeEventListener('visibilitychange', wake);
      browser.removeEventListener('online', wake);
      browser.removeEventListener('offline', clear);
    },
  };
}
