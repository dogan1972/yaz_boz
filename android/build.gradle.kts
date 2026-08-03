import org.gradle.api.JavaVersion

plugins {
    // 🔥 Firebase Google Services Plugin (Versiyonu güncelledik)
    id("com.google.gms.google-services") version "4.4.2" apply false
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
    
    // 🔥 TÜM ALT PROJELERİ (PAKETLER DAHİL) JAVA 17'YE ZORLA
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.extensions.findByType<com.android.build.gradle.BaseExtension>()?.let { android ->
                if (android.namespace == null) {
                    android.namespace = project.group.toString()
                }
                
                // Java derleyicisini 17'ye zorla
                android.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        
        // Kotlin derleyicisini 17'ye zorla
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}