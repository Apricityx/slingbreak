# TBS calls SDK internals and external interfaces reflectively from its DEX.
-keep class com.tencent.smtt.** { *; }
-dontwarn com.tencent.smtt.**
-keepclassmembers class io.github.apricityx.slingbreak.NativeAudio {
    @android.webkit.JavascriptInterface <methods>;
}
# AndroidX Test shares this target dependency; keep its runtime entry points
# so release instrumentation can start after target R8 optimization.
-keep class androidx.tracing.** { *; }
# AndroidX Test's Kotlin code is in the test APK, but its shared stdlib is
# supplied by the target. Preserve that ABI for release instrumentation.
-keep class kotlin.** { *; }
# These small protocol classes are also called by release instrumentation.
-keep class io.github.apricityx.slingbreak.NativeAudio { *; }
-keep class io.github.apricityx.slingbreak.GeckoMigration { *; }
