package io.github.apricityx.slingbreak;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.LinearLayout;
import androidx.core.content.FileProvider;
import io.github.apricityx.slingbreak.update.*;
import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

/** UI, consent and lifecycle only; release policy remains unit-testable Java. */
final class UpdateController {
    private final Activity activity;
    private final SharedPreferences preferences;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private UpdateService.Result available;
    private ApkDownload download;
    private Future<?> task;
    private AlertDialog progressDialog;
    private boolean busy, destroyed, awaitingPermission;
    private Release verifiedRelease;

    UpdateController(Activity activity) {
        this.activity = activity;
        preferences = activity.getSharedPreferences("updates", 0);
        String tag = preferences.getString("downloadTag", "");
        if (!tag.isEmpty() && new File(activity.getFilesDir(), "updates/update.apk").isFile()) {
            verifiedRelease = new Release(tag, "", "update.apk", "", "", preferences.getLong("downloadSize", 0));
        }
    }

    void autoCheck() {
        if (System.currentTimeMillis() - preferences.getLong("lastCheck", 0) >= 24L * 60 * 60 * 1000) check(false);
    }

    void requestCheck() {
        if (destroyed) return;
        if (busy) { message("检查更新", "正在检查或下载，请稍候再试。", null); return; }
        check(true);
    }

    private boolean mirrors() { return preferences.getBoolean("mirrors", false); }

    void menu() {
        if (destroyed) return;
        if (busy) { message("更新任务", "正在检查或下载，请稍候。", null); return; }
        String[] options = {verifiedRelease != null ? "安装已下载更新" : available != null ? "查看可用更新" : "检查 Release 更新",
            "备用下载源（当前" + (mirrors() ? "已启用" : "仅 GitHub") + "）", "打开 GitHub Releases", "关于 / 开源许可"};
        new AlertDialog.Builder(activity).setTitle("弓引力 " + BuildConfig.VERSION_NAME)
            .setItems(options, (dialog, item) -> {
                if (item == 0) {
                    if (verifiedRelease != null) install(); else if (available != null) offer(available); else check(true);
                } else if (item == 1) {
                    new AlertDialog.Builder(activity).setTitle("允许第三方备用源？")
                        .setMessage("GitHub 优先；不可达时依次使用 ghproxy.vip、gh.llkk.cc、gh-proxy.com。它们会收到请求信息。APK 仍必须通过数字签名校验，默认关闭。")
                        .setPositiveButton("启用", (d, w) -> preferences.edit().putBoolean("mirrors", true).apply())
                        .setNegativeButton("仅 GitHub", (d, w) -> preferences.edit().putBoolean("mirrors", false).apply()).show();
                } else if (item == 2) openPage();
                else new AlertDialog.Builder(activity).setTitle("离线 X5 客户端")
                    .setMessage("X5/TBS " + BuildConfig.X5_CORE_VERSION + "（仅 arm64）\n游戏资源内置，更新保留 X5 存档。首次启动会自动迁移可识别的 Gecko 存档，不覆盖已有 X5 进度。\n\n使用 API 36 兼容补丁；非腾讯官方 Android 16 构建。内核授权及依赖许可见包内 NOTICE 和 android/README.md。")
                    .setPositiveButton("确定", null).setNeutralButton("项目", (d, w) -> openPage()).show();
            }).setNegativeButton("返回游戏", null).show();
    }

    private void check(boolean manual) {
        if (busy) return;
        busy = true;
        if (manual) android.widget.Toast.makeText(activity, "正在检查更新…", android.widget.Toast.LENGTH_SHORT).show();
        boolean useMirrors = mirrors();
        task = worker.submit(() -> {
            try {
                UpdateService.Result result = new UpdateService(new GithubHttp()).check(BuildConfig.VERSION_NAME, Build.SUPPORTED_ABIS, useMirrors);
                activity.runOnUiThread(() -> {
                    if (destroyed) return;
                    busy = false;
                    available = result.newer ? result : null;
                    preferences.edit().putLong("lastCheck", System.currentTimeMillis()).apply();
                    if (result.newer && !manual) android.widget.Toast.makeText(activity,
                        "发现客户端更新，可在设置中查看。", android.widget.Toast.LENGTH_LONG).show();
                    if (result.newer && manual) offer(result);
                    else if (manual) message("检查更新", result.release == null ? "仓库尚未发布正式 Release。当前内置游戏可继续离线运行。" : "已是最新版本（" + BuildConfig.VERSION_NAME + "）。", null);
                });
            } catch (Exception error) {
                activity.runOnUiThread(() -> {
                    if (destroyed) return;
                    busy = false;
                    android.util.Log.w("SlingbreakUpdate", "Update check failed", error);
                    if (manual) message("检查失败", error.getMessage() + "\n游戏不受影响。可重试、查看 Release 或启用备用源。", null);
                });
            }
        });
    }

