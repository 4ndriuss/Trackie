# ==============================================================================
# SEC-08: ProGuard & R8 Obfuscation / Shrinking Rules for Trackie App
# ==============================================================================

# 1. Flutter Engine & Plugins Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepattributes *Annotation*
-dontwarn io.flutter.embedding.**

# 2. Desugaring & Java 17 Support
-dontwarn java.lang.invoke.**
-dontwarn java.lang.ClassValue

# 3. Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# 4. Flutter Secure Storage (Android Keystore)
-keep class androidx.security.crypto.** { *; }

# 5. Geolocation & Permissions
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# 6. Preserve Line Numbers & Attributes for Stack Traces
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
