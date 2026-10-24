plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

val keystorePath: String? = System.getenv("ANDROID_KEYSTORE_FILE")

// The core is assembler (../core/aarch64): assembled and linked with the NDK's clang into
// libblackbreak.so, with no libc. 16 KB pages, as Android 15 and later require.
val coreDir = rootProject.file("../core/aarch64")
val nativeOut = layout.buildDirectory.dir("native/jniLibs")
val ndkClang: String by lazy {
    val sdk = rootProject.file("local.properties").takeIf { it.exists() }
        ?.readLines()?.firstOrNull { it.startsWith("sdk.dir=") }?.substringAfter("=")
        ?: System.getenv("ANDROID_HOME") ?: System.getenv("ANDROID_SDK_ROOT") ?: error("no Android SDK")
    val ndk = File(sdk, "ndk").listFiles()?.filter { it.isDirectory }?.maxByOrNull { it.name } ?: error("no NDK in $sdk/ndk")
    File(ndk, "toolchains/llvm/prebuilt/linux-x86_64/bin/clang").path
}
val assembleCore by tasks.registering(Exec::class) {
    val sources = listOf("core.S", "controller.S", "jni.S").map { File(coreDir, it) }
    val out = nativeOut.map { it.file("arm64-v8a/libblackbreak.so") }
    inputs.files(sources + File(coreDir, "core.inc"))
    outputs.file(out)
    doFirst { out.get().asFile.parentFile.mkdirs() }
    commandLine(listOf(ndkClang, "--target=aarch64-linux-android26", "-shared", "-nostdlib",
        "-Wl,-z,max-page-size=16384", "-Wl,-soname,libblackbreak.so", "-o", out.get().asFile.path) + sources.map { it.path })
}

android {
    namespace = "io.github.junkers4.blackbreak"
    compileSdk = 35

    defaultConfig {
        applicationId = "io.github.junkers4.blackbreak"
        minSdk = 26
        targetSdk = 35
        versionName = (findProperty("versionName") as String?) ?: "0.0.0"
        versionCode = ((findProperty("versionCode") as String?) ?: "1").toInt()
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters += "arm64-v8a" }
    }

    signingConfigs {
        if (keystorePath != null) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = "blackbreak"
                keyPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keystorePath != null) signingConfig = signingConfigs.getByName("release")
        }
    }

    sourceSets["main"].jniLibs.srcDir(nativeOut)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.all { it.useJUnitPlatform() }
    }
}

kotlin {
    jvmToolchain(17)
}

tasks.named("preBuild") { dependsOn(assembleCore) }

dependencies {
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.rules)
    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.androidx.uiautomator)
}
