package io.github.apricityx.slingbreak;

import java.util.*;

/** Bounded stereo mixer; no allocations in the per-frame loop. */
public final class AudioMixer {
    public enum Bus { EFFECTS, UI, MUSIC }
    private static final int EFFECT_LIMIT = 64, UI_LIMIT = 16, MUSIC_LIMIT = 48;
    private static final String[] INSTRUMENTS = {"pad", "bass", "drums", "arp", "lead", "bell", "fx"};
    private final int rate;
    private final List<Voice> voices = new ArrayList<>();
    private final float[][] echo;
    private final float[][] musicEcho;
    private final float[] musicLevels = new float[INSTRUMENTS.length], musicTargets = new float[INSTRUMENTS.length];
    private float musicCutoff = 18000, musicTargetCutoff = 18000, musicLeft, musicRight;
    private float musicGain = 1, musicGainTarget = 1;
    private int musicGainFrames;
    private int musicEchoAt;
    private int echoAt;
    private long frame;
    private float gain = 1;
    private boolean muted = true, paused;
    public volatile long accepted, dropped, rendered;

    public static final class Voice {
        final float[] pcm;
        final int delay;
        final float left, right;
        final boolean wet, ui, priority;
        final Bus bus;
        int instrument;
        float volume = 1;
        long start;
        public Voice(float[] pcm, int delay, float pan, boolean wet, boolean ui, boolean priority) {
            this(pcm, delay, pan, wet, ui ? Bus.UI : Bus.EFFECTS, priority);
        }
        public Voice(float[] pcm, int delay, float pan, boolean wet, Bus bus, boolean priority) {
            this.pcm = pcm; this.delay = delay; this.wet = wet; this.ui = bus == Bus.UI; this.priority = priority;
            this.bus = bus;
            double angle = (pan + 1) * Math.PI / 4;
            left = (float) Math.cos(angle); right = (float) Math.sin(angle);
        }
    }

    public AudioMixer(int rate) {
        this.rate = rate; echo = new float[4][Math.max(1, Math.round(rate * .105f))];
        musicEcho = new float[2][Math.max(1, Math.round(rate * .34f))];
    }

    public synchronized void musicState(Map<String, Float> levels, float cutoff, boolean stop) {
        for (int i = 0; i < INSTRUMENTS.length; i++) musicTargets[i] = levels.getOrDefault(INSTRUMENTS[i], 0f);
        musicTargetCutoff = cutoff;
        if (stop) clearMusic();
    }
    public static int instrument(String name) { return Arrays.asList(INSTRUMENTS).indexOf(name); }
    public synchronized void musicFade(float target, int frames) { musicGainTarget = target; musicGainFrames = Math.max(1, frames); }
    private void clearMusic() {
        voices.removeIf(voice -> voice.bus == Bus.MUSIC);
        for (float[] channel : musicEcho) Arrays.fill(channel, 0);
        musicLeft = musicRight = 0;
        musicGain = musicGainTarget = 1; musicGainFrames = 0;
    }

    public synchronized void state(float gain, boolean muted, boolean paused) {
        this.gain = gain;
        if (muted && !this.muted) clear();
        if (paused && !this.paused) {
            voices.removeIf(voice -> !voice.ui);
            Arrays.fill(echo[0], 0); Arrays.fill(echo[1], 0);
            clearMusic();
        }
        this.muted = muted; this.paused = paused;
    }

    public synchronized int enqueue(List<Voice> batch) {
        if (batch.isEmpty()) return 0;
        Bus bus = batch.get(0).bus;
        int limit = bus == Bus.MUSIC ? MUSIC_LIMIT : bus == Bus.UI ? UI_LIMIT : EFFECT_LIMIT;
        int count = 0;
        for (Voice voice : voices) if (voice.bus == bus) count++;
        if (muted || batch.size() > limit || paused && bus != Bus.UI) { dropped++; return 0; }
        for (Voice voice : batch) if (voice.bus != bus) { dropped++; return 0; }
        boolean priority = batch.get(0).priority;
        if (count + batch.size() > limit) {
            if (!priority) { dropped++; return 0; }
            int available = 0;
            for (Voice voice : voices) if (voice.bus == bus && !voice.priority) available++;
            if (available < count + batch.size() - limit) { dropped++; return 0; }
            while (count + batch.size() > limit) {
                int victim = -1;
                for (int i = 0; i < voices.size(); i++) if (voices.get(i).bus == bus && !voices.get(i).priority) { victim = i; break; }
                voices.remove(victim);
                count--;
            }
        }
        for (Voice voice : batch) { voice.start = frame + voice.delay; voices.add(voice); }
        accepted++; return 1;
    }

