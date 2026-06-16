plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // تحديد رقم إصدار الأندرويد كـ رقم مجرد وليس نص
    compileSdk = 36

    namespace = "com.example.school_grading_app"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // الصيغة الصحيحة والمتوافقة لتحديد jvmTarget بدون أخطاء
        jvmTarget = "17"
    }

    defaultConfig {
        // معرف التطبيق الخاص بك
        applicationId = "com.example.school_grading_app"
        
        // الحد الأدنى لدعم الهواتف (رقم مجرد)
        minSdk = 21
        
        // الإصدار المستهدف (رقم مجرد ومتوافق مع الكاميرا)
        targetSdk = 36
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // إعدادات التوقيع الافتراضية للبناء التجريبي والمستقر
            signingConfig = signingConfigs.getByName("debug")
            
            // تفعيل التحسين لحل مشاكل المكتبات الخارجية مثل ML Kit
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
