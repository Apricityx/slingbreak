package io.github.apricityx.slingbreak;

import org.junit.Test;
import java.util.*;
import static org.junit.Assert.*;

public class AudioMixerTest {
    private AudioMixer.Voice voice(int frames, int delay, float pan, boolean wet, boolean ui, boolean priority) {
        float[] pcm = new float[frames]; Arrays.fill(pcm, .5f);
        return new AudioMixer.Voice(pcm, delay, pan, wet, ui, priority);
    }
    @Test public void delayPanGainAndLimiter() {
        AudioMixer mixer = new AudioMixer(48000); mixer.state(.5f, false, false);
        assertEquals(1, mixer.enqueue(List.of(voice(8, 2, .65f, false, false, false))));
        float[] out = new float[8]; mixer.render(out);
        assertEquals(0, out[0], 0); assertEquals(0, out[3], 0);
        assertTrue(out[4] > 0); assertTrue(out[5] > out[4]); assertTrue(out[5] < .9);
        mixer.state(0, false, false); mixer.render(out);
        for (float value : out) assertEquals(0, value, 0);
    }
    @Test public void pauseClearsGameplayButKeepsUiAndMuteClearsBoth() {
        AudioMixer mixer = new AudioMixer(48000); mixer.state(1, false, false);
        mixer.enqueue(List.of(voice(100, 0, 0, true, false, false)));
        mixer.enqueue(List.of(voice(100, 0, 0, true, true, false)));
        mixer.state(1, false, true); assertEquals(1, mixer.active());
        assertEquals(0, mixer.enqueue(List.of(voice(10, 0, 0, false, false, false))));
        float[] out = new float[8]; mixer.render(out); assertTrue(out[0] > 0);
        mixer.state(1, true, true); assertEquals(0, mixer.active()); mixer.render(out);
        for (float value : out) assertEquals(0, value, 0);
    }
    @Test public void boundedVoicesAndPriorityPreemption() {
        AudioMixer mixer = new AudioMixer(48000); mixer.state(1, false, false);
        for (int i = 0; i < 64; i++) mixer.enqueue(List.of(voice(100, 0, 0, false, false, false)));
        assertEquals(0, mixer.enqueue(List.of(voice(100, 0, 0, false, false, false))));
        assertEquals(1, mixer.enqueue(List.of(voice(100, 0, 0, false, false, true))));
        assertEquals(64, mixer.active());
        float[] out = new float[200]; mixer.render(out); assertEquals(0, mixer.active());
        for (float value : out) assertTrue(Math.abs(value) <= .9f);
    }
    @Test public void echoTailSurvivesSampleAndClearsOnPause() {
        AudioMixer mixer = new AudioMixer(100); mixer.state(1, false, false);
        mixer.enqueue(List.of(voice(1, 0, 0, true, false, false)));
        float[] out = new float[24]; mixer.render(out);
        assertTrue(out[22] > 0);
        mixer.state(1, false, true); mixer.render(out);
        for (float value : out) assertEquals(0, value, 0);
    }

    @Test public void busesHaveIndependentLimitsAndPriorityDoesNotCrash() {
        AudioMixer mixer = new AudioMixer(48000); mixer.state(1, false, false);
        for (int i = 0; i < 64; i++) assertEquals(1, mixer.enqueue(List.of(voice(100, 0, 0, false, false, false))));
        for (int i = 0; i < 16; i++) assertEquals(1, mixer.enqueue(List.of(voice(100, 0, 0, false, true, false))));
        assertEquals(64, mixer.active(AudioMixer.Bus.EFFECTS));
        assertEquals(16, mixer.active(AudioMixer.Bus.UI));
        for (int i = 0; i < 48; i++) {
            float[] pcm = new float[100];
            assertEquals(1, mixer.enqueue(List.of(new AudioMixer.Voice(pcm, 0, 0, false, AudioMixer.Bus.MUSIC, false))));
        }
        assertEquals(0, mixer.enqueue(List.of(new AudioMixer.Voice(new float[100], 0, 0, false, AudioMixer.Bus.MUSIC, false))));
        assertEquals(48, mixer.active(AudioMixer.Bus.MUSIC));
        assertEquals(0, mixer.enqueue(List.of(voice(100, 0, 0, false, false, false))));
        assertEquals(1, mixer.enqueue(List.of(voice(100, 0, 0, false, false, true))));
        assertEquals(64, mixer.active(AudioMixer.Bus.EFFECTS));

        AudioMixer priorityMixer = new AudioMixer(48000); priorityMixer.state(1, false, false);
        for (int i = 0; i < 64; i++) assertEquals(1, priorityMixer.enqueue(List.of(voice(100, 0, 0, false, false, true))));
        assertEquals(0, priorityMixer.enqueue(List.of(voice(100, 0, 0, false, false, true))));
        assertEquals(64, priorityMixer.active(AudioMixer.Bus.EFFECTS));
    }

