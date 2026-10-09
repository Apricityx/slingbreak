package io.github.apricityx.slingbreak;

import android.content.Context;
import android.media.*;
import android.os.*;
import android.util.Base64;
import android.util.Log;
import android.webkit.JavascriptInterface;
import java.nio.*;
import java.util.*;
import org.json.*;

/** Audio-only interface for the bundled, frame-free game. No files/URLs exposed. */
public final class NativeAudio implements AutoCloseable {
    private static final int MAX_BYTES = 32 * 1024 * 1024, MAX_SAMPLE_BYTES = 1024 * 1024;
    private final AudioManager manager;
    private final AudioAttributes attributes = new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build();
    private final Map<Integer, float[]> samples = new HashMap<>();
    private final LinkedHashMap<Integer, float[]> musicSamples = new LinkedHashMap<>(16, .75f, true);
    private int musicBytes;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final AudioFocusRequest focus;
    private volatile boolean foreground, focusGranted, running, closed, documentActive, outputActive;
    private volatile AudioTrack track;
    private AudioMixer mixer;
    private int session, sequence, rate, bytes;
    private float gain = 1;
    private boolean muted = true, paused;

    public NativeAudio(Context context) {
        manager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener(change -> {
                synchronized (NativeAudio.this) {
                    if (closed || !documentActive) return;
                    focusGranted = change == AudioManager.AUDIOFOCUS_GAIN;
                    applyState();
                }
            }, main).build();
    }

    public synchronized void foreground(boolean value) {
        foreground = value;
        if (!value) abandonFocus();
        else if (running && !muted) acquireFocus();
        applyState();
    }
    public synchronized void document(boolean value) {
        documentActive = value;
        if (!value) releaseInternal();
    }
    private boolean valid(int token) { return !closed && documentActive && token == session && session != 0; }

