plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dogan_kanlipicak.yaz_boz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.dogan_kanlipicak.yaz_boz"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

        signingConfigs {
        create("release") {
            keyAlias = "upload"
            // 🎯 Terminalde belirlediğiniz şifreyi buraya yazın:
            keyPassword = "d167167k."
            storePassword = "d167167k."
            
            // 🚀 BÜYÜK ÇÖZÜM: Bilgisayar isminden bağımsız, doğrudan proje içindeki dosyayı okur
            storeFile = file("upload-keystore.p12") 
        }
    }


    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
