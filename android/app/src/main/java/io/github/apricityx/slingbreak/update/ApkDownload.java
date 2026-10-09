package io.github.apricityx.slingbreak.update;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.List;

public final class ApkDownload {
    public interface Progress { void update(long bytes, long total); }
    public interface Validator { void verify(File file, Release release) throws Exception; }
    interface ConnectionFactory { HttpURLConnection open(String url) throws IOException; }
    private final ConnectionFactory connections;
    private volatile boolean cancelled;
    private volatile HttpURLConnection connection;

    public ApkDownload(GithubHttp http) { this.connections = url -> http.open(url, "GET", false); }
    ApkDownload(ConnectionFactory connections) { this.connections = connections; }
    public void cancel() {
        cancelled = true;
        HttpURLConnection active = connection;
        if (active != null) active.disconnect();
    }

    public File download(File directory, UpdateService.Result result, boolean mirrors, Progress progress, Validator validator) throws Exception {
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("无法创建下载目录");
        Release release = result.release;
        File partial = new File(directory, "update.part"), ready = new File(directory, "update.apk");
        List<UpdateSource> sources = new ArrayList<>(UpdateSource.candidates(mirrors, false));
        sources.remove(result.downloadSource);
        sources.add(0, result.downloadSource);
        Exception failure = null;
        for (UpdateSource source : sources) {
            checkCancelled();
            boolean downloaded = false;
            try {
                connection = connections.open(source.url(release.url));
                long contentLength = connection.getContentLengthLong();
                if (contentLength > 0 && contentLength != release.size) throw new IOException("下载长度与 Release 不匹配");
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                long total = 0, reported = 0;
                try (InputStream input = connection.getInputStream(); FileOutputStream output = new FileOutputStream(partial)) {
                    byte[] buffer = new byte[65536];
                    int count;
                    while ((count = input.read(buffer)) != -1) {
                        checkCancelled();
                        total += count;
                        if (total > release.size || total > Release.MAX_APK_BYTES) throw new IOException("下载文件超过预期大小");
                        digest.update(buffer, 0, count);
                        output.write(buffer, 0, count);
                        long now = System.nanoTime();
                        if (now - reported > 200_000_000) { progress.update(total, release.size); reported = now; }
                    }
                    output.getFD().sync();
                }
                checkCancelled();
                if (total != release.size) throw new IOException("APK 下载不完整");
                String hash = ApkVerifier.hex(digest.digest());
                if (!release.sha256.isEmpty() && !release.sha256.equals(hash)) throw new IOException("APK SHA-256 校验失败");
                validator.verify(partial, release);
                checkCancelled();
                if (ready.exists() && !ready.delete()) throw new IOException("无法替换旧下载");
                if (!partial.renameTo(ready)) throw new IOException("无法保存已验证 APK");
                progress.update(total, release.size);
                downloaded = true;
                return ready;
            } catch (Exception error) {
                failure = error;
                checkCancelled();
            } finally {
                HttpURLConnection active = connection;
                connection = null;
                if (active != null) active.disconnect();
                if (!downloaded && partial.exists()) partial.delete();
            }
        }
        throw failure == null ? new IOException("下载失败") : failure;
    }

    private void checkCancelled() throws IOException {
        if (cancelled || Thread.currentThread().isInterrupted()) throw new IOException("已取消下载");
    }
}
