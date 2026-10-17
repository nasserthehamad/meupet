#!/usr/bin/env python3
"""Faz o Gradle assinar SEMPRE com a chave fixa do repositório (android-keystore/).
Assim cada APK novo instala por cima do anterior (mesma assinatura)."""
import pathlib

app = pathlib.Path('android/app')
kts = app / 'build.gradle.kts'
groovy = app / 'build.gradle'
if kts.exists():
    kts.write_text(kts.read_text() + '''

// --- Meu Pet+: assinatura fixa (adicionado pelo CI) ---
android {
    signingConfigs {
        create("meupet") {
            storeFile = file("../../android-keystore/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
    buildTypes {
        getByName("release") { signingConfig = signingConfigs.getByName("meupet") }
        getByName("debug") { signingConfig = signingConfigs.getByName("meupet") }
    }
}
''')
    print('assinatura fixa configurada em', kts)
elif groovy.exists():
    groovy.write_text(groovy.read_text() + '''

// --- Meu Pet+: assinatura fixa (adicionado pelo CI) ---
android {
    signingConfigs {
        meupet {
            storeFile file("../../android-keystore/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }
    buildTypes {
        release { signingConfig signingConfigs.meupet }
        debug { signingConfig signingConfigs.meupet }
    }
}
''')
    print('assinatura fixa configurada em', groovy)
else:
    raise SystemExit('build.gradle não encontrado')
