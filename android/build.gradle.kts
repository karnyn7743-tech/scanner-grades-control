subprojects {
    afterEvaluate {
        project.plugins.withId("kotlin-android") {
            configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                jvmToolchain(17)
            }
        }
    }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}
