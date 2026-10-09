# AndroidX Test references these compile-time Error Prone annotations. They
# have no runtime behaviour; scope this suppression to the instrumentation APK.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.MustBeClosed
