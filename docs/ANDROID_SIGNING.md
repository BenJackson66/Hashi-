# Firma Android persistente — PR #3

Esta configuración mantiene **una misma identidad debug** entre compilaciones. No se genera ninguna clave desde CI y no se usa firma comercial. No fusionar este PR ni ejecutar su workflow hasta que el propietario haya preparado, respaldado y configurado los dos secretos.

## Revisión de Godot 4.6.3

El exportador `--export-debug Android` usa estas variables oficiales:

| Variable de Godot | Origen |
| --- | --- |
| `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` | Archivo privado temporal decodificado del secreto |
| `GODOT_ANDROID_KEYSTORE_DEBUG_USER` | Alias fijo `androiddebugkey` |
| `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD` | Secreto `HASHI_SIGNING_PASSWORD` |

Se revisaron [las constantes de la versión exacta](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.h) y [su uso al firmar](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/export/export_plugin.cpp). Los campos `keystore/debug*` del preset deben estar vacíos y no debe existir `export_credentials.cfg` en la exportación aislada: los valores del preset podrían sustituir la identidad esperada.

El script comprueba alias, contraseña de almacén y presencia de una entrada de clave privada. El almacén y la clave deben usar **la misma contraseña**. La firma real de Godot comprueba que se pueda utilizar esa clave; después `apk-signing.py` verifica la firma del APK y compara su certificado SHA-256 con el certificado público extraído del almacén suministrado. Una identidad diferente aborta el job antes de subir artefactos.

## Pasos mínimos del propietario

### 1. Reutilizar una identidad existente o generar una sola vez

Si ya conservas la clave que firmó la versión instalada, reutilízala y respáldala. Un APK o su certificado público **no permiten recuperar la clave privada**. Si la antigua firma era efímera y su clave ya no existe, esta nueva identidad solo garantiza continuidad desde su primera instalación en adelante.

En una máquina privada de confianza, con JDK 17, elige una carpeta **fuera de cualquier repositorio**, por ejemplo `~/Hashi-private`. Guarda la contraseña en un gestor de contraseñas. No ejecutes estos comandos en un workflow, terminal compartido, sesión grabada ni con `set -x`.

```bash
umask 077
mkdir -p "$HOME/Hashi-private"
keystore_path="$HOME/Hashi-private/hashi-android.p12"
test ! -e "$keystore_path" || { echo 'El almacén ya existe: reutilízalo, no lo reemplaces.'; exit 1; }
keytool -genkeypair -storetype PKCS12 -alias androiddebugkey \
  -keyalg RSA -keysize 3072 -validity 10000 \
  -dname 'CN=Hashi Android Development' -keystore "$keystore_path"
```

`keytool` solicita la contraseña de forma interactiva; no la escribas como argumento ni dentro de un script. PKCS12 usa la misma contraseña para el almacén y la clave. La validez indicada es de aproximadamente 27 años: registra su vencimiento en el respaldo privado. **Este comando se ejecuta una única vez**, no cada vez que se quiera compilar. No lo ejecutes aquí ni envíes el archivo al agente.

### 2. Respaldar privadamente antes de configurar CI

Conserva al menos dos copias recuperables del mismo archivo, en ubicaciones privadas independientes, con acceso limitado. El almacén PKCS12 ya está cifrado, pero para una copia externa usa además una bóveda o volumen cifrado; guarda la contraseña y las instrucciones de recuperación en un gestor separado.

Registra privadamente: repositorio/paquete `org.hashi.prototype`, alias `androiddebugkey`, formato, vencimiento y responsables de recuperación. Un hash del archivo permite detectar cambios accidentales; el SHA-256 del certificado permite reconocer su identidad. No subas el almacén, copias, archivos codificados ni contraseñas a Git, Issues, PR, artefactos o conversaciones. Base64 **no es cifrado**.

Prueba una restauración desde la copia en otra carpeta privada y confirma que `keytool -list -keystore <copia-restaurada> -alias androiddebugkey` la abre con la contraseña almacenada. No generes una nueva identidad como prueba de restauración. GitHub Secrets no sustituye este respaldo: su interfaz no permite recuperar después el valor guardado.

### 3. Configurar los dos secretos de Actions

Autentica `gh` en tu máquina privada con una cuenta que pueda gestionar secretos del repositorio. Usa los nombres exactos, como **Repository Actions secrets**, no variables públicas ni secretos de Environment sin configurar ese Environment en el job:

- `HASHI_SIGNING_KEYSTORE_BASE64`: el archivo PKCS12/JKS completo codificado en Base64.
- `HASHI_SIGNING_PASSWORD`: la contraseña común del almacén y de la clave.

