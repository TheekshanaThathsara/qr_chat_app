
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // Flutter Gradle plugin
    id("dev.flutter.flutter-gradle-plugin")

    // Google Services plugin (Firebase)
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.instant_chat_app"
    compileSdk = 36

    defaultConfig {
    applicationId = "com.example.instant_chat_app"

        // SDK versions
        minSdk = 24
        targetSdk = 34

        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // ✅ Shrink + minify only in release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // ✅ Don’t shrink in debug (faster build + avoids errors)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ✅ Ensure Java 17 for Flutter
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Firebase BoM - using stable version
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))

    // Firebase SDKs (add/remove based on usage)
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-database")
    implementation("com.google.firebase:firebase-storage")

    // AndroidX & Material
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.0")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
}

flutter {
    source = "../.."
}