    public synchronized void clear() {
        voices.clear(); for (float[] channel : echo) Arrays.fill(channel, 0); clearMusic();
    }
    public synchronized int active() { return voices.size(); }
    public synchronized int active(Bus bus) { int count = 0; for (Voice voice : voices) if (voice.bus == bus) count++; return count; }
    public synchronized float musicGain() { return musicGain; }
    public synchronized float musicCutoff() { return musicCutoff; }
    public synchronized void render(float[] out) {
        float smoothing = (float) (1 - Math.exp(-1.0 / (.4 * rate)));
        // Coefficients are block-level; no maps, strings or transcendental filter
        // calculations in the per-voice loop.
        musicCutoff += (musicTargetCutoff - musicCutoff) * (1 - (float) Math.exp(-(out.length / 2.0) / (.3 * rate)));
        float coefficient = (float) (1 - Math.exp(-2 * Math.PI * musicCutoff / rate));
        for (int i = 0; i < out.length; i += 2, frame++) {
            for (int b = 0; b < musicLevels.length; b++) musicLevels[b] += (musicTargets[b] - musicLevels[b]) * smoothing;
            if (musicGainFrames > 0) { musicGain += (musicGainTarget - musicGain) / musicGainFrames; musicGainFrames--; }
            float l = 0, r = 0, gl = 0, gr = 0, ul = 0, ur = 0, ml = 0, mr = 0, mwl = 0, mwr = 0;
            if (!muted) for (int v = 0; v < voices.size(); v++) {
                Voice voice = voices.get(v);
                long offset = frame - voice.start;
                if (offset < 0 || offset >= voice.pcm.length) continue;
                float sample = voice.pcm[(int) offset], a = sample * voice.left, b = sample * voice.right;
                if (voice.bus == Bus.MUSIC) {
                    float bus = musicLevels[voice.instrument] * voice.volume;
                    ml += a * bus; mr += b * bus;
                    if (voice.wet) { mwl += a * voice.volume; mwr += b * voice.volume; }
                    continue;
                }
                l += a; r += b;
                if (voice.wet) { if (voice.ui) { ul += a; ur += b; } else { gl += a; gr += b; } }
            }
            float el = echo[0][echoAt], er = echo[1][echoAt], il = echo[2][echoAt], ir = echo[3][echoAt];
            echo[0][echoAt] = gl + el * .18f; echo[1][echoAt] = gr + er * .18f;
            echo[2][echoAt] = ul + il * .18f; echo[3][echoAt] = ur + ir * .18f;
            l += (el + il) * .16f; r += (er + ir) * .16f;
            float mel = musicEcho[0][musicEchoAt], mer = musicEcho[1][musicEchoAt];
            musicEcho[0][musicEchoAt] = mwl + mel * .32f; musicEcho[1][musicEchoAt] = mwr + mer * .32f;
            if (++musicEchoAt == musicEcho[0].length) musicEchoAt = 0;
            musicLeft += coefficient * (ml + mel * .28f - musicLeft);
            musicRight += coefficient * (mr + mer * .28f - musicRight);
            l += musicLeft * musicGain * (.55f / .7f); r += musicRight * musicGain * (.55f / .7f);
            out[i] = muted ? 0 : (float) (.9 * Math.tanh(l * gain * .7 * 1.4));
            out[i + 1] = muted ? 0 : (float) (.9 * Math.tanh(r * gain * .7 * 1.4));
            if (++echoAt == echo[0].length) echoAt = 0;
        }
        voices.removeIf(voice -> frame - voice.start >= voice.pcm.length);
        rendered += out.length / 2;
    }
}
