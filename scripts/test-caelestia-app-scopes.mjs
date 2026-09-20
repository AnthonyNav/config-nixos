import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Exercise the actual patched QML function with the Quickshell boundary mocked.
const source = readFileSync(process.argv[2], 'utf8');
const body = source.match(/function launch\(entry: DesktopEntry\): void \{([\s\S]*?)\n    \}/)?.[1];
assert.ok(body, 'launcher function exists');
for (const runInTerminal of [false, true]) {
  for (const workingDirectory of ['', '/tmp/a directory with spaces']) {
    const entry = {
      id: 'scope-test', runInTerminal, workingDirectory,
      command: ['example-app', 'argument with spaces', '$HOME', '${USER}', '', '--flag', "a'b"],
    };
    const frequencies = [];
    let launched;
    vm.runInNewContext(`(function(entry) {${body}\n})(entry)`, {
      entry,
      appDb: { incrementFrequency: id => frequencies.push(id) },
      GlobalConfig: { general: { apps: { terminal: ['kitty', '--title', 'Terminal title'] } } },
      Quickshell: { shellDir: '/a shell path', execDetached: value => { launched = value; } },
    });
    assert.deepEqual(frequencies, [entry.id]);
    assert.equal(launched.workingDirectory, workingDirectory);
    const command = Array.from(launched.command);
    assert.match(command.shift(), /^\/nix\/store\/[^/]+\/bin\/systemd-run$/);
    assert.deepEqual(command, [
      '--user', '--scope', '--slice=app.slice', '--collect', '--quiet', '--expand-environment=no', '--',
      ...(runInTerminal ? ['kitty', '--title', 'Terminal title', '/a shell path/assets/wrap_term_launch.sh'] : []),
      ...entry.command,
    ]);
    assert.equal(launched.environment, undefined, 'inherit the launching environment');
  }
}
console.log('Caelestia launcher: GUI/terminal arguments and working directories preserved');
