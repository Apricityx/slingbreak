package io.github.apricityx.slingbreak;

import android.content.Context;
import android.content.ContextWrapper;
import android.database.sqlite.SQLiteDatabase;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Isolated fixture under cache; never rewrites an actual Gecko or X5 save. */
@RunWith(AndroidJUnit4.class)
public class GeckoMigrationReadTest {
    @Test public void readsCompressedSaveWithoutModifyingLegacyDatabase() throws Exception {
        Context target = InstrumentationRegistry.getInstrumentation().getTargetContext();
        File fixture = Files.createTempDirectory(target.getCacheDir().toPath(), "gecko-migration-").toFile();
        File base = new File(fixture, "mozilla"), profile = new File(base, "test.default");
        File source = new File(profile, "storage/default/resource+++android/ls/data.sqlite");
        assertTrue(source.getParentFile().mkdirs());
        Files.write(new File(base, "profiles.ini").toPath(), "[Profile0]\nIsRelative=1\nPath=test.default\nDefault=1\n".getBytes(StandardCharsets.UTF_8));
        String value = "{\"level\":4,\"coins\":4478,\"total\":148,\"best\":12,\"up\":{\"power\":1,\"arrow\":0,\"brick\":2}}";
        byte[] raw = value.getBytes(StandardCharsets.UTF_8);
        ByteArrayOutputStream block = new ByteArrayOutputStream();
        block.write(raw.length); block.write(240); block.write(raw.length - 1); block.write(raw);
        try (SQLiteDatabase db = SQLiteDatabase.openOrCreateDatabase(source, null)) {
            db.setVersion(80);
            db.execSQL("CREATE TABLE database(origin TEXT)"); db.execSQL("INSERT INTO database VALUES('resource://android')");
            db.execSQL("CREATE TABLE data(key TEXT,utf16_length INTEGER,conversion_type INTEGER,compression_type INTEGER,value BLOB)");
            db.execSQL("INSERT INTO data VALUES(?,?,?,?,?)", new Object[] {GeckoMigration.SAVE, value.length(), 1, 1, block.toByteArray()});
        }
        byte[] before = Files.readAllBytes(source.toPath());
        Context wrapped = new ContextWrapper(target) { @Override public File getFilesDir() { return fixture; } };
        String script = GeckoMigration.prepare(wrapped);
        assertTrue(script.contains("4478")); assertTrue(script.contains("localStorage.getItem(k)===null"));
        assertArrayEquals(before, Files.readAllBytes(source.toPath()));
    }
}
