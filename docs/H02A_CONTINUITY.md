# H02-A — Experiencia y continuidad

Base de desarrollo: `main` en `b10cbb0`. Rama: `feature/h02a-continuidad`. Sin cambios en reglas clásicas, modelo de islas, datos/soluciones de los tres tableros ni las 60 comprobaciones originales. Sin generación procedural.

## Juego

- **Deshacer / Rehacer:** cada modificación real de puentes registra una instantánea anterior y posterior. Incluye reinicios. Se pueden encadenar movimientos en ambos sentidos; un movimiento nuevo descarta el futuro de rehacer. Seleccionar una isla, rechazar una conexión o reiniciar un tablero vacío no crea registros ni invalida rehacer.
- La confirmación de victoria usa el mensaje de estado, sin diálogo modal. **Siguiente** solo está habilitado mientras el tablero actual está resuelto; deshacer un movimiento de la solución lo deshabilita, y rehacerlo lo habilita otra vez.
- La secuencia provisional es Inicio → Conexiones → Cruces → Inicio. El tercer nivel muestra **Volver al primero** y menciona expresamente el carácter provisional. Se conservan las partidas de cada tablero, incluso al volver al primero. **Reiniciar** permite empezar ese tablero otra vez.
- La marca **✓** del selector registra que el tablero se completó alguna vez. Reiniciar o deshacer no borra ese hito; la victoria actual y la habilitación de Siguiente se calculan con las reglas sobre los puentes actuales.
- Historial en memoria por tablero abierto: se vacía al cambiar de nivel o relanzar la aplicación. Las advertencias siguen desactivadas por defecto y no se persisten.

## Separación de responsabilidades

- `HashiHistory`: instantáneas independientes y operaciones de deshacer/rehacer, sin UI ni archivos.
- `HashiSequence`: política de selección del siguiente ID a partir del catálogo. Es el punto de sustitución para futuras modalidades; no se implementan Historia, dificultad fija ni progresión automática.
- `HashiSession`: tablero actual, instantáneas por nivel, hitos completados y navegación; usa la política y el almacén sin conocer controles.
- `HashiSaveStore`: formato y validación del archivo, límites de tamaño y escritura mediante reemplazo de un temporal.
- `HashiBoard`: conserva la interacción de puentes y expone cambios reales; la escena principal enlaza los botones, la sesión y el autoguardado.

## Formato persistente

Ruta de producción: **`user://hashi-save-v1.json`**, resuelta por Godot al directorio privado de la aplicación (en Android, el almacenamiento propio del paquete). No necesita permisos de almacenamiento compartido ni credenciales. Ejemplo de una partida parcial:

```json
{
  "version": 1,
  "current_puzzle_id": "h01_2",
  "boards": {
    "h01_1": {"0:1": 2, "1:3": 2, "2:3": 1},
    "h01_2": {"0:1": 1}
  },
  "completed_ids": ["h01_1"]
}
```

Se guarda después de un cambio real (incluidos deshacer, rehacer y reiniciar), de cambiar de tablero. Al recibir notificaciones de pausa, pérdida de foco o cierre se reintenta una escritura pendiente que hubiera fallado. Primero se escribe y vacía `hashi-save-v1.json.tmp`, y después se reemplaza el archivo principal. Un temporal incompleto se ignora al recuperar. Si falla la escritura se muestra un aviso y la partida sigue en memoria.

Se exige versión 1, tipos correctos, IDs de catálogo conocidos, selección existente, hitos sin duplicados, claves de puentes canónicas, extremos vecinos válidos y cantidades enteras 1/2. Se comprueban cruces y pasos por islas antes de recuperar el estado. Los números JSON se normalizan a enteros. No se importan islas o reglas desde el archivo guardado.

Los estados parciales desconectados y los excesos numéricos se aceptan porque H01 permite explorarlos; no cuentan como victoria. Los archivos corruptos, incompatibles o mayores de 128 KiB se rechazan completos: la aplicación muestra un aviso y comienza una partida nueva en memoria. El archivo rechazado no se sobrescribe solo por abrir la aplicación, aunque una acción posterior válida puede reemplazarlo. No se implementan migraciones de versiones futuras, cifrado, guardado en servidor ni verificación antifraude de hitos.

## Pruebas y límites

```bash
./tests/run.sh
```

- **60 comprobaciones originales**, conservadas en `tests/run.gd`: reglas, unicidad, gestos y victoria.
- **121 comprobaciones H02-A**: historial sucesivo, bifurcación, no-op, reinicio, recorrido de los tres niveles y retorno, snapshots independientes, guardado/restauración, rechazos de datos inválidos, temporal incompleto, error de escritura y controles de UI.
- Dos procesos independientes de Godot: uno resuelve el primer tablero, pasa al segundo, coloca un puente y termina; otro recupera nivel, puentes y progreso desde disco y verifica un nuevo deshacer.
- Prueba de layout con área lógica y ventana de 360×640, 480×800 y 720×1280; comprueba que tablero y botones de navegación queden dentro del área disponible.
- Todo el estado de usuario de las pruebas vive en un directorio temporal que se elimina al terminar, sin tocar partidas reales.

Las pruebas se ejecutaron con Godot 4.6.3 sin pantalla y pasaron. La exportación local de Android debug ARM64 también pasó las verificaciones de firma, alineación, manifiesto y datos empaquetados. La exportación local utiliza JDK 21 admitido por el motor; Actions mantiene JDK 17.

No se ha inspeccionado visualmente la UI ni se ha probado en un dispositivo Android real. Los eventos de pausa del sistema operativo, el área segura, el teclado/sistema de navegación y el almacenamiento en el teléfono requieren la prueba física descrita abajo. No se ha validado persistencia en navegador web; el almacenamiento de Godot en web depende de las políticas del navegador.

## Cómo probar en Android

1. En GitHub, Actions → **Android Debug APK** → Run workflow, selecciona **feature/h02a-continuidad**. La condición de esta rama permite construir H02-A; `main` conserva su configuración hasta revisar y fusionar el PR por separado.
2. Descarga el artefacto `hashi-h01-debug-arm64-<número>` de una ejecución correcta y extrae `hashi-h01-debug-arm64.apk`. Se mantienen los nombres de H01-B por compatibilidad del workflow. Ver también [la guía de descarga desde el teléfono](ANDROID_DEBUG.md#descargar-con-un-teléfono-android).
3. Instálalo en un teléfono ARM64 con Android 7.0 o posterior. Las firmas debug son efímeras: si debes desinstalar una versión anterior para resolver un conflicto de firma, sus datos se borrarán; esto no sirve como prueba de continuidad entre versiones.
4. Coloca varios puentes; prueba Deshacer/Rehacer sucesivos, deshaz y haz un cambio nuevo para comprobar que Rehacer se deshabilita. Intenta un gesto inválido y verifica que no añade historial.
5. Reinicia y deshaz el reinicio. Resuelve un nivel, deshaz para retirar la victoria y rehace para recuperarla. Pulsa Siguiente; completa la secuencia y comprueba Volver al primero.
6. Deja el segundo o tercer tablero a medias. Sal a Inicio, cierra/quita la app de recientes y vuelve a abrirla **sin desinstalar ni borrar datos**. Deben conservarse nivel, puentes y marcas ✓. Repite tras deshacer y tras reiniciar.
7. Comprueba botones y legibilidad en el teléfono; registra modelo, versión de Android y commit/APK usados. Estas pruebas físicas siguen pendientes.
