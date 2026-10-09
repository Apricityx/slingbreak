package io.github.apricityx.slingbreak.update;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.os.Build;
import java.io.File;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.zip.ZipFile;

public final class ApkVerifier {
    private ApkVerifier() {}

    public static void verify(Context context, File apk, Release release) throws Exception {
        if (!apk.isFile() || apk.length() != release.size) throw new IOException("APK 大小不匹配");
        com.android.apksig.ApkVerifier.Result signature = new com.android.apksig.ApkVerifier.Builder(apk)
            .setMinCheckedPlatformVersion(Build.VERSION.SDK_INT).build().verify();
        if (!signature.isVerified()) throw new IOException("APK 数字签名无效或文件已损坏");
        PackageManager pm = context.getPackageManager();
        PackageInfo installed = pm.getPackageInfo(context.getPackageName(), PackageManager.GET_SIGNING_CERTIFICATES);
        PackageInfo incoming = pm.getPackageArchiveInfo(apk.getAbsolutePath(), 0);
        if (incoming == null || !context.getPackageName().equals(incoming.packageName)) throw new IOException("APK 包名不匹配");
        if (incoming.getLongVersionCode() <= installed.getLongVersionCode()) throw new IOException("拒绝相同版本或降级 APK");
        Integer version = Versions.compare(incoming.versionName, release.tag);
        if (version == null || version != 0) throw new IOException("APK 版本与 Release 标签不匹配");
        if (!Versions.newer(installed.versionName, incoming.versionName)) throw new IOException("拒绝版本回退");
        if (incoming.applicationInfo == null || incoming.applicationInfo.minSdkVersion > Build.VERSION.SDK_INT)
            throw new IOException("此版本不支持当前 Android 系统");
        Set<String> expected = new HashSet<>(), actual = new HashSet<>();
        for (Signature cert : installed.signingInfo.getApkContentsSigners()) expected.add(hex(MessageDigest.getInstance("SHA-256").digest(cert.toByteArray())));
        for (X509Certificate cert : signature.getSignerCertificates()) actual.add(hex(MessageDigest.getInstance("SHA-256").digest(cert.getEncoded())));
        if (expected.isEmpty() || !expected.equals(actual)) throw new IOException("APK 签名与已安装客户端不同，拒绝安装");
        try (ZipFile zip = new ZipFile(apk)) {
            if (!RuntimeArchive.supports(zip, Build.SUPPORTED_ABIS)) throw new IOException("APK 的 X5 架构不支持本设备");
        }
    }

    public static String hex(byte[] bytes) {
        StringBuilder text = new StringBuilder();
        for (byte b : bytes) text.append(String.format(java.util.Locale.ROOT, "%02x", b & 255));
        return text.toString();
    }
}
