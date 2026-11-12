plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Valores de --dart-define / --dart-define-from-file (ej. dart_defines.local.json).
// Flutter se los pasa a Gradle en la propiedad "dart-defines", cada uno en base64.
// De ahí sale la clave de Google Maps para Android: NUNCA se escribe en el
// código (el repo es público).
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { entrada ->
        val texto = String(java.util.Base64.getDecoder().decode(entrada), Charsets.UTF_8)
        val igual = texto.indexOf('=')
        if (igual > 0) texto.substring(0, igual) to texto.substring(igual + 1) else null
    }
    ?.toMap()
    ?: emptyMap()

android {
    namespace = "bo.mdrmarket.mdrmarket"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "bo.mdrmarket.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Va al AndroidManifest (com.google.android.geo.API_KEY). Vacía = sin mapa.
        manifestPlaceholders["mapsApiKey"] = dartDefines["GOOGLE_MAPS_KEY"] ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
