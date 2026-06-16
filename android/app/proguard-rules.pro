# 1. Flutter Core and Method Channels
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. Fix SharedPreferences and Pigeon-based plugins
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugins.shared_preferences.** { *; }
-keep class com.google.android.gms.common.annotation.KeepName
-keep @com.google.android.gms.common.annotation.KeepName class *
-keepclassmembernames class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# 3. Fix Camera Plugin and Lifecycle
-keep class io.flutter.plugins.camera.** { *; }
-keep class androidx.lifecycle.** { *; }
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod

# 4. FFmpegKit (antonkarpenko fork and original)
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.AbiDetect { *; }
-keep class com.antonkarpenko.ffmpegkit.FFmpegKitConfig { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**
-dontwarn com.arthenica.ffmpegkit.**

# 5. Native Methods and App Code
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.kssoft.dashcam.** { *; }

# 6. Play Store / Google Play specific warnings
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager
