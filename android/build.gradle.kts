import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.BaseExtension
import com.android.build.gradle.LibraryPlugin
import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.jvm.toolchain.JavaLanguageVersion
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
        // Flutter engine/artifact downloads
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Ensure all Java compile tasks target Java 17 for consistent JVM compatibility
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Exclude old firebase-iid module globally to avoid duplicate class conflicts
    configurations.all {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }

    pluginManager.withPlugin("com.android.application") {
        extensions.configure<com.android.build.gradle.AppExtension>("android") {
            if (namespace.isNullOrBlank()) {
                namespace = "nexotech.nexapp"
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            if (namespace.isNullOrBlank()) {
                namespace = when (project.name) {
                    "on_audio_query_android" -> "com.lucasjosino.on_audio_query"
                    "google_mlkit_commons" -> "com.google.mlkit.commons"
                    "google_mlkit_object_detection" -> "com.google.mlkit.object_detection"
                    else -> "com.flutter.plugin.${project.name}"
                }
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }

        tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }

    pluginManager.withPlugin("org.jetbrains.kotlin.android") {
        tasks.withType<KotlinCompile>().configureEach {
            try {
                val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
                val javaTarget = androidExt?.compileOptions?.targetCompatibility?.toString()
                    ?: project.tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().firstOrNull()?.targetCompatibility?.toString()
                    ?: JavaVersion.VERSION_17.toString()
                val jvm = when {
                    javaTarget.contains("1.8") || javaTarget == "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                    javaTarget.contains("11") -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                    javaTarget.contains("17") || javaTarget == "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                    else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                }
                compilerOptions {
                    jvmTarget.set(jvm)
                }
            } catch (_: Throwable) {
            }
        }
    }

    // Try to set Kotlin JVM toolchain where Kotlin plugin is applied
    pluginManager.withPlugin("org.jetbrains.kotlin.jvm") {
        // This block will be executed in projects that apply the Kotlin JVM plugin.
        // Use the Kotlin DSL to request a JVM toolchain of Java 17.
        try {
            project.extensions.findByName("kotlin")?.let {
                // Request Kotlin JVM toolchain 17 for consistency with Java toolchain
                project.extra.set("kotlin.jvmToolchain", 17)
            }
        } catch (_: Throwable) {
        }
    }

    // Ensure Kotlin JVM target matches the project's Java target to avoid mismatches
    tasks.withType<KotlinCompile>().configureEach {
        try {
            val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            val javaTarget = androidExt?.compileOptions?.targetCompatibility?.toString()
                ?: project.tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().firstOrNull()?.targetCompatibility?.toString()
                ?: JavaVersion.VERSION_17.toString()
            val jvm = when {
                javaTarget.contains("1.8") || javaTarget == "8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                javaTarget.contains("11") -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                javaTarget.contains("17") || javaTarget == "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            }
            compilerOptions {
                jvmTarget.set(jvm)
            }
        } catch (_: Throwable) {
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


