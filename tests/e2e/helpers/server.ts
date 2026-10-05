import { spawn, ChildProcess } from 'node:child_process';
import * as fs from 'node:fs';
import * as net from 'node:net';
import * as os from 'node:os';
import * as path from 'node:path';

export type Runtime = 'shiny' | 'hotshiny';

export interface RunningApp {
  runtime: Runtime;
  url: string;
  /** Directory the app runs from (a private copy of the fixture). */
  dir: string;
  logs: () => string;
  stop: () => Promise<void>;
}

export const FIXTURES_DIR = path.resolve(__dirname, '..', 'fixtures');
const LAUNCHER = path.resolve(__dirname, 'launch.R');

async function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address();
      const port = typeof addr === 'object' && addr ? addr.port : 0;
      srv.close(() => resolve(port));
    });
  });
}

function copyDir(src: string, dest: string) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name);
    const d = path.join(dest, entry.name);
    if (entry.isDirectory()) copyDir(s, d);
    else fs.copyFileSync(s, d);
  }
}

export interface StartOptions {
  runtime: Runtime;
  fixture: string;
  hotReload?: boolean;
  timeoutMs?: number;
}

/**
 * Copy a fixture into a temp dir and launch it under the requested runtime.
 * Resolves once the R process prints shiny's "Listening on" line.
 */
export async function startApp(opts: StartOptions): Promise<RunningApp> {
  const src = path.join(FIXTURES_DIR, opts.fixture);
  if (!fs.existsSync(src)) throw new Error(`Unknown fixture: ${opts.fixture}`);
  const root = fs.mkdtempSync(path.join(os.tmpdir(), `hs-e2e-${opts.fixture}-`));
  const dir = path.join(root, opts.fixture);
  copyDir(src, dir);

  const port = await freePort();
  let out = '';
  const proc: ChildProcess = spawn(
    'Rscript',
    [LAUNCHER, opts.runtime, dir, String(port), opts.hotReload ? 'true' : 'false'],
    { cwd: dir, env: { ...process.env, R_LIBS_USER: process.env.R_LIBS_USER ?? '' }, stdio: ['ignore', 'pipe', 'pipe'] },
  );
  proc.stdout?.on('data', (d) => (out += d.toString()));
  proc.stderr?.on('data', (d) => (out += d.toString()));

  const timeout = opts.timeoutMs ?? 60_000;
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`App ${opts.fixture} (${opts.runtime}) did not start in ${timeout}ms.\n${out}`)), timeout);
    const check = () => {
      if (/Listening on http/.test(out)) {
        clearTimeout(timer);
        resolve();
      }
    };
    proc.stdout?.on('data', check);
    proc.stderr?.on('data', check);
    proc.on('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`App ${opts.fixture} (${opts.runtime}) exited with code ${code}.\n${out}`));
    });
  });

  const url = `http://127.0.0.1:${port}/`;
  // "Listening on" can be printed a moment before the socket accepts connections.
  const deadline = Date.now() + timeout;
  for (;;) {
    const ok = await fetch(url).then((r) => r.ok, () => false);
    if (ok) break;
    if (Date.now() > deadline) throw new Error(`App ${opts.fixture} (${opts.runtime}) never answered HTTP.\n${out}`);
    await new Promise((r) => setTimeout(r, 100));
  }

  return {
    runtime: opts.runtime,
    url,
    dir,
    logs: () => out,
    stop: async () => {
      if (proc.exitCode !== null) return;
      await new Promise<void>((resolve) => {
        proc.once('exit', () => resolve());
        proc.kill('SIGTERM');
        setTimeout(() => proc.kill('SIGKILL'), 3000);
      });
      fs.rmSync(root, { recursive: true, force: true });
    },
  };
}
