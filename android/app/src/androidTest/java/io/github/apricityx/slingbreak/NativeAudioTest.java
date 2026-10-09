package io.github.apricityx.slingbreak;

import android.content.Context;
import android.util.Base64;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import java.nio.*;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Exercises the bridge itself in the R8 release APK, without changing saves. */
@RunWith(AndroidJUnit4.class)
public class NativeAudioTest {
    @Test public void protocolValidationGainUiAndRelease() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        android.app.Instrumentation instrumentation = InstrumentationRegistry.getInstrumentation();
        android.app.Instrumentation.ActivityMonitor monitor = instrumentation.addMonitor(MainActivity.class.getName(), null, false);
        // The tested ROM blocks app-origin background launches even under
        // instrumentation. Shell launch keeps the real foreground/focus policy.
        try (android.os.ParcelFileDescriptor command = instrumentation.getUiAutomation().executeShellCommand(
                "am start -W -n " + context.getPackageName() + "/" + MainActivity.class.getName());
             java.io.InputStream input = new android.os.ParcelFileDescriptor.AutoCloseInputStream(command)) {
            byte[] buffer = new byte[1024];
            while (input.read(buffer) != -1) {}
        }
        android.app.Activity activity = monitor.waitForActivityWithTimeout(10000);
        instrumentation.removeMonitor(monitor);
        assertNotNull("Shell launch must create the foreground Activity", activity);
        long deadline = android.os.SystemClock.uptimeMillis() + 10000;
        while (!activity.hasWindowFocus() && android.os.SystemClock.uptimeMillis() < deadline) Thread.sleep(50);
        assertTrue("Foreground Activity must have window focus", activity.hasWindowFocus());
        try (NativeAudio audio = new NativeAudio(context)) {
            assertFalse(new JSONObject(audio.begin()).has("session"));
            audio.document(true); audio.foreground(true);
            JSONObject begin = new JSONObject(audio.begin());
            int session = begin.getInt("session");
            JSONObject capabilities = new JSONObject(audio.capabilities());
            assertEquals(2, capabilities.getInt("version"));
            assertTrue(capabilities.getBoolean("music"));
            assertTrue(capabilities.getBoolean("batch"));
            ByteBuffer data = ByteBuffer.allocate(480 * 4).order(ByteOrder.LITTLE_ENDIAN);
            for (int i = 0; i < 480; i++) data.putFloat((float) Math.sin(i * .1) * .05f);
            String sample = Base64.encodeToString(data.array(), Base64.NO_WRAP);
            assertFalse(audio.upload(session + 1, 0, sample));
            assertFalse(audio.upload(session, -1, sample));
            assertFalse(audio.upload(session, 0, "???"));
            assertTrue(audio.upload(session, 0, sample));
            assertFalse(audio.upload(session, 0, sample));
            assertTrue(audio.commit(session));
            assertFalse(audio.setState(session, Double.NaN, false, false));
            assertFalse(audio.setState(session, 2, false, false));
            assertTrue(audio.setState(session, .35, false, true));
            JSONObject info = new JSONObject(audio.snapshot(session));
            assertEquals(.35, info.getDouble("gain"), .000001);
            assertTrue(info.getBoolean("running"));
            assertEquals(-1, audio.play(session, "{\"voices\":[{\"id\":99,\"delay\":0,\"pan\":0}]}"));
            assertEquals(0, audio.play(session, "{\"voices\":[{\"id\":0,\"delay\":0,\"pan\":0}]}"));
            assertEquals(1, audio.play(session, "{\"ui\":true,\"voices\":[{\"id\":0,\"delay\":0,\"pan\":0}]}"));
            assertTrue(audio.uploadMusic(session, 7, sample));
            assertEquals("[]", audio.playBatch(session + 1, "[]"));
            assertEquals("[]", audio.playBatch(session, "not json"));
            assertEquals("[0,1,-2,-1]", audio.playBatch(session,
                "[{\"voices\":[{\"id\":0,\"delay\":0,\"pan\":0}]},"
                + "{\"ui\":true,\"voices\":[{\"id\":0,\"delay\":0,\"pan\":0}]},"
                + "{\"music\":true,\"id\":99,\"delay\":0,\"pan\":0,\"volume\":0.5,\"bus\":\"pad\"},{}]"));
            assertEquals(0, audio.playMusic(session, 7, 0, 0, .5, "pad", true));
            assertTrue(audio.setState(session, .35, false, false));
            assertEquals(1, audio.playMusic(session, 7, 0, 0, .5, "pad", true));
            assertTrue(audio.musicState(session, "{\"pad\":1}", 1200, false));
            assertTrue(audio.musicFade(session, .5, .1));
            assertEquals(1, new JSONObject(audio.snapshot(session)).getInt("musicSamples"));
            audio.foreground(false);
            assertTrue(new JSONObject(audio.snapshot(session)).getBoolean("muted"));
            audio.release(session);
            assertEquals(-1, audio.play(session, "{}"));
            assertEquals(0, new JSONObject(audio.snapshot(session)).length());
            audio.document(false); assertFalse(new JSONObject(audio.begin()).has("session"));
        }
    }
}
