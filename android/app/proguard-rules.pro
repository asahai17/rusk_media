# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WorkManager - keep Room database implementation class that R8 strips
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * implements androidx.work.WorkerFactory { *; }
-keep class * implements androidx.work.Configuration$Provider { *; }

# Room - keep generated _Impl classes
-keep class * extends androidx.room.RoomDatabase { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Play Core (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
