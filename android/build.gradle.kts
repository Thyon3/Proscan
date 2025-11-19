import com.android.build.gradle.LibraryExtension
import org.gradle.kotlin.dsl.configure

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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension> {
            if (namespace.isNullOrBlank()) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                val manifestNamespace = if (manifestFile.exists()) {
                    Regex("""package="([^"]+)"""")
                        .find(manifestFile.readText())
                        ?.groups?.get(1)
                        ?.value
                } else null

                namespace = manifestNamespace ?: "com.${project.name.replace('_', '.')}"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