    private void offer(UpdateService.Result result) {
        String text = BuildConfig.VERSION_NAME + " → " + result.release.tag + "\n" + result.release.name +
            "\n" + String.format(java.util.Locale.ROOT, "%.1f MiB", result.release.size / 1048576.0) +
            "\n元数据：" + result.metadataSource.label + "；下载：" + result.downloadSource.label +
            "\n\n" + result.release.notes + "\n\n下载后校验签名，再由 Android 确认安装。不卸载、不清除存档。";
        new AlertDialog.Builder(activity).setTitle("发现新版本")
            .setMessage(text).setPositiveButton("下载更新", (dialog, which) -> download(result))
            .setNegativeButton("稍后", null).setNeutralButton("Release 页面", (dialog, which) -> openPage()).show();
    }

    private void download(UpdateService.Result result) {
        if (busy) return;
        busy = true;
        verifiedRelease = null;
        preferences.edit().remove("downloadTag").remove("downloadSize").apply();
        download = new ApkDownload(new GithubHttp());
        ApkDownload current = download;
        boolean useMirrors = mirrors();
        LinearLayout layout = new LinearLayout(activity);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(40, 20, 40, 20);
        TextView status = new TextView(activity);
        status.setText("准备下载…");
        ProgressBar bar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(100);
        layout.addView(status);
        layout.addView(bar);
        progressDialog = new AlertDialog.Builder(activity).setTitle("下载 " + result.release.tag).setView(layout)
            .setNegativeButton("取消", (d, w) -> current.cancel()).setCancelable(false).show();
        task = worker.submit(() -> {
            try {
                current.download(new File(activity.getFilesDir(), "updates"), result, useMirrors,
                    (bytes, total) -> activity.runOnUiThread(() -> {
                        if (destroyed) return;
                        int percent = (int) (bytes * 100 / total);
                        bar.setProgress(percent);
                        status.setText(percent == 100 ? "正在校验 APK…" : "已下载 " + percent + "%");
                    }), (file, release) -> ApkVerifier.verify(activity, file, release));
                activity.runOnUiThread(() -> {
                    if (destroyed) return;
                    finishDownload();
                    verifiedRelease = result.release;
                    preferences.edit().putString("downloadTag", result.release.tag).putLong("downloadSize", result.release.size).apply();
                    message("下载及验证完成", "点击安装将打开 Android 安装确认界面。", this::install);
                });
            } catch (Exception error) {
                activity.runOnUiThread(() -> {
                    if (destroyed) return;
                    finishDownload();
                    message("下载未完成", error.getMessage(), null);
                });
            }
        });
    }

    private void finishDownload() {
        busy = false;
        download = null;
        if (progressDialog != null) { progressDialog.dismiss(); progressDialog = null; }
    }

    private void install() {
        if (busy || verifiedRelease == null) return;
        if (!activity.getPackageManager().canRequestPackageInstalls()) {
            message("允许安装更新", "请在系统设置中允许此客户端安装应用；只会在你确认后安装已验证的 APK。", () -> {
                awaitingPermission = true;
                try { activity.startActivity(new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + activity.getPackageName()))); }
                catch (android.content.ActivityNotFoundException error) { awaitingPermission = false; message("无法打开设置", "请在系统设置中允许安装未知应用。", null); }
            });
            return;
        }
        busy = true;
        Release release = verifiedRelease;
        task = worker.submit(() -> {
            try {
                File apk = new File(activity.getFilesDir(), "updates/update.apk");
                ApkVerifier.verify(activity, apk, release);
                activity.runOnUiThread(() -> {
                    if (destroyed) return;
                    busy = false;
                    Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".updates", apk);
                    Intent intent = new Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    try { activity.startActivity(intent); }
                    catch (android.content.ActivityNotFoundException error) { message("无法安装", "系统未提供 APK 安装程序。", null); }
                });
            } catch (Exception error) {
                activity.runOnUiThread(() -> {
                    if (destroyed) return;
                    busy = false;
                    verifiedRelease = null;
                    preferences.edit().remove("downloadTag").remove("downloadSize").apply();
                    message("拒绝安装", error.getMessage(), null);
                });
            }
        });
    }

    void resume() {
        if (awaitingPermission) {
            awaitingPermission = false;
            if (activity.getPackageManager().canRequestPackageInstalls()) install();
        }
    }

    private void message(String title, String text, Runnable action) {
        AlertDialog.Builder builder = new AlertDialog.Builder(activity).setTitle(title).setMessage(text)
            .setPositiveButton(action == null ? "确定" : "继续", (dialog, which) -> { if (action != null) action.run(); });
        if (action != null) builder.setNegativeButton("稍后", null);
        builder.show();
    }

    private void openPage() {
        try { activity.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(Release.PAGE))); }
        catch (android.content.ActivityNotFoundException error) { message("GitHub Releases", Release.PAGE, null); }
    }

    void destroy() {
        destroyed = true;
        if (download != null) download.cancel();
        if (task != null) task.cancel(true);
        worker.shutdownNow();
        if (progressDialog != null) progressDialog.dismiss();
    }
}
