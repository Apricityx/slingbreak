package io.github.apricityx.slingbreak;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;

/** Decoder for Gecko LSValue's raw Snappy blocks and UTF8/UTF16-LE values.
 * Format reference: Mozilla dom/localstorage/LSValue.{h,cpp}, Snappy format.
 * Independent implementation; no Gecko runtime or native Snappy dependency. */
public final class GeckoValue {
    private static final int LIMIT = 2 * 1024 * 1024;
    private GeckoValue() {}

    public static String decode(byte[] input, int utf16Length, int conversion, int compression) throws IOException {
        if (input == null || input.length > LIMIT || utf16Length < 0 || utf16Length > LIMIT / 2)
            throw new IOException("Gecko value exceeds migration limit");
        if (compression != 0 && compression != 1 || conversion != 0 && conversion != 1)
            throw new IOException("Unknown Gecko value encoding");
        byte[] bytes = compression == 1 ? unsnappy(input) : input;
        if (conversion == 0 && bytes.length % 2 != 0) throw new IOException("Invalid UTF16 byte length");
        try {
            String value = (conversion == 1 ? StandardCharsets.UTF_8 : StandardCharsets.UTF_16LE)
                .newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes)).toString();
            if (value.length() != utf16Length) throw new IOException("Gecko value length mismatch");
            return value;
        } catch (java.nio.charset.CharacterCodingException error) { throw new IOException("Invalid Gecko text", error); }
    }

    static byte[] unsnappy(byte[] input) throws IOException {
        int pos = 0, shift = 0;
        long size = 0;
        while (true) {
            if (pos >= input.length || shift > 28) throw new IOException("Invalid Snappy size");
            int b = input[pos++] & 255;
            size |= (long) (b & 127) << shift;
            if ((b & 128) == 0) break;
            shift += 7;
        }
        if (size > LIMIT) throw new IOException("Snappy output too large");
        byte[] out = new byte[(int) size];
        int written = 0;
        while (pos < input.length) {
            int tag = input[pos++] & 255, type = tag & 3;
            if (type == 0) {
                long length = tag >>> 2;
                if (length >= 60) {
                    int count = (int) length - 59;
                    if (pos + count > input.length) throw new IOException("Truncated Snappy literal");
                    length = 0;
                    for (int i = 0; i < count; i++) length |= (long) (input[pos++] & 255) << (8 * i);
                }
                length++;
                if (length > out.length - written || length > input.length - pos)
                    throw new IOException("Snappy literal outside block");
                System.arraycopy(input, pos, out, written, (int) length);
                pos += (int) length; written += (int) length;
            } else {
                int length, count;
                long offset;
                if (type == 1) {
                    length = 4 + ((tag >>> 2) & 7); count = 1; offset = (tag & 224) << 3;
                } else {
                    length = 1 + (tag >>> 2); count = type == 2 ? 2 : 4; offset = 0;
                }
                if (pos + count > input.length) throw new IOException("Truncated Snappy copy");
                for (int i = 0; i < count; i++) offset |= (long) (input[pos++] & 255) << (8 * i);
                if (offset <= 0 || offset > written || length > out.length - written)
                    throw new IOException("Snappy copy outside block");
                for (int i = 0; i < length; i++) { out[written] = out[written - (int) offset]; written++; }
            }
        }
        if (written != out.length) throw new IOException("Snappy block length mismatch");
        return out;
    }
}
