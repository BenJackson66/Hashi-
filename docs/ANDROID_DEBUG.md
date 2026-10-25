# H01-B — APK Android de depuración en GitHub Actions

## Qué se configura

Workflow: **Android Debug APK**, archivo `.github/workflows/android-debug.yml`. Solo se activa manualmente mediante `workflow_dispatch`; el job solo compila `feature/h01-prototipo`. No hace merge, no publica Releases ni distribuye a tiendas. Permisos del token: únicamente `contents: read`.

El runner Ubuntu 24.04 instala JDK 17, Android SDK y Godot **4.6.3** estándar, junto con su plantilla Android debug oficial de la misma versión. El motor y las plantillas se verifican con SHA-512 fijados desde el archivo oficial de sumas. Las acciones se fijan por SHA de commit.

Componentes Android:

- SDK Platform 36.
- SDK Build-Tools **36.1.0** (`apksigner`, `zipalign` y `aapt`).
- Platform-Tools (`adb`).
- Command-line Tools, proporcionadas por `android-actions/setup-android`.

El ajuste de importación de texturas ETC2/ASTC está activado en `project.godot`, como exige el exportador Android. No cambia las reglas, los tableros ni los controles.

La guía general 4.6 todavía enumera SDK 35/Build-Tools 35.0.1, mientras que el código etiquetado **4.6.3-stable** fija SDK 36/Build-Tools 36.1.0. Esta configuración sigue la versión exacta del motor. Se usa la plantilla APK precompilada, sin Gradle, plugins nativos ni recompilación del motor; no hace falta NDK/CMake para este flujo.

Referencias oficiales:

- [Exportar para Android, Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html).
- [Versiones Android de Godot 4.6.3](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/android/java/app/config.gradle).
- [Artefactos y sumas de Godot 4.6.3](https://github.com/godotengine/godot/releases/tag/4.6.3-stable).

## Ejecución manual

1. Abre el repositorio `BenJackson66/Hashi-` en GitHub y entra en **Actions**.
2. Selecciona **Android Debug APK** → **Run workflow**.
3. Selecciona la rama **feature/h01-prototipo** y confirma **Run workflow**. Elegir otra rama hace que el job se omita.
4. Espera a que termine correctamente. El workflow importa el proyecto, ejecuta las pruebas de H01, exporta con `--export-debug` y verifica estáticamente el APK.

**Requisito inicial de GitHub:** `workflow_dispatch` solo puede ejecutarse si el archivo del workflow existe en la rama predeterminada. Actualmente `main` solo contiene el commit inicial, por lo que el archivo añadido exclusivamente en la rama feature aún no cumple ese requisito. Para habilitarlo se necesita una acción posterior autorizada que coloque el workflow en la rama predeterminada o cambie esa configuración del repositorio. Esta misión no modifica `main` ni fusiona ramas. [Documentación oficial](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

También deben estar habilitados GitHub Actions y las acciones usadas en Settings → Actions → General, y la cuenta que ejecuta debe tener permiso para disparar workflows. No se necesitan secrets del repositorio ni credenciales comerciales de firma.

Una vez habilitado, también puede iniciarse con:

```bash
gh workflow run android-debug.yml --repo BenJackson66/Hashi- --ref feature/h01-prototipo
```

## APK y firma

Artefacto por ejecución: **`hashi-h01-debug-arm64-<número de ejecución>`**, disponible en **Actions → ejecución → Artifacts** durante 14 días. Contiene:

- `hashi-h01-debug-arm64.apk`.
- `SHA256SUMS.txt`.
- `apk-verification.txt` con la información del manifiesto.

Ruta del APK en el runner: `build/android/hashi-h01-debug-arm64.apk`. Paquete: `org.hashi.prototype`. Solo ARM64 (`arm64-v8a`), Android 7.0/API 24 o posterior, target API 36.

Cada ejecución genera una clave **exclusivamente de depuración**, con contraseña aleatoria en memoria y archivo ignorado bajo `.local/`. La clave se borra al finalizar la exportación; no se incluye en el artefacto. No se guardan contraseñas ni claves privadas en Git y no se usa firma de producción. Puesto que la firma cambia entre ejecuciones, puede ser necesario desinstalar una compilación previa antes de instalar otra; esto elimina sus datos locales.

Las verificaciones automáticas exigen firma válida, alineación de 16 KB para bibliotecas nativas, paquete y niveles SDK esperados, flag debug, única ABI ARM64, actividad de lanzamiento, ZIP íntegro y tableros empaquetados. Estas son comprobaciones del archivo: **no prueban que el sistema Android lo instale ni que el juego funcione en un teléfono**.

## Descargar con un teléfono Android

1. Abre GitHub en Chrome u otro navegador e inicia sesión con una cuenta que tenga acceso al repositorio. Si no ves Actions/Artifacts, activa **Sitio de escritorio** del navegador.
2. Ve a **Actions → Android Debug APK → ejecución completada correctamente**. Comprueba la rama y el commit.
3. Baja a **Artifacts** y toca `hashi-h01-debug-arm64-<número>`. GitHub descarga un archivo ZIP; no es una Release ni un enlace público permanente.
4. En la aplicación Archivos/Files, abre Descargas y **extrae el ZIP**. Toca `hashi-h01-debug-arm64.apk`.
5. Si Android lo solicita, habilita **Permitir desde esta fuente** únicamente para el navegador o gestor de archivos usado, y pulsa **Instalar**. Puedes desactivar ese permiso al terminar.
6. Si aparece un conflicto de firma con otra compilación debug, desinstala la anterior y vuelve a intentar. Un teléfono de 32 bits no admite este APK ARM64.
7. Abre Hashi. Para validar el funcionamiento, prueba en el teléfono los tres tableros, toques y deslizamientos, reinicio, advertencias y victoria. Reporta modelo del teléfono, versión de Android y commit usado.

La instalación física puede verificarse además con `adb install <apk>` en un dispositivo ARM64 conectado y autorizado. Aquí no se ha realizado esa prueba.

## Estado y bloqueos observados en H01-B

- La consulta inicial de Actions devolvió `Forbidden`. Una consulta posterior del repositorio sí funcionó y confirmó `main` como rama predeterminada y permisos de acceso; no se solicitaron credenciales nuevas. El resultado final del intento de ejecución se registra en la entrega.
- El workflow está preparado en la rama feature; falta su presencia en la rama predeterminada para `workflow_dispatch`.
- No existe todavía una ejecución de Actions validada ni un artefacto de Actions confirmado. No debe interpretarse el nombre previsto del artefacto como un archivo ya publicado.
- Los resultados de la exportación local en la nube y de las comprobaciones finales se registran en la entrega de la misión. No hay dispositivo Android conectado; instalación y funcionamiento real quedan pendientes.

### Exportación verificada en esta máquina de la nube

`tools/ci/install-godot.sh` verificó las sumas oficiales del motor y de las plantillas. `tools/ci/export-android.sh` terminó con código 0: importación, **60 comprobaciones de H01 sin fallos**, exportación debug y verificación del APK. Los keystores temporales se eliminaron al terminar.

APK local: `build/android/hashi-h01-debug-arm64.apk`, aproximadamente 27 MB. Este archivo generado está ignorado por Git; no es un artefacto de Actions. Su suma está en `build/android/SHA256SUMS.txt`.

La exportación local se probó con OpenJDK 21, versión superior admitida por Godot; el workflow fija el JDK 17 recomendado. Se usaron Build-Tools 36.1.0 y la plantilla oficial 4.6.3. No se instaló el APK en Android ni se probó el juego en un dispositivo real.
