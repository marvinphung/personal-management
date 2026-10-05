# WorkManager opens its generated Room database implementation by reflection.
# R8 must retain its no-argument constructor in release builds.
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}

# WorkManager creates the input merger declared in each WorkSpec by class name.
# Without this rule R8 removes its public constructor and every release worker
# fails before UploadWorker.doWork() is entered.
-keep class * extends androidx.work.InputMerger {
    public <init>();
}

# WorkManager also instantiates workers by their class name.
-keepnames class * extends androidx.work.ListenableWorker
-keep class app.quanlytao.collector.queue.UploadWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}
