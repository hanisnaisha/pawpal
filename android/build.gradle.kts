allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Removed custom build directory to avoid OneDrive file locking issues
// Gradle will use default build directory in android/build/ which is better for OneDrive projects

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
