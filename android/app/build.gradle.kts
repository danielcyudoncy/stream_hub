plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.stream_hub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.stream_hub"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // flutter_vlc_player ships large libvlc .so files per ABI; keep
            // them uncompressed so Android can load them at runtime.
            useLegacyPackaging = true
            excludes += setOf("**/x86_64/**", "**/x86/**")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Native SurfaceView + ExoPlayer playback backend (ExoPlayerSurfaceView).
    // Renders video through a real SurfaceView composited by SurfaceFlinger in
    // hybrid-composition mode, bypassing the broken Flutter external-texture
    // sampler on Unisoc/Mali devices (see docs/PLAYBACK_ENGINEERING.md §1.1).
    val media3 = "1.10.1"
    implementation("androidx.media3:media3-exoplayer:$media3")
    implementation("androidx.media3:media3-exoplayer-hls:$media3")
    implementation("androidx.media3:media3-exoplayer-dash:$media3")
    implementation("androidx.media3:media3-exoplayer-rtsp:$media3")
    implementation("androidx.media3:media3-extractor:$media3")
    implementation("androidx.media3:media3-ui:$media3")

    // Phase 3 evaluation engine (IjkPlayerAdapter / IjkPlayerActivity): the
    // self-built ijkplayer AAR plus its per-ABI native libraries. Artifacts are
    // vendored by tools/ijkplayer/vendor.sh from the pinned source build
    // (docs/IJK_EVALUATION.md).
    //
    // IJK is OPTIONAL: when the vendored AAR is absent the engine is compiled
    // out — its Kotlin sources (src/ijk/kotlin) and manifest (src/ijk/manifest)
    // are not included, so the rest of the app still builds and runs. The
    // MainActivity registers the IJK channel via reflection, so it has no
    // static dependency on IJK when unavailable. Vendor the AAR to enable it.
    val ijkAar = file("libs/ijkplayer-java-release.aar")
    if (ijkAar.exists()) {
        implementation(files(ijkAar))
        android.sourceSets.getByName("main") {
            java { srcDir("src/ijk/kotlin") }
            // Note: manifest.srcFile replaces the entire main manifest, which deletes MainActivity!
            // IjkPlayerActivity is now declared directly in src/main/AndroidManifest.xml.
        }
    }
}

flutter {
    source = "../.."
}