    @JavascriptInterface public String capabilities() { return "{\"version\":2,\"gain\":true,\"ui\":true,\"music\":true,\"batch\":true,\"backend\":\"native-audiotrack\"}"; }
    @JavascriptInterface public synchronized String begin() {
        if (closed || !documentActive) return "{\"error\":\"inactive document\"}";
        releaseInternal();
        try {
            rate = Integer.parseInt(manager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE));
        } catch (Exception ignored) { rate = 48000; }
        if (rate < 22050 || rate > 96000) rate = 48000;
        session = ++sequence;
        mixer = new AudioMixer(rate);
        return "{\"version\":1,\"session\":" + session + ",\"sampleRate\":" + rate + ",\"backend\":\"native-audiotrack\"}";
    }

    @JavascriptInterface public synchronized boolean upload(int token, int id, String encoded) {
        if (!valid(token) || running || id < 0 || id >= 512 || samples.containsKey(id)
            || encoded == null || encoded.length() > MAX_SAMPLE_BYTES * 4 / 3 + 8) return false;
        try {
            byte[] data = Base64.decode(encoded, Base64.NO_WRAP);
            if (data.length == 0 || data.length % 4 != 0 || data.length > MAX_SAMPLE_BYTES || bytes + data.length > MAX_BYTES) return false;
            float[] pcm = new float[data.length / 4];
            FloatBuffer buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer();
            buffer.get(pcm);
            for (float value : pcm) if (!Float.isFinite(value) || Math.abs(value) > 4) return false;
            samples.put(id, pcm); bytes += data.length; return true;
        } catch (Exception error) { return false; }
    }

    @JavascriptInterface public synchronized boolean commit(int token) {
        if (!valid(token) || running || samples.isEmpty()) return false;
        try {
            int min = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_FLOAT);
            if (min <= 0) return false;
            track = new AudioTrack.Builder().setAudioAttributes(attributes).setAudioFormat(new AudioFormat.Builder()
                .setSampleRate(rate).setChannelMask(AudioFormat.CHANNEL_OUT_STEREO).setEncoding(AudioFormat.ENCODING_PCM_FLOAT).build())
                .setBufferSizeInBytes(Math.max(min, 256 * 8 * 2)).setTransferMode(AudioTrack.MODE_STREAM)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY).build();
            if (track.getState() != AudioTrack.STATE_INITIALIZED) throw new IllegalStateException("AudioTrack unavailable");
            running = true;
            AudioTrack output = track; AudioMixer engine = mixer;
            new Thread(() -> write(output, engine), "Sling-native-audio").start();
            Log.i("SlingAudio", "native-audiotrack ready rate=" + rate + " samples=" + samples.size() + " bytes=" + bytes);
            return true;
        } catch (Exception error) { Log.e("SlingAudio", "Native stream failed", error); releaseInternal(); return false; }
    }

    private void write(AudioTrack output, AudioMixer engine) {
        android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO);
        float[] block = new float[256 * 2];
        try {
            while (running && track == output) {
                synchronized (this) {
                    while (running && track == output && !outputActive) wait();
                    if (!running || track != output) break;
                    if (output.getPlayState() != AudioTrack.PLAYSTATE_PLAYING) output.play();
                }
                engine.render(block);
                int offset = 0;
                while (offset < block.length && running && track == output && outputActive) {
                    int count = output.write(block, offset, block.length - offset, AudioTrack.WRITE_BLOCKING);
                    if (count <= 0) {
                        if (!running || track != output || !outputActive) break;
                        throw new IllegalStateException("AudioTrack write=" + count);
                    }
                    offset += count;
                }
            }
        } catch (Exception error) {
            if (running && track == output) Log.e("SlingAudio", "Native output stopped", error);
        } finally {
            synchronized (this) { if (track == output) { running = false; track = null; abandonFocus(); } }
            try { output.stop(); } catch (Exception ignored) {}
            output.release();
        }
    }

    @JavascriptInterface public synchronized boolean setState(int token, double volume, boolean silent, boolean gamePaused) {
        if (!valid(token) || !running || !Double.isFinite(volume) || volume < 0 || volume > 1) return false;
        gain = (float) volume; muted = silent || gain == 0; paused = gamePaused;
        if (muted) abandonFocus(); else if (foreground) acquireFocus();
        applyState(); return true;
    }
    private void acquireFocus() {
        if (!focusGranted) focusGranted = manager.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
    }
    private void abandonFocus() { manager.abandonAudioFocusRequest(focus); focusGranted = false; }
    private void applyState() {
        boolean active = !muted && foreground && focusGranted;
        if (mixer != null) mixer.state(gain, !active, paused);
        if (!active && outputActive && track != null) {
            // Stop output immediately and discard queued audio on focus loss.
            // The writer sleeps rather than rendering silence in the background.
            try { track.pause(); track.flush(); } catch (Exception ignored) {}
        }
        outputActive = active;
        notifyAll();
    }

    @JavascriptInterface public synchronized int play(int token, String encoded) {
        if (!valid(token) || !running) return -1;
        if (encoded == null || encoded.length() > 8192) return -1;
        try {
            return enqueueEffects(new JSONObject(encoded));
        } catch (Exception ignored) { return -1; }
    }

    private int enqueueEffects(JSONObject request) throws JSONException {
        JSONArray voices = request.getJSONArray("voices");
        if (voices.length() > 16) return -1;
        boolean ui = request.optBoolean("ui"), priority = request.optBoolean("priority");
        List<AudioMixer.Voice> batch = new ArrayList<>();
        for (int i = 0; i < voices.length(); i++) {
            JSONObject voice = voices.getJSONObject(i);
            float[] pcm = samples.get(voice.getInt("id"));
            double delay = voice.getDouble("delay"), pan = voice.getDouble("pan");
            if (pcm == null || !Double.isFinite(delay) || delay < 0 || delay > 2
                || !Double.isFinite(pan) || Math.abs(pan) > .65) return -1;
            batch.add(new AudioMixer.Voice(pcm, (int) Math.round(delay * rate), (float) pan, voice.optBoolean("wet"), ui, priority));
        }
        return mixer.enqueue(batch);
    }

    /** One bounded bridge crossing for a frame's ordered, independent requests. */
    @JavascriptInterface public synchronized String playBatch(int token, String encoded) {
        if (!valid(token) || !running || encoded == null || encoded.length() > 131072) return "[]";
        try {
            JSONArray requests = new JSONArray(encoded), results = new JSONArray();
            if (requests.length() > 96) return "[]";
            for (int i = 0; i < requests.length(); i++) {
                try {
                    JSONObject request = requests.getJSONObject(i);
                    int result = request.optBoolean("music") ? playMusic(token, request.getInt("id"),
                        request.getDouble("delay"), request.getDouble("pan"), request.getDouble("volume"),
                        request.getString("bus"), request.optBoolean("wet")) : enqueueEffects(request);
                    results.put(result);
                } catch (JSONException error) { results.put(-1); }
            }
            return results.toString();
        } catch (JSONException error) { return "[]"; }
    }

    @JavascriptInterface public synchronized boolean uploadMusic(int token, int id, String encoded) {
        if (!valid(token) || !running || id < 0 || encoded == null || encoded.length() > 12 * 1024 * 1024) return false;
        try {
            byte[] data = Base64.decode(encoded, Base64.NO_WRAP);
            if (data.length == 0 || data.length % 4 != 0 || data.length > 8 * 1024 * 1024) return false;
            float[] pcm = new float[data.length / 4];
            ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer().get(pcm);
            for (float value : pcm) if (!Float.isFinite(value) || Math.abs(value) > 4) return false;
            float[] old = musicSamples.remove(id); if (old != null) musicBytes -= old.length * 4;
            while (musicBytes + data.length > 64 * 1024 * 1024 || musicSamples.size() >= 128) {
                Integer key = musicSamples.keySet().iterator().next(); musicBytes -= musicSamples.remove(key).length * 4;
            }
            musicSamples.put(id, pcm); musicBytes += data.length; return true;
        } catch (Exception error) { return false; }
    }
    @JavascriptInterface public synchronized int playMusic(int token, int id, double delay, double pan, double volume, String bus, boolean wet) {
        if (!valid(token) || !running) return -1;
        float[] pcm = musicSamples.get(id);
        if (pcm == null) return -2; // Cache evicted: JS can upload this note again.
        if (!Double.isFinite(delay) || delay < 0 || delay > 3 || !Double.isFinite(pan) || Math.abs(pan) > 1
            || !Double.isFinite(volume) || volume < 0 || volume > 1
            || !Arrays.asList("pad", "bass", "drums", "arp", "lead", "bell", "fx").contains(bus)) return -1;
        AudioMixer.Voice voice = new AudioMixer.Voice(pcm, (int) Math.round(delay * rate), (float) pan, wet, AudioMixer.Bus.MUSIC, false);
        voice.instrument = AudioMixer.instrument(bus); voice.volume = (float) volume;
        return mixer.enqueue(Collections.singletonList(voice));
    }
    @JavascriptInterface public synchronized boolean musicFade(int token, double target, double seconds) {
        if (!valid(token) || !running || !Double.isFinite(target) || target < 0 || target > 1
            || !Double.isFinite(seconds) || seconds < 0 || seconds > 10) return false;
        mixer.musicFade((float) target, (int) (seconds * rate)); return true;
    }
    @JavascriptInterface public synchronized boolean musicState(int token, String encoded, double cutoff, boolean stop) {
        if (!valid(token) || !running || encoded == null || encoded.length() > 1024
            || !Double.isFinite(cutoff) || cutoff < 30 || cutoff > 22050) return false;
        try {
            JSONObject values = new JSONObject(encoded); Map<String, Float> levels = new HashMap<>();
            for (String bus : new String[] {"pad", "bass", "drums", "arp", "lead", "bell", "fx"}) {
                double value = values.optDouble(bus, 0);
                if (!Double.isFinite(value) || value < 0 || value > 2) return false;
                levels.put(bus, (float) value);
            }
            mixer.musicState(levels, (float) cutoff, stop); return true;
        } catch (Exception error) { return false; }
    }

    @JavascriptInterface public synchronized String snapshot(int token) {
        if (!valid(token)) return "{}";
        try {
            JSONObject info = new JSONObject().put("backend", "native-audiotrack").put("running", running)
                .put("sampleRate", rate).put("samples", samples.size()).put("sampleBytes", bytes)
                .put("musicSamples", musicSamples.size()).put("musicBytes", musicBytes)
                .put("musicGain", mixer.musicGain()).put("musicCutoff", mixer.musicCutoff())
                .put("gain", gain).put("muted", muted || !foreground || !focusGranted).put("paused", paused)
                .put("focus", focusGranted).put("voices", mixer.active()).put("accepted", mixer.accepted)
                .put("dropped", mixer.dropped).put("renderedFrames", mixer.rendered);
            info.put("buses", new JSONObject().put("effects", mixer.active(AudioMixer.Bus.EFFECTS))
                .put("ui", mixer.active(AudioMixer.Bus.UI)).put("music", mixer.active(AudioMixer.Bus.MUSIC)));
            if (track != null) info.put("underruns", track.getUnderrunCount()).put("bufferFrames", track.getBufferSizeInFrames());
            return info.toString();
        } catch (Exception ignored) { return "{}"; }
    }
    @JavascriptInterface public synchronized void release(int token) { if (valid(token)) releaseInternal(); }
    private void releaseInternal() {
        running = false;
        outputActive = false;
        notifyAll();
        AudioTrack old = track; track = null;
        if (old != null) try { old.stop(); old.flush(); } catch (Exception ignored) {}
        if (mixer != null) mixer.clear();
        samples.clear(); bytes = 0; session = 0; muted = true;
        musicSamples.clear(); musicBytes = 0;
        abandonFocus();
    }
    @Override public synchronized void close() { closed = true; documentActive = false; releaseInternal(); }
}
