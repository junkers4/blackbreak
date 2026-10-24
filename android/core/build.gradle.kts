plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    testImplementation(libs.junit.jupiter)
    testImplementation(libs.serialization.json)
    testRuntimeOnly(libs.junit.platform.launcher)
}

tasks.test {
    useJUnitPlatform()
    systemProperty("blackbreak.spec", rootProject.projectDir.resolve("../spec").canonicalPath)
    testLogging { events("failed") }
}
