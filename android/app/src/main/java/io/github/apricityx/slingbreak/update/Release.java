package io.github.apricityx.slingbreak.update;

import java.net.URI;
import org.json.JSONArray;
import org.json.JSONObject;

public final class Release {
    public static final String REPOSITORY = "Apricityx/slingbreak";
    public static final String PAGE = "https://github.com/" + REPOSITORY + "/releases";
    public static final long MAX_APK_BYTES = 300L * 1024 * 1024;
    public final String tag, notes, name, url, sha256;
    public final long size;

    public Release(String tag, String notes, String name, String url, String sha256, long size) {
        this.tag = tag;
        this.notes = notes;
        this.name = name;
        this.url = url;
        this.sha256 = sha256;
        this.size = size;
    }

    public static Release parse(JSONObject root, String[] abis) {
        String tag = root.optString("tag_name").trim();
        if (root.optBoolean("draft") || root.optBoolean("prerelease") || !Versions.stable(tag)) return null;
        JSONArray assets = root.optJSONArray("assets");
        if (assets == null) return null;
        JSONObject chosen = null;
        int best = Integer.MAX_VALUE;
        for (int i = 0; i < assets.length(); i++) {
            JSONObject asset = assets.optJSONObject(i);
            if (asset == null || !"uploaded".equals(asset.optString("state", "uploaded"))) continue;
            String name = asset.optString("name").toLowerCase(java.util.Locale.ROOT);
            if (!name.startsWith("slingbreak-") || !name.endsWith(".apk") || name.contains("debug") || name.contains("unsigned")) continue;
            long size = asset.optLong("size");
            if (size <= 0 || size > MAX_APK_BYTES || !validAssetUrl(asset.optString("browser_download_url"), tag)) continue;
            int score = name.contains("-universal.apk") ? abis.length : Integer.MAX_VALUE;
            for (int a = 0; a < abis.length; a++) if (name.endsWith("-" + abis[a] + ".apk")) { score = a; break; }
            if (score < best) { best = score; chosen = asset; }
        }
        if (chosen == null) return null;
        String digest = chosen.optString("digest", "");
        if (digest.equals("null")) digest = "";
        if (!digest.isEmpty() && !digest.matches("sha256:[0-9a-fA-F]{64}")) throw new IllegalArgumentException("Release 校验和无效");
        String notes = root.optString("body", "").replace("\r\n", "\n").replace('\r', '\n').trim();
        if (notes.length() > 32000) notes = notes.substring(0, 32000) + "\n…";
        return new Release(tag, notes, chosen.optString("name"), chosen.optString("browser_download_url"),
            digest.isEmpty() ? "" : digest.substring(7).toLowerCase(java.util.Locale.ROOT), chosen.optLong("size"));
    }

    public static boolean validAssetUrl(String value, String tag) {
        if (!UpdateSource.allowedOfficialUrl(value)) return false;
        URI uri = URI.create(value);
        String prefix = "/" + REPOSITORY + "/releases/download/" + tag + "/";
        String path = uri.getPath();
        return "github.com".equals(uri.getHost()) && uri.getQuery() == null && uri.getFragment() == null &&
            path.startsWith(prefix) && !path.substring(prefix.length()).contains("/") && path.endsWith(".apk") &&
            !path.contains("/../") && !path.contains("/./");
    }
}
