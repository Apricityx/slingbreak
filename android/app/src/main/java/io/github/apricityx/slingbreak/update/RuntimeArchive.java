package io.github.apricityx.slingbreak.update;

import java.io.IOException;
import java.util.Arrays;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipEntry;

/** X5's native engine is in a nested asset APK, not Gecko's top-level libxul. */
public final class RuntimeArchive {
    private RuntimeArchive() {}
    public static boolean supports(ZipFile apk, String[] abis) throws IOException {
        if (!Arrays.asList(abis).contains("arm64-v8a")) return false;
        if (apk.getEntry("lib/arm64-v8a/liblinuxtoolsfortbssdk_jni.so") == null) return false;
        ZipEntry core = apk.getEntry("assets/x5/tbs_core_release.tbs.apk");
        if (core == null) return false;
        try (ZipInputStream nested = new ZipInputStream(apk.getInputStream(core))) {
            ZipEntry entry;
            while ((entry = nested.getNextEntry()) != null) {
                if ("lib/arm64-v8a/libmttwebview.so".equals(entry.getName()) && !entry.isDirectory()) return true;
            }
        }
        return false;
    }
}
