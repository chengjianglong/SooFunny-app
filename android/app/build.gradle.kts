import org.gradle.api.file.FileSystemOperations
import java.util.Properties
import javax.inject.Inject

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.chengjianglong.soofunny"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.chengjianglong.soofunny"
        minSdk = 26
        targetSdk = 37
        versionCode = 4
        versionName = "0.4"

        // 64-bit phones and emulators only: the talking buddy's llama.cpp library is built for
        // these, and the other libraries' 32-bit copies would only make the app bigger.
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }

        // The talking buddy's llama.cpp library (src/main/cpp), for phones and emulators.
        externalNativeBuild {
            cmake {
                abiFilters += listOf("arm64-v8a", "x86_64")
                arguments += listOf("-DANDROID_STL=c++_static")
            }
        }
    }

    ndkVersion = "28.2.13676358"
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildFeatures { compose = true }

    // The natural voices ship as a Play Asset Delivery pack, installed with the app.
    assetPacks += listOf(":voices")

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    androidResources {
        // Photos are already JPEG; storing them uncompressed lets them be read straight from the APK.
        noCompress += listOf("jpg")
        // Voice models are memory-mapped straight from the APK / asset pack.
        noCompress += listOf("onnx")
    }

    // Release signing with the Play upload key, if android/keystore.properties exists (it and the
    // key are made by tools/make_upload_key.sh and never committed). Without it the release
    // bundle is built unsigned.
    val keystoreFile = rootProject.file("keystore.properties")
    if (keystoreFile.exists()) {
        val keystore = Properties().apply { keystoreFile.inputStream().use(::load) }
        signingConfigs {
            create("upload") {
                storeFile = rootProject.file(keystore.getProperty("storeFile"))
                storePassword = keystore.getProperty("storePassword")
                keyAlias = keystore.getProperty("keyAlias")
                keyPassword = keystore.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystoreFile.exists()) signingConfig = signingConfigs.getByName("upload")
            isMinifyEnabled = true
            isShrinkResources = true
            // Symbols for the native library, so Play Console can read crash reports.
            ndk { debugSymbolLevel = "SYMBOL_TABLE" }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

/**
 * Copies the content the iOS app ships with (word list, word photos, gallery photos and their
 * credits) from ../SooFunny into the APK's assets, so both apps share one copy of it.
 */
abstract class CopyIosAssets : DefaultTask() {
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val iosDir: DirectoryProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @get:Inject
    abstract val fs: FileSystemOperations

    @TaskAction
    fun copy() {
        val ios = iosDir.get().asFile
        fs.sync {
            into(outputDir)
            from(ios.resolve("Words")) {
                include("kids_words.txt")
                into("words")
            }
            from(ios.resolve("Words/Photos")) {
                include("*.jpg", "*.json")
                into("words/photos")
            }
            from(ios.resolve("Showcase")) {
                include("*.jpg", "*.json")
                into("showcase")
            }
            // Natural voices: pronunciation dictionaries, Chinese G2P data and voice styles.
            from(ios.resolve("Voice/Resources")) {
                into("voice")
            }
        }
    }
}

// Fill the voices asset pack from ../Models before building.
tasks.named("preBuild") {
    dependsOn(":voices:copyModels")
}

val copyIosAssets = tasks.register<CopyIosAssets>("copyIosAssets") {
    iosDir.set(rootProject.layout.projectDirectory.dir("../SooFunny"))
    outputDir.set(layout.buildDirectory.dir("generated/iosAssets"))
}

androidComponents {
    onVariants { variant ->
        variant.sources.assets?.addGeneratedSourceDirectory(copyIosAssets, CopyIosAssets::outputDir)
    }
    // For testing without bundletool: `./gradlew installDebug -PwithModels=true` puts the voices
    // straight into the debug APK (about 250 MB more), where the app finds them as plain assets.
    if (providers.gradleProperty("withModels").orNull == "true") {
        onVariants(selector().withBuildType("debug")) { variant ->
            variant.sources.assets?.addStaticSourceDirectory(rootProject.file("voices/src/main/assets").path)
        }
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.activity.compose)
    // My books: on-device text recognition (bundled model, Chinese and Latin) and the system document scanner.
    implementation(libs.mlkit.text.chinese)
    implementation(libs.mlkit.document.scanner)
    // Color: finds the subject of a photo, so it gets more detail than the background.
    implementation(libs.mlkit.subject.segmentation)
    // Natural voices: Kokoro-82M run with ONNX Runtime.
    implementation(libs.onnxruntime.android)
    debugImplementation(libs.compose.ui.tooling)
    testImplementation(libs.junit)
}
