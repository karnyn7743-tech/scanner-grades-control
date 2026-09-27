allprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
    configurations.all {
        resolutionStrategy {
            force("org.tensorflow:tensorflow-lite:2.14.0")
            force("org.tensorflow:tensorflow-lite-api:2.14.0")
            force("org.tensorflow:tensorflow-lite-gpu:2.14.0")
            force("org.tensorflow:tensorflow-lite-gpu-api:2.14.0")
        }
    }
}

subprojects {
    project.configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.tensorflow") {
                useVersion("2.14.0")
                because("توحيد إصدار tensorflow-lite لمنع تكرار مساحة الأسماء في الـ Manifest")
            }
        }
    }

    afterEvaluate {
        project.plugins.withId("kotlin-android") {
            configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                jvmToolchain(17)
            }
        }

        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.BaseExtension) {
                androidExt.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }

        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}
