// Importadas: dentro de un .kts, "java.util…" se confunde con la extensión "java" de Gradle.
import java.util.Base64
import java.util.Properties

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
        val texto = String(Base64.getDecoder().decode(entrada), Charsets.UTF_8)
        val igual = texto.indexOf('=')
        if (igual > 0) texto.substring(0, igual) to texto.substring(igual + 1) else null
    }
    ?.toMap()
    ?: emptyMap()

// Llave de firma DEL PROYECTO: una sola huella SHA-1 (la que se registra en
// Google Cloud para la clave de Maps), se arme el APK en la PC que sea.
// android/key.properties (NO va a git) dice dónde está el .jks y sus claves;
// quien arme el APK necesita una copia de los dos. Sin ese archivo se usa la
// llave de depuración de cada PC (el mapa solo carga si su SHA-1 está registrada).
val firma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}
val hayLlaveDelProyecto = firma.getProperty("storeFile")?.let { file(it).exists() } == true

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

    signingConfigs {
        if (hayLlaveDelProyecto) {
            create("proyecto") {
                storeFile = file(firma.getProperty("storeFile"))
                storePassword = firma.getProperty("storePassword")
                keyAlias = firma.getProperty("keyAlias")
                keyPassword = firma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Con la llave del proyecto se firman las dos versiones (la de prueba
        // con `flutter run` y la final): así basta UNA huella en Google.
        val llave = if (hayLlaveDelProyecto) signingConfigs.getByName("proyecto") else signingConfigs.getByName("debug")
        debug {
            signingConfig = llave
        }
        release {
            signingConfig = llave
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
