# Build Guide - Projeto Ally v2.1

Este documento contém as configurações e comandos necessários para gerar builds do **Projeto Ally** para Windows e Android.

## 🖥️ Build Windows

### Pré-requisitos
- **Godot 4.4.1** - `C:\Users\ALLYSON\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe`
- **NSIS** - `D:\NSIS\makensis.exe`

### Comando de Export
```bash
cd "D:\PROJETO-2D-EX\projeto-ally"
"C:\Users\ALLYSON\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --export-release "Windows Desktop" "builds/projeto-ally.exe"
```

### Gerar Instalador
```bash
cd "D:\PROJETO-2D-EX\projeto-ally"
"D:\NSIS\makensis.exe" installer.nsi
```

**Resultado:** `builds/Projeto Ally v2.1 Installer.exe` (48MB)

---

## 📱 Build Android

### Pré-requisitos
- **Android SDK:** `C:\Users\ALLYSON\AppData\Local\Android\Sdk`
- **Java JDK:** `C:\Program Files\Android\Android Studio\jbr`
- **Build Tools:** `C:\Users\ALLYSON\AppData\Local\Android\Sdk\build-tools\34.0.0`

### Configurações do Godot
Arquivo: `C:\Users\ALLYSON\AppData\Roaming\Godot\editor_settings-4.4.tres`
```ini
export/android/java_sdk_path = "C:/Program Files/Android/Android Studio/jbr"
export/android/android_sdk_path = "C:\\Users\\ALLYSON\\AppData\\Local\\Android\\Sdk"
export/android/debug_keystore = "C:/Users/ALLYSON/AppData/Roaming/Godot/keystores/debug.keystore"
export/android/debug_keystore_pass = "android"
```

### Keystore de Release
```bash
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore "D:\PROJETO-2D-EX\projeto-ally\release.keystore" -alias projeto_ally -keyalg RSA -keysize 2048 -validity 25000 -storepass projetoally123 -keypass projetoally123 -dname "CN=Project Brothers, OU=Game Dev, O=Project Brothers, L=Brazil, ST=Brasil, C=BR"
```

### Preset Android
Arquivo: `export_presets.cfg` - Configurações importantes:
```ini
[preset.1]
name="Android"
platform="Android"
export_path="builds/projeto-ally-signed.apk"
package/unique_name="com.projectbrothers.projetoally"
package/name="Projeto Ally"
package/signed=true
keystore/release="D:/PROJETO-2D-EX/projeto-ally/release.keystore"
keystore/release_user="projeto_ally"
keystore/release_password="projetoally123"
architectures/arm64-v8a=true
version/name="2.1"
```

### Comando de Export Android
```bash
cd "D:\PROJETO-2D-EX\projeto-ally"
"C:\Users\ALLYSON\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --export-release "Android" "builds/projeto-ally-signed.apk"
```

**Resultado:** `builds/projeto-ally-signed.apk` (31.6MB)

---

## 🔧 Correções Importantes

### Problema: Sprites Invisíveis no Build
**Causa:** Carregamento dinâmico de texturas via `load()` não funciona em builds compilados.

**Solução:** Criados recursos pré-carregados:
- `player_sprites.gd` - Sprites do player com `preload()`
- `enemy_sprites.gd` - Sprites do inimigo com `preload()`

### Problema: APK "Pacote Inválido"
**Causa:** APK não assinado corretamente.

**Solução:** Configuração de keystore de release com assinatura adequada usando apksigner.

---

## 📋 Arquivos Finais

### Windows
- **Instalador:** `builds/Projeto Ally v2.1 Installer.exe`
- **Executável:** `builds/projeto-ally.exe`
- **Recursos:** `builds/projeto-ally.pck`

### Android  
- **APK Assinado:** `builds/projeto-ally-signed.apk`
- **Keystore:** `release.keystore`

---

## 🎯 Informações do Projeto

- **Engine:** Godot 4.4.1
- **Versão:** 2.1
- **Desenvolvedor:** Project Brothers
- **Package ID:** com.projectbrothers.projetoally
- **Arquitetura Android:** ARM64-v8a
- **Assinatura:** RSA 2048-bit, válida por 68 anos

---

*Documento gerado automaticamente durante o processo de build - Projeto Ally v2.1*