const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');

function fixture(t, overrides = {}) {
    const parent = path.join(root, 'agent-tmp');
    fs.mkdirSync(parent, { recursive: true });
    const dir = fs.mkdtempSync(path.join(parent, 'android-script-test-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const script = path.join(dir, 'script');
    const android = path.join(dir, 'android');
    fs.mkdirSync(script);
    fs.mkdirSync(android);
    for (const name of ['build.sh', 'build-debug-install.sh']) {
        fs.copyFileSync(path.join(root, 'script', name), path.join(script, name));
    }
    const log = path.join(dir, 'calls.jsonl');
    const mock = path.join(dir, 'mock-tool.cjs');
    fs.writeFileSync(mock, `#!${process.execPath}
const fs = require('node:fs');
const path = require('node:path');
const args = process.argv.slice(2);
const tool = path.basename(process.argv[1]);
fs.appendFileSync(process.env.MOCK_LOG, JSON.stringify({tool, args, cwd: process.cwd()}) + '\\n');
if (tool === 'gradlew') {
    if (process.env.MOCK_BUILD_FAIL) process.exit(3);
    const out = path.join(process.cwd(), 'app/build/outputs/apk/debug');
    fs.mkdirSync(out, {recursive: true});
    for (const abi of JSON.parse(process.env.MOCK_APKS)) {
        fs.writeFileSync(path.join(out, 'app-' + abi + '-debug.apk'), 'fixture');
    }
} else if (args[0] === 'devices') {
    process.stdout.write('List of devices attached\\n' + process.env.MOCK_DEVICES);
} else if (args[2] === 'get-state') {
    process.stdout.write(process.env.MOCK_STATE + '\\n');
    if (process.env.MOCK_STATE !== 'device') process.exit(1);
} else if (args[2] === 'shell') {
    process.stdout.write((args[4] === 'ro.product.cpu.abilist' ? process.env.MOCK_ABIS : process.env.MOCK_ABI) + '\\r\\n');
} else if (args[2] === 'install') {
    if (process.env.MOCK_INSTALL_FAIL) process.exit(4);
    process.stdout.write('Success\\n');
} else {
    process.exit(9);
}
`);
    fs.chmodSync(mock, 0o755);
    fs.symlinkSync(mock, path.join(android, 'gradlew'));
    const adb = path.join(dir, 'adb');
    fs.symlinkSync(mock, adb);
    const env = {
        ...process.env,
        GRADLE_BIN: path.join(android, 'gradlew'),
        ADB_BIN: adb,
        SLINGBREAK_DEVICE: '10.126.126.1:5555',
        MOCK_LOG: log,
        MOCK_DEVICES: 'usb-device\tdevice\n',
        MOCK_STATE: 'device',
        MOCK_ABIS: 'arm64-v8a,armeabi-v7a',
        MOCK_ABI: 'arm64-v8a',
        MOCK_APKS: JSON.stringify(['arm64-v8a', 'armeabi-v7a', 'x86_64']),
        MOCK_BUILD_FAIL: '',
        MOCK_INSTALL_FAIL: '',
        ...overrides
    };
    return {
        android,
        run(name, args = []) {
            return spawnSync('bash', [path.join(script, name), ...args], {
                cwd: dir, env, encoding: 'utf8', timeout: 10000
            });
        },
        calls() {
            return fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').map(JSON.parse) : [];
        }
    };
}

test('Android script help works without Gradle or ADB', t => {
    for (const name of ['build.sh', 'build-debug-install.sh']) {
        const f = fixture(t, { GRADLE_BIN: '/missing/gradle', ADB_BIN: '/missing/adb' });
        const result = f.run(name, ['--help']);
        assert.equal(result.status, 0, result.stderr);
        assert.match(result.stdout, /Usage:/);
        assert.deepEqual(f.calls(), []);
    }
});

test('Android build commands use the Android directory and forward Gradle arguments', t => {
    const commands = {
        debug: [':app:assembleDebug'],
        release: [':app:distributeRelease'],
        test: [':app:testReleaseUnitTest'],
        lint: [':app:lintRelease'],
        check: [':app:testReleaseUnitTest', ':app:lintRelease', ':app:assembleReleaseAndroidTest']
    };
    for (const [command, tasks] of Object.entries(commands)) {
        const f = fixture(t);
        const result = f.run('build.sh', [command, '--offline', '-PappVersionCode=2']);
        assert.equal(result.status, 0, result.stderr);
        assert.deepEqual(f.calls(), [{
            tool: 'gradlew', cwd: f.android, args: [...tasks, '--offline', '-PappVersionCode=2']
        }]);
    }
});

test('Android script invalid arguments fail without invoking tools', t => {
    for (const args of [['--unknown'], ['--device'], ['--device', '--help'], ['--device='], ['one', 'two'], ['--device', 'one', 'two']]) {
        const f = fixture(t);
        assert.equal(f.run('build-debug-install.sh', args).status, 2);
        assert.deepEqual(f.calls(), []);
    }
    const f = fixture(t);
    assert.equal(f.run('build.sh', ['unknown']).status, 2);
    assert.deepEqual(f.calls(), []);
});

test('Android debug installer selects the preferred ABI and preserves the app with install -r', t => {
    for (const args of [[], ['usb-device'], ['--device', 'usb-device'], ['--device=usb-device']]) {
        const f = fixture(t);
        const result = f.run('build-debug-install.sh', args);
        assert.equal(result.status, 0, result.stderr);
        const calls = f.calls();
        const serial = args.length ? 'usb-device' : '10.126.126.1:5555';
        assert.deepEqual(calls[0].args, ['-s', serial, 'get-state']);
        assert.deepEqual(calls.find(call => call.tool === 'gradlew'), {
            tool: 'gradlew', cwd: f.android, args: [':app:assembleDebug']
        });
        assert.deepEqual(calls[calls.length - 1].args, [
            '-s', serial, 'install', '-r', path.join(f.android, 'app/build/outputs/apk/debug/app-arm64-v8a-debug.apk')
        ]);
    }
});

test('Android debug installer reads a single ABI, the final ABI and the legacy ABI fallback', t => {
    for (const overrides of [
        { MOCK_ABIS: 'x86_64' },
        { MOCK_ABIS: 'unsupported,x86_64' },
        { MOCK_ABIS: '', MOCK_ABI: 'x86_64' }
    ]) {
        const f = fixture(t, overrides);
        const result = f.run('build-debug-install.sh');
        assert.equal(result.status, 0, result.stderr);
        assert.match(f.calls().pop().args[4], /app-x86_64-debug\.apk$/);
    }
});

test('Android debug installer can discover exactly one authorized device', t => {
    const f = fixture(t, { SLINGBREAK_DEVICE: '', MOCK_DEVICES: 'offline-device\toffline\nusb-device\tdevice\n' });
    const result = f.run('build-debug-install.sh');
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(f.calls().pop().args.slice(0, 4), ['-s', 'usb-device', 'install', '-r']);
});

test('Android debug installer refuses missing, ambiguous and unready devices before building', t => {
    for (const overrides of [
        { SLINGBREAK_DEVICE: '', MOCK_DEVICES: '' },
        { SLINGBREAK_DEVICE: '', MOCK_DEVICES: 'one\tdevice\ntwo\tdevice\n' },
        { MOCK_STATE: 'offline' },
        { MOCK_STATE: 'unauthorized' }
    ]) {
        const f = fixture(t, overrides);
        const result = f.run('build-debug-install.sh');
        assert.notEqual(result.status, 0);
        assert.ok(f.calls().every(call => call.tool !== 'gradlew' && !call.args.includes('install')));
    }
});

test('Android debug installer refuses missing or incompatible APKs', t => {
    for (const overrides of [{ MOCK_APKS: '[]' }, { MOCK_ABIS: 'unsupported' }]) {
        const f = fixture(t, overrides);
        assert.notEqual(f.run('build-debug-install.sh').status, 0);
        assert.ok(f.calls().every(call => !call.args.includes('install')));
    }
});

test('Android debug installer propagates build and install failures', t => {
    const build = fixture(t, { MOCK_BUILD_FAIL: '1' });
    assert.equal(build.run('build-debug-install.sh').status, 3);
    assert.ok(build.calls().every(call => !call.args.includes('install')));
    const install = fixture(t, { MOCK_INSTALL_FAIL: '1' });
    const result = install.run('build-debug-install.sh');
    assert.equal(result.status, 4);
    assert.doesNotMatch(result.stdout, /installed successfully/);
});