    @Test public void musicStateAndPauseClearOnlyMusicVoices() {
        AudioMixer mixer = new AudioMixer(48000); mixer.state(1, false, false);
        float[] pcm = new float[100]; Arrays.fill(pcm, .2f);
        AudioMixer.Voice music = new AudioMixer.Voice(pcm, 0, 0, false, AudioMixer.Bus.MUSIC, false);
        music.instrument = AudioMixer.instrument("pad");
        assertEquals(1, mixer.enqueue(List.of(music)));
        assertEquals(1, mixer.active(AudioMixer.Bus.MUSIC));
        mixer.musicState(Collections.singletonMap("pad", 1f), 1200, false);
        mixer.musicFade(0, 10);
        mixer.render(new float[32]);
        assertEquals(1, mixer.active(AudioMixer.Bus.MUSIC));
        mixer.state(1, false, true);
        assertEquals(0, mixer.active(AudioMixer.Bus.MUSIC));
        mixer.state(1, false, false);
        assertEquals(0, mixer.active(AudioMixer.Bus.MUSIC));
    }

    @Test public void musicFadeReachesSilenceAndPauseResetsFadeForResume() {
        AudioMixer mixer = new AudioMixer(1000); mixer.state(1, false, false);
        mixer.musicState(Collections.singletonMap("pad", 1f), 1200, false);
        float[] pcm = new float[10000]; Arrays.fill(pcm, .2f);
        AudioMixer.Voice music = new AudioMixer.Voice(pcm, 0, 0, true, AudioMixer.Bus.MUSIC, false);
        music.instrument = AudioMixer.instrument("pad");
        mixer.enqueue(List.of(music));
        float[] out = new float[8000]; mixer.render(out);
        assertTrue(out[out.length - 1] > .05f);
        mixer.musicFade(0, 1000); mixer.render(new float[2000]);
        assertEquals(0, mixer.musicGain(), .00001f);
        float[] silent = new float[512]; mixer.render(silent);
        for (float value : silent) assertEquals(0, value, .00001f);
        mixer.state(1, false, true); assertEquals(1, mixer.musicGain(), 0);
        mixer.state(1, false, false);
        assertEquals(1, mixer.enqueue(List.of(new AudioMixer.Voice(pcm, 0, 0, false, AudioMixer.Bus.MUSIC, false))));
        mixer.render(out); assertTrue(out[out.length - 1] > .05f);
    }

    @Test public void rejectedPriorityBatchDoesNotPartiallyEvictVoices() {
        AudioMixer mixer = new AudioMixer(48000); mixer.state(1, false, false);
        for (int i = 0; i < 63; i++) mixer.enqueue(List.of(voice(100, 0, 0, false, false, true)));
        mixer.enqueue(List.of(voice(100, 0, 0, false, false, false)));
        assertEquals(0, mixer.enqueue(List.of(voice(100, 0, 0, false, false, true), voice(100, 0, 0, false, false, true))));
        assertEquals(64, mixer.active());
        assertEquals(1, mixer.enqueue(List.of(voice(100, 0, 0, false, false, true))));
        assertEquals(64, mixer.active());
    }
}
