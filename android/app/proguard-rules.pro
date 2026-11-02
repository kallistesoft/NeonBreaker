# WorkManager (pulled in by the Google Mobile Ads SDK) opens its Room database by reflection on
# WorkDatabase_Impl; without these, R8 strips it and the release app crashes at startup.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
