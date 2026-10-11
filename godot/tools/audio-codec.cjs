const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const format = { version: 2, codec: 'vorbis', channels: 1, sampleRate: 48000, quality: 6 };

function encode(pcm, out, key) {
    if (!pcm.length || pcm.length % 4) throw new Error('Invalid Float32 PCM input');
    const result = spawnSync(process.env.FFMPEG_BIN || 'ffmpeg', [
        '-hide_banner', '-loglevel', 'error', '-f', 'f32le', '-ar', '48000', '-ac', '1',
        '-i', 'pipe:0', '-c:a', 'libvorbis', '-q:a', String(format.quality),
        '-map_metadata', '-1', '-f', 'ogg', 'pipe:1'
    ], { input: pcm, maxBuffer: 16 * 1024 * 1024 });
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error(result.stderr.toString());
    const file = crypto.createHash('sha256').update(key).digest('hex').slice(0, 24) + '.vorbis';
    fs.writeFileSync(path.join(out, file), result.stdout);
    return { key, file, frames: pcm.length / 4, bytes: result.stdout.length,
        sha256: crypto.createHash('sha256').update(result.stdout).digest('hex') };
}

module.exports = { format, encode };
