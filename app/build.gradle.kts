import java.util.Properties

plugins { id("com.android.application") }

val signing = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.isFile) f.inputStream().use { load(it) }
}

val signingReady =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
        !signing.getProperty(it).isNullOrBlank()
    } &&
    rootProject.file(signing.getProperty("storeFile", "missing")).isFile

if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } && !signingReady) {
    throw GradleException("Release signing is not configured. Run ./setup-keys.ps1 first.")
}

android {
    namespace = "wifi.login.auto"
    compileSdk = 36
    buildToolsVersion = "36.0.0"

    defaultConfig {
        applicationId = "wifi.login.auto"
        minSdk = 23
        targetSdk = 23 // Deliberate legacy broadcast behavior; see README compatibility.
        versionCode = 5
        versionName = "1.3.1"
    }

    signingConfigs {
        if (signingReady) {
            create("release") {
                storeFile = rootProject.file(signing.getProperty("storeFile"))
                storePassword = signing.getProperty("storePassword")
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
                storeType = signing.getProperty("storeType", "PKCS12")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }

        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        abortOnError = true
        disable += "ExpiredTargetSdkVersion"
    }
}
