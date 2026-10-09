package io.github.apricityx.slingbreak.update;

import java.io.IOException;
import org.json.JSONObject;

public final class UpdateService {
    public static final String API = "https://api.github.com/repos/" + Release.REPOSITORY + "/releases/latest";
    public interface Transport {
        String text(String url) throws IOException;
        boolean reachable(String url);
    }
    public static final class Result {
        public final Release release;
        public final boolean newer;
        public final UpdateSource metadataSource, downloadSource;
        Result(Release release, boolean newer, UpdateSource metadataSource, UpdateSource downloadSource) {
            this.release = release;
            this.newer = newer;
            this.metadataSource = metadataSource;
            this.downloadSource = downloadSource;
        }
    }
    private final Transport http;
    public UpdateService(Transport http) { this.http = http; }

    public Result check(String current, String[] abis, boolean mirrors) throws IOException {
        if (Versions.compare(current, current) == null) throw new IOException("本地版本号无法比较");
        IOException last = null;
        for (UpdateSource source : UpdateSource.candidates(mirrors, true)) {
            Release release;
            try {
                release = Release.parse(new JSONObject(http.text(source.url(API))), abis);
                if (release == null) throw new IOException("最新 Release 没有适配本设备的正式 Slingbreak APK");
            } catch (GithubHttp.HttpError error) {
                if (source == UpdateSource.GITHUB && error.status == 404) return new Result(null, false, source, null);
                last = error;
                continue;
            } catch (IOException error) { last = error; continue; }
            catch (Exception error) { last = new IOException("Release 元数据无效", error); continue; }
            boolean newer = Versions.newer(current, release.tag);
            if (!newer) return new Result(release, false, source, null);
            for (UpdateSource download : UpdateSource.candidates(mirrors, false)) {
                if (http.reachable(download.url(release.url))) return new Result(release, true, source, download);
            }
            throw new IOException("发现 " + release.tag + "，但 APK 下载链接不可达。请重试或启用备用源。");
        }
        throw last == null ? new IOException("无法检查更新") : last;
    }
}
