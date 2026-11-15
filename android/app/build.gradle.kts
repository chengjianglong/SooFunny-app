import org.gradle.api.file.FileSystemOperations
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
        versionCode = 3
        versionName = "0.3"
    }

    buildFeatures { compose = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    androidResources {
        // Photos are already JPEG; storing them uncompressed lets them be read straight from the APK.
        noCompress += listOf("jpg")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
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
        }
    }
}

val copyIosAssets = tasks.register<CopyIosAssets>("copyIosAssets") {
    iosDir.set(rootProject.layout.projectDirectory.dir("../SooFunny"))
    outputDir.set(layout.buildDirectory.dir("generated/iosAssets"))
}

androidComponents {
    onVariants { variant ->
        variant.sources.assets?.addGeneratedSourceDirectory(copyIosAssets, CopyIosAssets::outputDir)
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
    debugImplementation(libs.compose.ui.tooling)
    testImplementation(libs.junit)
}
