package io.github.apricityx.slingbreak.update;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public final class GithubHttp implements UpdateService.Transport {
    public static final class HttpError extends IOException {
        public final int status;
        HttpError(int status, String message) { super(message); this.status = status; }
    }

    public HttpURLConnection open(String url, String method, boolean range) throws IOException {
        for (int redirects = 0; redirects <= 6; redirects++) {
            if (!UpdateSource.allowedTransportUrl(url)) throw new IOException("拒绝非白名单 HTTPS 下载地址");
            if (Thread.currentThread().isInterrupted()) throw new IOException("已取消");
            HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
            connection.setConnectTimeout(8000);
            connection.setReadTimeout(12000);
            connection.setInstanceFollowRedirects(false);
            connection.setRequestMethod(method);
            connection.setRequestProperty("User-Agent", "Slingbreak-Android-Update");
            connection.setRequestProperty("Accept", "application/vnd.github+json");
            connection.setRequestProperty("X-GitHub-Api-Version", "2022-11-28");
            if (range) connection.setRequestProperty("Range", "bytes=0-0");
            int status;
            try { status = connection.getResponseCode(); }
            catch (IOException error) { connection.disconnect(); throw error; }
            if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) {
                String location = connection.getHeaderField("Location");
                connection.disconnect();
                if (location == null) throw new IOException("下载重定向缺少地址");
                try { url = URI.create(url).resolve(location).toString(); }
                catch (IllegalArgumentException error) { throw new IOException("下载重定向无效", error); }
                continue;
            }
            if (status < 200 || status >= 300) {
                connection.disconnect();
                throw new HttpError(status, status == 403 || status == 429
                    ? "GitHub 请求受限，请稍后重试（HTTP " + status + "）" : "请求失败（HTTP " + status + "）");
            }
            return connection;
        }
        throw new IOException("下载重定向过多");
    }

    @Override public String text(String url) throws IOException {
        HttpURLConnection connection = open(url, "GET", false);
        try (InputStream stream = connection.getInputStream(); ByteArrayOutputStream bytes = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = stream.read(buffer)) != -1) {
                if (bytes.size() + count > 2 * 1024 * 1024) throw new IOException("Release 元数据过大");
                bytes.write(buffer, 0, count);
            }
            return bytes.toString(StandardCharsets.UTF_8.name());
        } finally { connection.disconnect(); }
    }

    @Override public boolean reachable(String url) {
        for (boolean range : new boolean[] {false, true}) {
            HttpURLConnection connection = null;
            try {
                connection = open(url, range ? "GET" : "HEAD", range);
                return true;
            } catch (IOException error) {
                if (Thread.currentThread().isInterrupted()) return false;
            } finally { if (connection != null) connection.disconnect(); }
        }
        return false;
    }
}
