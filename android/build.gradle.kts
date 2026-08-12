import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

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
    val applyNamespaceFix: (Project) -> Unit = { p ->
        if (p.hasProperty("android")) {
            val android = p.extensions.getByName("android")
            try {
                val namespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                val getNamespaceMethod = android.javaClass.getMethod("getNamespace")
                if (getNamespaceMethod.invoke(android) == null) {
                    val defaultNamespace = "com.anvyaai.ago.${p.name.replace("-", "_")}"
                    namespaceMethod.invoke(android, defaultNamespace)
                }
            } catch (e: Exception) {
                // Ignore
            }

            // Fix for "Incorrect package found in source AndroidManifest.xml"
            // This is required for older plugins like background_sms
            try {
                p.tasks.matching { it.name.contains("process", ignoreCase = true) && it.name.contains("Manifest", ignoreCase = true) }.configureEach {
                    doFirst {
                        val manifestFile = file("src/main/AndroidManifest.xml")
                        if (manifestFile.exists()) {
                            val content = manifestFile.readText()
                            if (content.contains("package=")) {
                                val newContent = content.replace(Regex("""package="[^"]*""""), "")
                                manifestFile.writeText(newContent)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                // Ignore
            }

            // Force JVM Target to 17
            p.tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(JvmTarget.JVM_17)
                }
            }
            try {
                val androidExtension = p.extensions.getByName("android")
                if (androidExtension is com.android.build.gradle.BaseExtension) {
                    androidExtension.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                    androidExtension.compileOptions.targetCompatibility = JavaVersion.VERSION_17
                }
            } catch (e: Exception) {
                // Ignore if not an android project
            }
        }
    }

    if (project.state.executed) {
        applyNamespaceFix(project)
    } else {
        afterEvaluate {
            applyNamespaceFix(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
