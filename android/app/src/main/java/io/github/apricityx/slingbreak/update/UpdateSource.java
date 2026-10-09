package io.github.apricityx.slingbreak.update;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;

/** Mirrors are opt-in; no Watt DNS/TLS bypass or arbitrary proxy URLs. */
public enum UpdateSource {
    GITHUB("GitHub", "", true),
    VIP("ghproxy.vip", "https://ghproxy.vip/", true),
    LLKK("gh.llkk.cc", "https://gh.llkk.cc/", true),
    PROXY("gh-proxy.com", "https://gh-proxy.com/", false);

    public final String label;
    private final String prefix;
    public final boolean metadata;

    UpdateSource(String label, String prefix, boolean metadata) {
        this.label = label;
        this.prefix = prefix;
        this.metadata = metadata;
    }

    public String url(String officialUrl) {
        if (!allowedOfficialUrl(officialUrl)) throw new IllegalArgumentException("非 GitHub HTTPS 地址");
        return prefix + officialUrl;
    }

    public static List<UpdateSource> candidates(boolean mirrors, boolean forMetadata) {
        List<UpdateSource> sources = new ArrayList<>();
        for (UpdateSource source : values()) {
            if ((source == GITHUB || mirrors) && (!forMetadata || source.metadata)) sources.add(source);
        }
        return sources;
    }

    public static boolean allowedOfficialUrl(String value) {
        try {
            URI uri = URI.create(value);
            String host = uri.getHost();
            return "https".equals(uri.getScheme()) && uri.getUserInfo() == null && uri.getPort() == -1 && host != null &&
                (host.equals("github.com") || host.equals("api.github.com") || host.endsWith(".githubusercontent.com"));
        } catch (IllegalArgumentException error) { return false; }
    }

    public static boolean allowedTransportUrl(String value) {
        if (allowedOfficialUrl(value)) return true;
        for (UpdateSource source : values()) {
            if (!source.prefix.isEmpty() && value.startsWith(source.prefix) &&
                allowedOfficialUrl(value.substring(source.prefix.length()))) return true;
        }
        return false;
    }
}
