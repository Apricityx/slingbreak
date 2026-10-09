package io.github.apricityx.slingbreak.update;

import android.content.Context;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;

/** Runs against the installed signed release without installing the fixture.
 * Push a future signed APK into the target's external-files directory first:
 * adb push ... /sdcard/Android/data/io.github.apricityx.slingbreak/files/update-fixture.apk
 * Pass -e fixtureVersion 1.1.0 to the instrumentation runner.
 * No production update URL override or hidden installer backdoor is added. */
@RunWith(AndroidJUnit4.class)
public class ApkVerificationTest {
    private Context context() { return InstrumentationRegistry.getInstrumentation().getTargetContext(); }
    private Release release(File file, String tag) { return new Release(tag, "", "fixture.apk", "", "", file.length()); }

    @Test public void sameInstalledApkIsNotAnUpdate() throws Exception {
        Context context = context();
        File apk = new File(context.getApplicationInfo().sourceDir);
        String current = context.getPackageManager().getPackageInfo(context.getPackageName(), 0).versionName;
        try { ApkVerifier.verify(context, apk, release(apk, current)); fail("Same APK must be rejected"); }
        catch (java.io.IOException expected) { assertTrue(expected.getMessage(), expected.getMessage().contains("降级")); }
    }

    @Test public void signedFutureApkAndTamperChecks() throws Exception {
        Context context = context();
        File fixture = new File(context.getExternalFilesDir(null), "update-fixture.apk");
        String tag = InstrumentationRegistry.getArguments().getString("fixtureVersion");
        assertTrue("Provide future signed APK fixture", fixture.isFile());
        assertNotNull("Provide fixtureVersion", tag);
        ApkVerifier.verify(context, fixture, release(fixture, tag));
        try { ApkVerifier.verify(context, fixture, release(fixture, "999.0.0")); fail("Release tag mismatch"); }
        catch (java.io.IOException expected) { assertTrue(expected.getMessage().contains("标签")); }
        File damaged = new File(context.getCacheDir(), "damaged-fixture.apk");
        try {
            try (FileInputStream input = new FileInputStream(fixture); FileOutputStream output = new FileOutputStream(damaged)) {
                byte[] bytes = new byte[65536];
                int count;
                while ((count = input.read(bytes)) != -1) output.write(bytes, 0, count);
                output.write(0); // v2/v3 signature covers the complete archive.
            }
            try { ApkVerifier.verify(context, damaged, release(damaged, tag)); fail("Tampered APK must be rejected"); }
            catch (Exception expected) { /* Invalid ZIP layout or signature are both fail-closed. */ }
        } finally { damaged.delete(); }
    }
}
