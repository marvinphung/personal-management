# WorkManager opens its generated Room database implementation by reflection.
# R8 must retain its no-argument constructor in release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}

-keepnames class * extends androidx.work.ListenableWorker
