import java.util.Properties
plugins { id("com.android.application") }
val signing = Properties().apply { val f = rootProject.file("keystore.properties"); if (f.isFile) f.inputStream().use { load(it) } }
val signingReady = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all { !signing.getProperty(it).isNullOrBlank() } && rootProject.file(signing.getProperty("storeFile", "missing")).isFile
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } && !signingReady) throw GradleException("Configure keystore.properties for release signing. See docs/RELEASING.md.")
android {
 namespace = "wifi.login.auto"
 compileSdk = 36
 buildToolsVersion = "36.0.0"
 defaultConfig {
  applicationId = "wifi.login.auto"
  minSdk = 23
  targetSdk = 23 // Deliberate legacy broadcast behavior; see README compatibility.
  versionCode = 2
  versionName = "1.1.0"
 }
 signingConfigs { if (signingReady) create("release") {
  storeFile = rootProject.file(signing.getProperty("storeFile"))
  storePassword = signing.getProperty("storePassword")
  keyAlias = signing.getProperty("keyAlias")
  keyPassword = signing.getProperty("keyPassword")
 } }
 buildTypes {
  debug { applicationIdSuffix = ".debug"; versionNameSuffix = "-debug" }
  release { isMinifyEnabled = false; signingConfig = signingConfigs.findByName("release") }
 }
 compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
 lint { abortOnError = true; disable += "ExpiredTargetSdkVersion" }
}
