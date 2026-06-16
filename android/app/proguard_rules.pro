# حماية مكتبات جوجل الذكية من الحذف والتصغير العشوائي
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
