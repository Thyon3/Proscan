import com.android.build.gradle.LibraryExtension
import org.gradle.api.JavaVersion
import org.gradle.api.file.Directory
import org.gradle.kotlin.dsl.configure
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Firebase plugins - compatible with AGP 8.9.1 and Kotlin 2.1.0
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
    }
}

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
            
            // Force compileSdk 36 for all library modules (required for Java 9+ support)
            // This ensures plugins can compile with modern Android SDK
            compileSdk = 36
            
            // Force Java 17 for library modules
            compileOptions {
                sourceCompatibility = org.gradle.api.JavaVersion.VERSION_17
                targetCompatibility = org.gradle.api.JavaVersion.VERSION_17
            }
        }
    }
    
    // Force Kotlin jvmTarget 17 for all Kotlin tasks in all subprojects
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }

    // Force Java 17 for all Java compilation tasks (some plugins default to 11)
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
