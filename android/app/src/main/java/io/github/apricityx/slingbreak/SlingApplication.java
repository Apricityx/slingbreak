package io.github.apricityx.slingbreak;

import android.app.Application;
import android.util.Log;
import com.tencent.smtt.sdk.QbSdk;
import com.tencent.smtt.sdk.TbsListener;
import java.util.HashMap;

public final class SlingApplication extends Application {
    enum State { STARTING, INSTALLING, RESTART_REQUIRED, READY, FAILED }
    volatile State state = State.STARTING;
    volatile String detail = "正在准备内置 X5…";

    @Override public void onCreate() {
        super.onCreate();
        HashMap<String, Object> settings = new HashMap<>();
        settings.put(QbSdk.KEY_SET_SENDREQUEST_AND_UPLOAD, false);
        QbSdk.initTbsSettings(settings);
        QbSdk.disAllowThirdAppDownload();
        QbSdk.setDisableUseHostBackupCoreBySwitch(true);
        QbSdk.setCoreMinVersion(BuildConfig.X5_CORE_VERSION);
        QbSdk.setTbsListener(new TbsListener() {
            @Override public void onDownloadFinish(int code) { Log.i("SlingX5", "download=" + code); }
            @Override public void onDownloadProgress(int percent) {}
            @Override public void onInstallFinish(int code) {
                Log.i("SlingX5", "install=" + code);
                if (code == 200) {
                    detail = "内置 X5 已安装，重新打开即可运行游戏。";
                    state = State.RESTART_REQUIRED;
                } else fail("X5 安装失败（" + code + "）");
            }
        });
        new Thread(() -> {
            try {
                if (!X5Core.prepare(this)) {
                    state = State.INSTALLING;
                    detail = "首次启动：正在安装内置 X5，无需下载…";
                    X5Core.install(this);
                } else {
                    // Unlike initX5Environment, preInit does not query a remote
                    // provider for downloadable replacement cores.
                    QbSdk.preInit(this, new QbSdk.PreInitCallback() {
                        @Override public void onCoreInitFinished() {}
                        @Override public void onViewInitFinished(boolean x5) {
                            if (x5 && QbSdk.getTbsVersion(SlingApplication.this) == BuildConfig.X5_CORE_VERSION) {
                                detail = "X5 " + BuildConfig.X5_CORE_VERSION;
                                state = State.READY;
                                Log.i("SlingX5", "Pinned X5 ready; " + QbSdk.getX5CoreLoadHelp(SlingApplication.this));
                            } else fail("X5 无法启动，不会回退系统 WebView。\n" + QbSdk.getX5CoreLoadHelp(SlingApplication.this));
                        }
                    });
                }
            } catch (Exception error) { Log.e("SlingX5", "Initialization failed", error); fail(error.getMessage()); }
        }, "Sling-X5-prepare").start();
    }

    private void fail(String message) { detail = message; state = State.FAILED; }
}
