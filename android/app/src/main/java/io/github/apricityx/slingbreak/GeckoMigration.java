package io.github.apricityx.slingbreak;

import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.util.Log;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import org.json.JSONObject;

/** One-way, insert-only migration. Old profile files are only opened read-only. */
final class GeckoMigration {
    static final String SAVE = "slingbreak-save-v1", THEME = "slingbreak-theme";

    static String prepare(Context context) {
        try {
            File base = new File(context.getFilesDir(), "mozilla");
            File profile = selectProfile(base);
            if (profile == null) return "";
            File source = new File(profile, "storage/default/resource+++android/ls/data.sqlite");
            if (!source.isFile()) return "";
            if (source.length() > 16 * 1024 * 1024) throw new IOException("Gecko database exceeds migration limit");
            JSONObject values = new JSONObject();
            try (SQLiteDatabase db = SQLiteDatabase.openDatabase(source.getPath(), null,
                    SQLiteDatabase.OPEN_READONLY | SQLiteDatabase.NO_LOCALIZED_COLLATORS)) {
                if (db.getVersion() != 80) throw new IOException("Unsupported Gecko localStorage schema");
                try (Cursor origin = db.rawQuery("SELECT origin FROM database", null)) {
                    if (!origin.moveToFirst() || !"resource://android".equals(origin.getString(0)) || origin.moveToNext())
                        throw new IOException("Unexpected Gecko origin");
                }
                try (Cursor rows = db.rawQuery("SELECT key,utf16_length,conversion_type,compression_type,value FROM data WHERE key IN (?,?)", new String[] {SAVE, THEME})) {
                    while (rows.moveToNext()) {
                        String key = rows.getString(0);
                        String value = GeckoValue.decode(rows.getBlob(4), rows.getInt(1), rows.getInt(2), rows.getInt(3));
                        if (SAVE.equals(key)) {
                            if (!validSave(value)) throw new IOException("Invalid legacy game save");
                        } else if (!Arrays.asList("system", "light", "dark").contains(value)) continue;
                        values.put(key, value);
                    }
                }
            }
            if (values.length() == 0) return "";
            Log.i("SlingMigration", "Validated legacy Gecko storage; insert-only migration prepared");
            return script(values);
        } catch (Exception error) {
            // Never reset progress, mark a failed attempt complete, or block
            // the game. Retain source so migration can be retried on next launch.
            Log.w("SlingMigration", "Legacy migration deferred: " + error.getClass().getSimpleName());
            return "";
        }
    }

    static File selectProfile(File base) throws IOException {
        File ini = new File(base, "profiles.ini");
        if (!ini.isFile() || ini.length() > 65536) return null;
        List<Map<String, String>> profiles = new ArrayList<>();
        Map<String, String> section = null;
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(new FileInputStream(ini), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.startsWith("[") && line.endsWith("]")) {
                    section = line.matches("\\[Profile\\d+\\]") ? new HashMap<>() : null;
                    if (section != null) profiles.add(section);
                } else if (section != null && line.contains("=")) {
                    int equal = line.indexOf('='); section.put(line.substring(0, equal).trim(), line.substring(equal + 1).trim());
                }
            }
        }
        List<Map<String, String>> defaults = new ArrayList<>();
        for (Map<String, String> profile : profiles) if ("1".equals(profile.get("Default"))) defaults.add(profile);
        Map<String, String> chosen = defaults.size() == 1 ? defaults.get(0) : defaults.isEmpty() && profiles.size() == 1 ? profiles.get(0) : null;
        if (chosen == null || !"1".equals(chosen.get("IsRelative")) || chosen.get("Path") == null) return null;
        File path = new File(base, chosen.get("Path")).getCanonicalFile();
        if (!path.getPath().startsWith(base.getCanonicalPath() + File.separator) || !path.isDirectory()) return null;
        return path;
    }

    static boolean validSave(String value) {
        try {
            JSONObject state = new JSONObject(value);
            for (String name : new String[] {"level", "coins", "total", "best"}) {
                Object field = state.get(name);
                if (!(field instanceof Number) || !Double.isFinite(((Number) field).doubleValue()) || ((Number) field).doubleValue() < 0) return false;
            }
            double level = state.getDouble("level");
            if (level < 1 || level != Math.floor(level)) return false;
            JSONObject up = state.getJSONObject("up");
            for (String name : new String[] {"power", "arrow", "brick", "comboCap", "slots"}) {
                if (!up.has(name) && (name.equals("comboCap") || name.equals("slots"))) continue;
                Object field = up.get(name);
                if (!(field instanceof Number)) return false;
                double n = ((Number) field).doubleValue();
                if (!Double.isFinite(n) || n < 0 || n != Math.floor(n)) return false;
            }
            return true;
        } catch (Exception ignored) { return false; }
    }

    static String script(JSONObject values) {
        // Escape HTML/script terminators and JS line separators in stored strings.
        String json = values.toString().replace("<", "\\u003c").replace("&", "\\u0026")
            .replace("\u2028", "\\u2028").replace("\u2029", "\\u2029");
        return "(function(){'use strict';var done='slingbreak-gecko-migration-v1',added=[];try{"
            + "if(localStorage.getItem(done))return;var values=" + json + ";"
            + "Object.keys(values).forEach(function(k){if(localStorage.getItem(k)===null){"
            + "added.push(k);localStorage.setItem(k,values[k]);if(localStorage.getItem(k)!==values[k])throw new Error('verify');}});"
            + "localStorage.setItem(done,'1');console.info('[SlingBreak] Gecko migration complete; existing X5 values preserved');"
            + "}catch(e){added.forEach(function(k){try{localStorage.removeItem(k);}catch(ignore){}});"
            + "console.warn('[SlingBreak] Gecko migration deferred');}})();";
    }
}
