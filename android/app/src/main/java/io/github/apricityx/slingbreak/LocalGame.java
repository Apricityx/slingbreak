package io.github.apricityx.slingbreak;

import java.net.URI;

/** Shared, unit-testable origin and navigation policy. Never serve remote HTML. */
public final class LocalGame {
    public static final String ORIGIN = "https://appassets.androidplatform.net";
    public static final String GAME = ORIGIN + "/assets/game/index.html";
    private LocalGame() {}

    public static String asset(String value) {
        try {
            URI uri = new URI(value);
            if (!"https".equals(uri.getScheme()) || !"appassets.androidplatform.net".equals(uri.getHost())
                    || uri.getPort() != -1 || uri.getUserInfo() != null) return null;
            String path = uri.getPath();
            if (path == null || !path.startsWith("/assets/game/") || path.contains("\\") || path.contains("\u0000")) return null;
            for (String segment : path.split("/")) if ("..".equals(segment) || ".".equals(segment)) return null;
            return path.substring("/assets/".length());
        } catch (Exception ignored) { return null; }
    }

    public static boolean document(String value) { return "game/index.html".equals(asset(value)); }

    public static boolean commandAllowed(String target, String source, boolean mainFrame, boolean gesture, boolean redirect) {
        return mainFrame && gesture && !redirect && document(source)
            && ("slingbreak://check-update".equals(target) || "slingbreak://client-options".equals(target)
                || "slingbreak://export-progress".equals(target));
    }
}
