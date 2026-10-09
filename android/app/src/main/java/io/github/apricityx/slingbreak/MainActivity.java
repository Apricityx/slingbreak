package io.github.apricityx.slingbreak;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.Toast;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.tencent.smtt.sdk.*;
import com.tencent.smtt.export.external.interfaces.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Offline X5 only. Native commands use fixed navigations; the bridge is audio-only. */
public final class MainActivity extends Activity {
    static final String GAME = LocalGame.GAME;
    private static final int OPEN_PROGRESS = 10, SAVE_PROGRESS = 11;
    private WebView view;
    private FrameLayout root;
    private UpdateController updates;
    private final ExecutorService files = Executors.newSingleThreadExecutor();
    private ValueCallback<Uri[]> fileResult;
    private byte[] exportedProgress;
    private boolean destroyed, resumed, failed, exportPending;
    private AlertDialog engineDialog;
    private volatile String migrationScript = "";
    private NativeAudio audio;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        WindowManager.LayoutParams layout = getWindow().getAttributes();
        layout.layoutInDisplayCutoutMode = android.os.Build.VERSION.SDK_INT >= 30
            ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        getWindow().setAttributes(layout);
        root = new FrameLayout(this);
        setContentView(root);
        immersive();
        if (android.os.Build.VERSION.SDK_INT >= 33)
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, this::confirmExit);
        awaitEngine();
    }

    private void awaitEngine() {
        if (destroyed || isFinishing()) return;
        SlingApplication app = (SlingApplication) getApplication();
        if (app.state == SlingApplication.State.READY) {
            if (engineDialog != null) { engineDialog.dismiss(); engineDialog = null; }
            loadGame();
        } else if (app.state == SlingApplication.State.FAILED) {
            if (engineDialog != null) engineDialog.dismiss();
            loadFailure(app.detail);
        } else if (app.state == SlingApplication.State.RESTART_REQUIRED) {
            if (engineDialog != null) engineDialog.dismiss();
            engineDialog = new AlertDialog.Builder(this).setTitle("X5 已就绪").setMessage(app.detail)
                .setCancelable(false).setPositiveButton("重新打开", (d, w) -> {
                    Intent next = new Intent(this, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                    android.app.PendingIntent restart = android.app.PendingIntent.getActivity(this, 0, next,
                        android.app.PendingIntent.FLAG_CANCEL_CURRENT | android.app.PendingIntent.FLAG_IMMUTABLE);
                    try { restart.send(); } catch (android.app.PendingIntent.CanceledException ignored) {}
                    finish();
                    android.os.Process.killProcess(android.os.Process.myPid());
                }).show();
        } else {
            if (engineDialog == null) engineDialog = new AlertDialog.Builder(this).setTitle("准备内置 X5")
                .setMessage(app.detail).setCancelable(false).show();
            else engineDialog.setMessage(app.detail);
            root.postDelayed(this::awaitEngine, 300);
        }
    }

    private void loadGame() {
        if (view != null || destroyed) return;
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
        view = new WebView(this);
        if (view.getX5WebViewExtension() == null) {
            view.destroy(); view = null;
            loadFailure("X5 创建失败。为保护存档，不会回退到系统 WebView。");
            return;
        }
        android.util.Log.i("SlingX5", "actualX5=true UA=" + view.getSettings().getUserAgentString());
        root.addView(view, new FrameLayout.LayoutParams(-1, -1));
        WebSettings settings = view.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(true); // SAF import URI; no filesystem access.
        settings.setAllowFileAccessFromFileURLs(false);
        settings.setAllowUniversalAccessFromFileURLs(false);
        settings.setMixedContentMode(android.webkit.WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        audio = new NativeAudio(this);
        audio.foreground(resumed && hasWindowFocus());
        view.addJavascriptInterface(audio, "SlingNativeAudio");
        delegates();
        updates = new UpdateController(this);
        updates.autoCheck();
        // Read Gecko's dormant profile off the UI thread. Injection into the
        // entry HTML happens before any theme/game script can create a save.
        files.execute(() -> {
            migrationScript = GeckoMigration.prepare(this);
            runOnUiThread(() -> { if (!destroyed) { audio.document(true); view.loadUrl(GAME + "?client=1"); } });
        });
    }

    private void delegates() {
        view.setWebViewClient(new WebViewClient() {
            @Override public void onPageStarted(WebView web, String url, android.graphics.Bitmap icon) {
                if (audio != null) { audio.document(false); audio.document(localDocument(url)); }
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView web, WebResourceRequest request) {
                return resource(request.getUrl().toString(), request.getMethod());
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView web, String url) { return resource(url, "GET"); }
            @Override public boolean shouldOverrideUrlLoading(WebView web, WebResourceRequest request) {
                String url = request.getUrl().toString();
                if (LocalGame.commandAllowed(url, web.getUrl(), request.isForMainFrame(), request.hasGesture(), request.isRedirect())) {
                    if (url.equals("slingbreak://check-update")) updates.requestCheck();
                    else if (url.equals("slingbreak://client-options")) updates.menu();
                    else exportProgress();
                }
                return !localDocument(url);
            }
            // Legacy callback has no reliable gesture/frame metadata: no native commands.
            @Override public boolean shouldOverrideUrlLoading(WebView web, String url) { return !localDocument(url); }
            @Override public void onPageFinished(WebView web, String url) {
                android.util.Log.i("SlingX5", "Page finished: " + url);
                if (BuildConfig.DEBUG) web.evaluateJavascript("JSON.stringify({game:!!window.Game,phase:window.Game&&Game.phase,storage:!!window.localStorage})",
                    result -> android.util.Log.i("SlingX5", "page=" + result));
            }
            @Override public void onReceivedError(WebView web, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) loadFailure("内置游戏加载失败；存档未清除。");
            }
            @Override public void onReceivedSslError(WebView web, SslErrorHandler handler, SslError error) { handler.cancel(); }
            @Override public boolean onRenderProcessGone(WebView web, RenderProcessGoneDetail detail) {
                loadFailure("X5 渲染进程已停止；请重新打开客户端，存档未清除。");
                return true;
            }
        });
        view.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onConsoleMessage(ConsoleMessage message) {
                if (BuildConfig.DEBUG) android.util.Log.i("SlingX5JS", message.messageLevel() + " " + message.message());
                return true;
            }
            @Override public boolean onShowFileChooser(WebView web, ValueCallback<Uri[]> reply, FileChooserParams params) {
                if (!localDocument(web.getUrl()) || fileResult != null || params.getMode() != FileChooserParams.MODE_OPEN) {
                    reply.onReceiveValue(null); return true;
                }
                fileResult = reply;
                try { startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("application/json").putExtra(Intent.EXTRA_MIME_TYPES,
                        new String[] {"application/json", "text/plain", "application/octet-stream"}), OPEN_PROGRESS); }
                catch (android.content.ActivityNotFoundException error) { dismissFilePrompt(); toast("系统没有文件选择器"); }
                return true;
            }
            @Override public void onPermissionRequest(PermissionRequest request) { request.deny(); }
        });
        view.setDownloadListener((url, ua, contentDisposition, mime, length) -> toast("只允许通过设置导出 JSON 进度；其他网页下载已禁用。"));
    }

    private WebResourceResponse resource(String url, String method) {
        String path = LocalGame.asset(url);
        InputStream input = new ByteArrayInputStream(new byte[0]);
        int code = 403;
        String mime = "text/plain";
        if (path != null && "GET".equals(method)) {
            try {
                input = getAssets().open(path); code = 200; mime = mime(path);
                if ("game/index.html".equals(path) && !migrationScript.isEmpty()) {
                    try (InputStream source = input; ByteArrayOutputStream bytes = new ByteArrayOutputStream()) {
                        byte[] buffer = new byte[8192]; int count;
                        while ((count = source.read(buffer)) != -1) bytes.write(buffer, 0, count);
                        String html = new String(bytes.toByteArray(), StandardCharsets.UTF_8);
                        if (!html.contains("<head>")) throw new IOException("Missing entry head");
                        html = html.replace("<head>", "<head><script>" + migrationScript + "</script>");
                        input = new ByteArrayInputStream(html.getBytes(StandardCharsets.UTF_8));
                    }
                }
            }
            catch (IOException ignored) { code = 404; }
        }
        HashMap<String, String> headers = new HashMap<>();
        headers.put("Cache-Control", "no-store");
        headers.put("X-Content-Type-Options", "nosniff");
        headers.put("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self'; frame-src 'none'; object-src 'none'; worker-src 'none'; base-uri 'self'; form-action 'none'");
        return new WebResourceResponse(mime, "UTF-8", code, code == 200 ? "OK" : code == 404 ? "Not Found" : "Forbidden", headers, input);
    }

    private static String mime(String path) {
        if (path.endsWith(".html")) return "text/html";
        if (path.endsWith(".js")) return "application/javascript";
        if (path.endsWith(".css")) return "text/css";
        if (path.endsWith(".json")) return "application/json";
        if (path.endsWith(".svg")) return "image/svg+xml";
        if (path.endsWith(".png")) return "image/png";
        return "application/octet-stream";
    }

    static boolean localDocument(String value) { return LocalGame.document(value); }

    private void exportProgress() {
        if (exportPending || exportedProgress != null || destroyed || !localDocument(view.getUrl())) return;
        exportPending = true;
        view.evaluateJavascript("(function(){if(!window.Game)return null;if(Game.phase!=='clearing')Game.save();return JSON.stringify(Game.exportProgress());})()", result -> {
            exportPending = false;
            if (destroyed) return;
            try {
                Object decoded = new org.json.JSONTokener(result).nextValue();
                if (!(decoded instanceof String)) throw new IOException("无法读取游戏进度");
                byte[] bytes = ((String) decoded).getBytes(StandardCharsets.UTF_8);
                if (bytes.length > 2 * 1024 * 1024) throw new IOException("存档文件过大");
                new org.json.JSONObject((String) decoded);
                exportedProgress = bytes;
                startActivityForResult(new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("application/json").putExtra(Intent.EXTRA_TITLE, "slingbreak-progress.json"), SAVE_PROGRESS);
            } catch (Exception error) { exportedProgress = null; toast("导出失败：" + error.getMessage()); }
        });
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request == OPEN_PROGRESS && fileResult != null) {
            ValueCallback<Uri[]> reply = fileResult; fileResult = null;
            reply.onReceiveValue(result == RESULT_OK && data != null && data.getData() != null ? new Uri[] {data.getData()} : null);
        } else if (request == SAVE_PROGRESS) {
            byte[] bytes = exportedProgress; exportedProgress = null;
            if (result == RESULT_OK && data != null && data.getData() != null && bytes != null) {
                Uri uri = data.getData();
                files.execute(() -> {
                    try (OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
                        if (out == null) throw new IOException("无法写入文件");
                        out.write(bytes);
                        runOnUiThread(() -> { if (!destroyed) toast("存档已保存"); });
                    } catch (Exception error) { runOnUiThread(() -> { if (!destroyed) toast("保存失败：" + error.getMessage()); }); }
                });
            }
        }
    }

    private void loadFailure(String message) {
        if (destroyed || failed) return;
        failed = true;
        if (audio != null) audio.close();
        new AlertDialog.Builder(this).setTitle("X5 加载失败").setMessage(message)
            .setPositiveButton("退出", (dialog, which) -> finish()).setCancelable(false).show();
    }
    private void dismissFilePrompt() { if (fileResult != null) fileResult.onReceiveValue(null); fileResult = null; }
    private void toast(String message) { Toast.makeText(this, message, Toast.LENGTH_LONG).show(); }
    private void immersive() {
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        controller.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        controller.hide(WindowInsetsCompat.Type.systemBars());
    }
    private void confirmExit() {
        new AlertDialog.Builder(this).setTitle("退出弓引力？").setMessage("已保存的进度会保留。")
            .setPositiveButton("退出", (d, w) -> finish()).setNegativeButton("继续游戏", null).show();
    }
    @android.annotation.SuppressLint("GestureBackNavigation")
    @Override public void onBackPressed() { confirmExit(); }
    @Override protected void onResume() { super.onResume(); resumed = true; immersive(); if (view != null) view.onResume(); if (audio != null) audio.foreground(hasWindowFocus()); if (updates != null) updates.resume(); }
    @Override protected void onPause() { resumed = false; if (audio != null) audio.foreground(false); if (view != null) view.onPause(); super.onPause(); }
    @Override public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if (focused) immersive();
        if (audio != null) audio.foreground(resumed && focused);
        if (view != null) { if (resumed && focused) view.onResume(); else view.onPause(); }
    }
    @Override protected void onDestroy() {
        destroyed = true;
        if (audio != null) audio.close();
        if (engineDialog != null) engineDialog.dismiss();
        if (updates != null) updates.destroy();
        dismissFilePrompt(); files.shutdownNow();
        if (view != null) { root.removeView(view); view.destroy(); }
        super.onDestroy();
    }
}
