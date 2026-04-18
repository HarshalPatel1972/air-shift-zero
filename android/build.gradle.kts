allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Force a stable version of AndroidX Core that is compatible with lStar
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
        }
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
    // This is the cleanest way to override SDKs in Gradle 8+
    // It runs during the configuration phase of each subproject
    project.plugins.withType<com.android.build.gradle.BasePlugin> {
        project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
            compileSdkVersion(36)
            buildToolsVersion("36.0.0")
            
            defaultConfig {
                targetSdk = 36
            }
        }
    }

    project.afterEvaluate {
        val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null) {
            if (android.namespace == null) {
                android.namespace = "com.airshift.generated.${project.name.replace("-", ".")}"
            }
            
            project.tasks.matching { it.name.contains("Manifest") }.configureEach {
                doFirst {
                    try {
                        val manifestFile = project.file("src/main/AndroidManifest.xml")
                        if (manifestFile.exists()) {
                            val content = manifestFile.readText()
                            if (content.contains("package=")) {
                                val newContent = content.replace(Regex("package=\"[^\"]*\""), "")
                                manifestFile.writeText(newContent)
                            }
                        }
                    } catch (e: Exception) {
                        println("Warning: Could not strip package from ${project.name}: ${e.message}")
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
