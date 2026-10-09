package io.github.apricityx.slingbreak;

import android.content.Context;
import android.os.Build;
import android.util.Log;
import com.tencent.smtt.sdk.QbSdk;
import java.io.*;
import java.security.MessageDigest;
import java.util.Properties;

/** Pinned offline runtime. Never alter or trust an unknown installed core. */
final class X5Core {
    static final String CORE_HASH = "a58b1e6d700b01a8341793b4175a41c51b02ecc8e1d6d367f460ea692277d081";
    static final String ORIGINAL = "c7d4a2863ba3e91a75cc694d2215f1c686c7f8c43d7845d15b3018f8415137dd";
    static final String PATCHED = "448b783e96d74024c19290e0bc7ec7d7a24004ebf337a1aae03c08502c326105";

    static boolean prepare(Context context) throws Exception {
        File base = context.getDir("tbs_64", Context.MODE_PRIVATE);
        boolean prepared = false;
        // The SDK promotes a successful local installation on next preInit.
        // Protect and patch its staging directory before that can load DEX.
        for (String name : new String[] {"core_share", "core_unzip_tmp"})
            prepared = prepareDirectory(context, new File(base, name)) || prepared;
        return prepared;
    }

    private static boolean prepareDirectory(Context context, File core) throws Exception {
        File extension = new File(core, "tbs_sdk_extension_dex.jar");
        if (!extension.isFile()) return false;
        Properties conf = new Properties();
        try (InputStream in = new FileInputStream(new File(core, "tbs.conf"))) { conf.load(in); }
        if (Integer.parseInt(conf.getProperty("tbs_core_version", "0")) != BuildConfig.X5_CORE_VERSION)
            throw new IOException("未知 X5 内核版本，拒绝加载");
        String current = digest(extension);
        if (!ORIGINAL.equals(current) && !PATCHED.equals(current))
            throw new IOException("X5 扩展摘要不匹配，拒绝加载");
        if (Build.VERSION.SDK_INT == 36 && ORIGINAL.equals(current)) {
            File backup = new File(context.getFilesDir(), "x5-original-extension.jar");
            if (backup.exists() && !ORIGINAL.equals(digest(backup)))
                throw new IOException("X5 原始扩展备份损坏");
            if (!backup.exists()) {
                try (InputStream in = new FileInputStream(extension)) { copy(in, backup); }
            }
            File pending = new File(core, "sling-api36-extension.tmp");
            // This exact file is ours, never a vendor core or save. Recover an
            // interrupted write without discarding any other file.
            if (pending.exists() && !pending.delete()) throw new IOException("无法恢复 X5 补丁临时文件");
            try (InputStream in = context.getAssets().open("x5/api36-extension.jar")) { copy(in, pending); }
            if (!PATCHED.equals(digest(pending))) throw new IOException("X5 补丁摘要不匹配");
            if (!pending.renameTo(extension)) throw new IOException("无法应用 X5 补丁");
            Log.i("SlingX5", "Applied pinned API-36-only patch");
        }
        File[] files = core.listFiles();
        if (files != null) for (File file : files) {
            if (file.isFile() && file.getName().endsWith(".jar") && !file.setReadOnly())
                throw new IOException("无法保护动态 DEX：" + file.getName());
        }
        return true;
    }

    static void install(Context context) throws Exception {
        File archive = new File(context.getCacheDir(), "sling-x5-original.tbs.apk");
        if (archive.exists() && !archive.delete()) throw new IOException("无法准备内置 X5 包");
        try (InputStream in = context.getAssets().open("x5/tbs_core_release.tbs.apk")) { copy(in, archive); }
        if (!CORE_HASH.equals(digest(archive))) throw new IOException("内置 X5 包摘要不匹配");
        QbSdk.installLocalTbsCore(context, BuildConfig.X5_CORE_VERSION, archive.getAbsolutePath());
    }

    private static void copy(InputStream in, File target) throws IOException {
        try (FileOutputStream out = new FileOutputStream(target)) {
            if (!target.setReadOnly()) throw new IOException("无法设为只读：" + target.getName());
            byte[] buffer = new byte[65536];
            int count;
            while ((count = in.read(buffer)) != -1) out.write(buffer, 0, count);
            out.getFD().sync();
        }
    }

    static String digest(File file) throws Exception {
        MessageDigest hash = MessageDigest.getInstance("SHA-256");
        try (InputStream in = new FileInputStream(file)) {
            byte[] buffer = new byte[65536];
            int count;
            while ((count = in.read(buffer)) != -1) hash.update(buffer, 0, count);
        }
        return io.github.apricityx.slingbreak.update.ApkVerifier.hex(hash.digest());
    }
}
