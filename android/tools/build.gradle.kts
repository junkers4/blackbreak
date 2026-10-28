// Fetches the smali assembler and its dependencies into tools/lib, for build.sh.
val smali by configurations.creating

dependencies {
    smali("com.android.tools.smali:smali:3.0.10")
}

tasks.register<Copy>("fetchSmali") {
    from(smali)
    into(layout.projectDirectory.dir("lib"))
}
