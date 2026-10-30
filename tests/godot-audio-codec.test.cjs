const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { format, encode } = require('../godot/tools/audio-codec.cjs');

test('Godot compressed audio retains the mixer sample format and rate', () => {
    assert.deepEqual(format, { version: 2, codec: 'vorbis', channels: 1, sampleRate: 48000, quality: 6 });
    assert.throws(() => encode(Buffer.alloc(0), '.', 'empty'), /Invalid Float32/);
    assert.throws(() => encode(Buffer.alloc(3), '.', 'unaligned'), /Invalid Float32/);
});

test('Godot Vorbis encoder writes decodable mono audio with exact duration', t => {
    const ffmpeg = process.env.FFMPEG_BIN || 'ffmpeg';
    const available = spawnSync(ffmpeg, ['-version']);
    if (available.error) return t.skip('FFmpeg is not installed');
    const parent = path.resolve(__dirname, '../agent-tmp');
    fs.mkdirSync(parent, { recursive: true });
    const out = fs.mkdtempSync(path.join(parent, 'vorbis-test-'));
    t.after(() => fs.rmSync(out, { recursive: true, force: true }));
    const frames = 48000;
    const pcm = Buffer.alloc(frames * 4);
    for (let i = 0; i < frames; i++) pcm.writeFloatLE(Math.sin(i * Math.PI * 2 * 440 / 48000) * .5, i * 4);
    const sample = encode(pcm, out, 'test-tone');
    assert.equal(sample.frames, frames);
    assert.ok(sample.bytes < pcm.length / 4);
    const decoded = spawnSync(ffmpeg, ['-v', 'error', '-i', path.join(out, sample.file),
        '-f', 'f32le', '-ar', '48000', '-ac', '1', 'pipe:1']);
    assert.equal(decoded.status, 0, String(decoded.stderr));
    // FFmpeg may drop a short Vorbis priming block; Godot uses the original frame count.
    assert.ok(Math.abs(decoded.stdout.length / 4 - frames) <= 128);
    let energy = 0;
    for (let i = 0; i < decoded.stdout.length; i += 4) energy += decoded.stdout.readFloatLE(i) ** 2;
    assert.ok(energy / (decoded.stdout.length / 4) > .1);
});
