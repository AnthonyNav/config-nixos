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

const actionsSource = readFileSync(process.argv[3], 'utf8');
const actionBody = actionsSource.match(/function onClicked\(list: AppList\): void \{([\s\S]*?)\n        \}/)?.[1];
assert.ok(actionBody, 'action function exists');
const literalCommand = ['kitty', '--hold', '-e', 'example', '$HOME', 'a space', '', "a'b"];
for (const [command, sessionHandled] of [
  [[], false], [['autocomplete', 'wallpaper'], false], [['setMode', 'light'], false],
  [['poweroff'], true], [literalCommand, false],
]) {
  const list = { search: { text: '' }, screenState: { launcher: true } };
  let detached, mode, sessionCommand;
  vm.runInNewContext(`(function(list) {${actionBody}\n})(list)`, {
    list, command,
    GlobalConfig: { launcher: { actionPrefix: '>' } },
    Colours: { setMode: value => { mode = value; } },
    SessionManager: { exec: value => { sessionCommand = value; return sessionHandled; } },
    Quickshell: { execDetached: value => { detached = Array.from(value); } },
  });
  if (command.length === 0) {
    assert.equal(list.screenState.launcher, true);
  } else if (command[0] === 'autocomplete') {
    assert.equal(list.search.text, '>wallpaper ');
    assert.equal(list.screenState.launcher, true);
  } else if (command[0] === 'setMode') {
    assert.equal(mode, 'light');
  } else {
    assert.equal(sessionCommand, command);
    if (!sessionHandled) {
      assert.match(detached.shift(), /^\/nix\/store\/[^/]+\/bin\/systemd-run$/);
      assert.deepEqual(detached, ['--user', '--scope', '--slice=app.slice', '--collect', '--quiet', '--expand-environment=no', '--', ...command]);
    }
  }
  if (command !== literalCommand) assert.equal(detached, undefined);
}
console.log('Caelestia actions: literal arguments scoped; native session and search actions preserved');
