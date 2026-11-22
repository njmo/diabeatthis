plugins {
    id("com.android.application")
}


android {
    namespace = "pl.diabeatthis.wear"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "pl.diabeatthis.app"
        minSdk = 30
        targetSdk = 36
        testInstrumentationRunner = "pl.diabeatthis.wear.ActiveMealLayoutInstrumentation"
        versionCode = providers.gradleProperty("wearVersionCode").orNull?.toInt() ?: 1
        versionName = providers.gradleProperty("wearVersionName").orNull ?: "1.0.0"
    }

    val releaseSigning = signingConfigs.create("release") {
        val keystore = System.getenv("ANDROID_KEYSTORE_PATH")
        if (!keystore.isNullOrBlank()) {
            storeFile = file(keystore)
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        } else {
            initWith(signingConfigs.getByName("debug"))
        }
    }
    buildTypes.getByName("release").signingConfig = releaseSigning
}

dependencies {
    implementation("androidx.wear.tiles:tiles:1.5.0")
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
    implementation("com.google.android.gms:play-services-wearable:20.0.1")
}
