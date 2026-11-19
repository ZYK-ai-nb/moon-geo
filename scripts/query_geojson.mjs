// Node handles file I/O only. Parsing, geometry, updates and queries run in MoonBit.
import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const [input, output] = process.argv.slice(2);
if (!input || process.argv.length > 4) {
  console.error('Usage: node scripts/query_geojson.mjs request.json [output.json]');
  process.exit(2);
}
try {
  const build = spawnSync('moon', ['build', 'app', '--target', 'js', '--release', '--deny-warn', '--target-dir', 'work/cli-build'], { cwd: root, encoding: 'utf8' });
  if (build.error) throw build.error;
  if (build.status !== 0) throw new Error(build.stderr || build.stdout || 'MoonBit build failed');
  const request = readFileSync(resolve(input), 'utf8');
  const { run } = createRequire(import.meta.url)(resolve(root, 'work/cli-build/js/release/build/app/app.js'));
  const report = JSON.parse(run(request));
  const text = JSON.stringify(report, null, 2) + '\n';
  if (output) writeFileSync(resolve(output), text, 'utf8');
  else process.stdout.write(text);
  if (!report.ok || report.results.some(result => !result.ok)) process.exitCode = 1;
} catch (error) {
  console.error(String(error.message || error));
  process.exitCode = 1;
}
