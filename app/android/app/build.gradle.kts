import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clave de firma de release. El archivo tiene contrasenas, asi que no se
// versiona (esta en android/.gitignore) y el keystore vive fuera del repo.
// Sin el, la build de release sigue andando pero firmada con la clave de
// depuracion: sirve para probar, no para publicar.
val propiedadesFirma = Properties()
val archivoFirma = rootProject.file("key.properties")
val hayFirmaPropia = archivoFirma.exists()
if (hayFirmaPropia) {
    archivoFirma.inputStream().use { propiedadesFirma.load(it) }
}

android {
    namespace = "com.joaqovrs.mi_spotify"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.joaqovrs.mi_spotify"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayFirmaPropia) {
            create("release") {
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
                storeFile = file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Si falta key.properties (otra maquina, o el CI) se cae a la clave
            // de depuracion en vez de romper la build. El APK sale instalable
            // igual; lo que no sale es publicable.
            signingConfig = if (hayFirmaPropia) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
