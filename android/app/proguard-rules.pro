# Firebase / Google Play services use reflection for some SDK internals.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Sign-In / Credential Manager
-keep class com.google.android.gms.auth.api.signin.** { *; }

# flutter_local_notifications uses reflection to find receivers/services.
-keep class com.dexterous.** { *; }

# geolocator plugin
-keep class com.baseflow.geolocator.** { *; }

# Keep annotation-based metadata used by several plugins.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Avoid stripping classes referenced only via Firestore's dynamic Map-based
# reads/writes in this codebase (defensive; app uses fromMap()/toMap(), not
# @IgnoreExtraProperties POJOs, but this guards against future additions).
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
