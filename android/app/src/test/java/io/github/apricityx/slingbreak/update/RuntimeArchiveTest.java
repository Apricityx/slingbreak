package io.github.apricityx.slingbreak.update;

import org.junit.Test;
import static org.junit.Assert.*;
import java.io.*;
import java.util.zip.*;

public class RuntimeArchiveTest {
    private byte[] zip(String name, byte[] data) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(out)) { zip.putNextEntry(new ZipEntry(name)); zip.write(data); zip.closeEntry(); }
        return out.toByteArray();
    }
    private boolean supports(String nativeName, String[] abis) throws Exception {
        File file = File.createTempFile("x5-runtime", ".apk");
        try {
            try (ZipOutputStream out = new ZipOutputStream(new FileOutputStream(file))) {
                out.putNextEntry(new ZipEntry("assets/x5/tbs_core_release.tbs.apk"));
                out.write(zip(nativeName, new byte[] {1})); out.closeEntry();
                out.putNextEntry(new ZipEntry("lib/arm64-v8a/liblinuxtoolsfortbssdk_jni.so")); out.write(1); out.closeEntry();
            }
            try (ZipFile archive = new ZipFile(file)) { return RuntimeArchive.supports(archive, abis); }
        } finally { file.delete(); }
    }
    @Test public void nestedCoreMustMatchDeviceAbi() throws Exception {
        assertTrue(supports("lib/arm64-v8a/libmttwebview.so", new String[] {"arm64-v8a", "armeabi-v7a"}));
        assertFalse(supports("lib/arm64-v8a/libmttwebview.so", new String[] {"x86_64"}));
        assertFalse(supports("lib/armeabi-v7a/libmttwebview.so", new String[] {"arm64-v8a"}));
    }
}