Para evitar imprimir o guardar una copia Base64, envíala directamente por stdin:

```bash
set +x
set -o pipefail
base64 < "$HOME/Hashi-private/hashi-android.p12" | tr -d '\r\n' | \
  gh secret set HASHI_SIGNING_KEYSTORE_BASE64 --repo BenJackson66/Hashi-
gh secret set HASHI_SIGNING_PASSWORD --repo BenJackson66/Hashi-
```

El segundo comando solicita el secreto interactivo; no lo pases como argumento. También puedes configurar los valores de forma privada en GitHub → Settings → Secrets and variables → Actions → New repository secret. No pegues valores en el PR ni en esta conversación. `gh secret list --repo BenJackson66/Hashi-` permite verificar únicamente nombres/fechas; no muestra valores.

### 4. Validar después de configurar ambos secretos

Solo después de preparar el respaldo y ambos secretos, revisa el PR y ejecuta manualmente **Android Debug APK** seleccionando **feature/android-persistent-signing**. Mientras este PR no esté integrado, no selecciones `main` para comprobar esta nueva configuración: esa rama puede conservar el comportamiento anterior. Este trabajo no autoriza ni realiza la fusión.

El workflow admite esta rama. Si falta cualquiera de los secretos, falla inmediatamente después del checkout, antes de instalar dependencias. Una codificación, almacén, alias o contraseña inválidos también abortan. No hay identidad alternativa, generación de claves ni subida de APK tras un fallo.

La copia privada decodificada usa permisos restrictivos y se borra al terminar o abortar, incluso ante una decodificación parcial. No se activa salida verbose de Godot. No se reenvían diagnósticos de `keytool` que puedan contener información del almacén. Los artefactos contienen APK, verificaciones y **`signing-certificate-sha256.txt`**, una huella pública, nunca el almacén ni su contenido Base64. Conserva también esa huella en el respaldo privado para detectar una sustitución accidental de secretos.

## Comparar dos APK consecutivos

Tras configurar los secretos, ejecuta el workflow dos veces sobre esta rama, sin sustituir la identidad. Descarga ambos artefactos y conserva los APK en carpetas distintas. Los nombres de artefacto siguen siendo `hashi-h01-debug-arm64-<número>` por compatibilidad.

Con Android Build-Tools 36.1.0 y `ANDROID_HOME` configurado:

```bash
python3 tools/ci/apk-signing.py compare \
  /ruta/privada/build-1/hashi-h01-debug-arm64.apk \
  /ruta/privada/build-2/hashi-h01-debug-arm64.apk
```

También acepta `--apksigner /ruta/al/apksigner` **antes** de `compare`. El programa ejecuta `apksigner verify --print-certs` sobre ambos archivos, exige exactamente un firmante y compara el SHA-256 de sus certificados. Devuelve código 1 si hay una firma inválida, certificados distintos, falta un archivo o se le pasa dos veces la misma ruta. No compara hashes de APK: pueden cambiar aunque la firma sea la misma. No acepta claves privadas ni contraseñas.

Para comprobar además la actualización real, instala el primer APK en un dispositivo Android, crea progreso y actualiza con el segundo mediante `adb install -r <segundo.apk>`, **sin desinstalar ni borrar datos**. Deben mantenerse paquete (`org.hashi.prototype`), certificado y un `versionCode` no inferior; incrementa `versionCode` en futuras versiones. Reabre Hashi y verifica nivel, puentes y progreso. La coincidencia de certificados es necesaria, pero no sustituye esta prueba física.

Si la versión instalada usa una antigua clave efímera perdida, esta nueva firma no podrá actualizarla. Puede requerir una reinstalación inicial que borra los datos privados; el proyecto no ofrece todavía una exportación/importación de partidas para esa migración. No prometer conservación de datos durante esa transición ni desinstalar automáticamente.

## Validación realizada y pendiente

- Revisión del uso de variables y alias contra el código oficial de Godot 4.6.3.
- **15 pruebas de seguridad** (`python3 tests/signing_security.py`), sin claves reales ni exportaciones: secretos ausentes/vacíos, decodificación parcial con limpieza, identidad inválida, alias sin clave privada, sustitución desde preset y comprobaciones de certificados con datos públicos ficticios.
- El acceso del agente a la lista de secretos devuelve HTTP 403. Su existencia no está confirmada; no se solicitaron valores ni se crearon secretos.
- No se generó una clave, no se ejecutó el workflow y no se realizaron compilaciones que dependan de los secretos.
- Quedan pendientes: generación/reutilización y respaldo por el propietario, configuración de secretos, dos compilaciones reales con la identidad persistente y prueba de actualización en Android conservando datos.
