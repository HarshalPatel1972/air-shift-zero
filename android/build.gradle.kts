allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Resolve 'lStar' Linking Error by forcing compatible androidx.core versions
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.6.0")
            force("androidx.core:core-ktx:1.6.0")
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
    project.evaluationDependsOn(":app")
    
    fun fixProject() {
        val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null) {
            // 1. Force Namespace if missing for AGP 8.0+
            if (android.namespace == null) {
                android.namespace = "com.airshift.generated.${project.name.replace("-", ".")}"
            }
            
            // 2. Strip 'package' attribute from Manifest (AGP 8+ requirement)
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

    if (project.state.executed) fixProject() else project.afterEvaluate { fixProject() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
