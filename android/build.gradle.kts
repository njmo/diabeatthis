allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// These plugins rely on built-in Kotlin on AGP 9, while other dependencies still use KGP.
val builtInKotlinPlugins = setOf("file_picker", "firebase_ai", "firebase_app_check")
subprojects {
    if (name in builtInKotlinPlugins) {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("com.android.built-in-kotlin")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
