export function startVisiblePolling(options: {
  task: () => void | Promise<void>;
  intervalMs: number;
  runOnStart?: boolean;
}): { run: () => Promise<void>; stop: () => void };
