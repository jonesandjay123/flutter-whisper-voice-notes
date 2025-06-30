# Flutter's default rules.
-dontwarn io.flutter.embedding.android.**
-keep class io.flutter.embedding.android.FlutterActivity
-keep class io.flutter.embedding.android.FlutterFragment
-keep class io.flutter.embedding.android.FlutterView
-keep class io.flutter.plugins.**

# Keep rules for Wear OS Communication Services
# This prevents ProGuard from stripping out the service and its dependencies in release builds.

# Keep the main communication service.
-keep class com.jovicheer.whisper_voice_notes.service.PhoneWearCommunicationService { *; }

# Keep all subclasses of WearableListenerService, as a general rule.
-keep class * extends com.google.android.gms.wearable.WearableListenerService

# Keep the data models (request/response classes) used for serialization/deserialization with Gson.
# The `{*;} a`llows obfuscation of method names but keeps all members.
-keep class com.jovicheer.whisper_voice_notes.data.model.** { *; }

# Keep the fields of the data models to prevent them from being removed, which would break Gson serialization.
-keepclassmembers class com.jovicheer.whisper_voice_notes.data.model.** {
    <fields>;
}

# Keep any other managers or holders you created.
-keep class com.jovicheer.whisper_voice_notes.service.WearSyncManager { *; }
-keep class com.jovicheer.whisper_voice_notes.service.WearSyncManagerHolder { *; }

# For Gson library, if you use it for serialization.
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
} 