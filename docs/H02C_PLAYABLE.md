# H02-C — Tableros procedurales jugables

Base: `main` (`88265b7`), Godot **4.6.3**. La generación y la identidad siguen usando `h02b-1` y `procedural-id1-h02b-1-<sha256>` sin cambios. No se modifican las reglas, los tres tableros prediseñados ni la firma permanente Android.

## Uso

**Nuevo tablero**, en la misma fila que Deshacer/Rehacer, solicita una semilla nueva y un acertijo de **5×5 con 10 islas**. El botón se deshabilita mientras exista una tarea pendiente; el estado muestra «Generando tablero…». No se ofrece selección de dificultad.

El tablero actual permanece visible y se puede seguir jugando o navegar. Si se cambia de nivel, se modifica el tablero, se deshace o se reinicia mientras se genera, el resultado pendiente se descarta al terminar; así no reemplaza una acción más reciente. El botón vuelve a habilitarse cuando se recoge ese resultado. La tarea se deja terminar dentro de sus presupuestos, sin cancelación forzosa de hilos.

Solo un resultado generado y guardado correctamente sustituye el tablero procedural reciente. Fallos, presupuestos agotados y resultados obsoletos conservan la partida anterior. Una nueva instalación de la misma identidad es idempotente: no borra sus puentes.

Se conservan los tres niveles y su navegación Inicio → Conexiones → Cruces → Inicio. Tras generar, aparece una cuarta entrada **Procedural** en el selector. Se guarda **un solo procedural reciente**: otro éxito reemplaza ese slot, sus puentes y su marca de completado, manteniendo los niveles prediseñados y sus partidas. No se implementa una biblioteca de tableros generados. Al resolver el procedural, el botón **Inicio** permite regresar a la secuencia estática; también se puede pedir Nuevo tablero.

Los gestos, reglas, advertencias, reinicio, victoria y deshacer/rehacer siguen siendo los existentes. Como en H02-A, el historial es de la sesión abierta: cambiar de tablero o relanzar lo vacía, pero los puentes y el progreso se conservan.

## Generación fuera del hilo principal

`HashiGenerationTask` es un `RefCounted` que ejecuta `HashiGenerator.new().generate` en `WorkerThreadPool`. Cada solicitud crea una instancia nueva y copia sus parámetros; las tareas no comparten un generador mutable ni nodos de interfaz. Un mutex protege el traspaso de un resultado copiado.

La escena consulta `is_task_completed` desde `_process` y solo recoge el resultado cuando ya ha terminado. No espera a la generación dentro del bucle interactivo. Un contador de solicitud invalida resultados antiguos. Una escena marcada para eliminación no acepta resultados; al destruirse recoge la tarea pendiente para liberar recursos. Esa unión final puede esperar hasta el presupuesto acotado de la tarea (1500 ms por defecto), únicamente durante el cierre, no en la interacción normal.

El worker elimina del resultado tanto `solution` como `construction_solution` antes de entregarlo. La UI recibe únicamente estado, receta y pistas. Si una tarea terminara sin resultado, se convierte en un fallo recuperable en lugar de dejar el botón bloqueado.

Los presupuestos predeterminados son 100 intentos, 1500 ms y 100 000 nodos por prueba de unicidad, los mismos valores por defecto de H02-B. Los límites de reloj continúan siendo cooperativos, no de tiempo real.

## Persistencia v2 y compatibilidad

La ruta permanece **`user://hashi-save-v1.json`**, pese al nombre histórico, para encontrar las partidas instaladas. El campo interno `version` pasa a **2**. No cambian el paquete Android, las rutas de datos de Godot ni las credenciales de firma.

El lector acepta:

- **v1:** los cuatro campos históricos (`version`, `current_puzzle_id`, `boards`, `completed_ids`), con los IDs prediseñados. Se normaliza a v2 en memoria, con `procedural: {}`. Leer no reescribe el archivo; la siguiente escritura válida guarda v2 en la misma ruta.
- **v2:** los mismos campos más `procedural`, un diccionario de cero o un registro indexado por su ID estable.

Cada registro procedural tiene exactamente:

| Campo | Contenido |
| --- | --- |
| `seed` | Cadena decimal canónica, para conservar incluso enteros de 64 bits sin pérdida al leer JSON. |
| `algorithm_version` | `h02b-1`. |
| `identity_schema` | `1`. |
| `parameters` | Parámetros de contenido y presupuestos normalizados de H02-B. |
| `puzzle` | Solo `id`, `title` e `islands` (pistas y metadatos clásicos). |

`boards[id]` sigue conteniendo únicamente los puentes **colocados por el jugador**. Una partida terminada puede tener todos los puentes correctos; eso no añade una solución oculta ni otro testigo del solucionador al estado.

La recuperación registra temporalmente la definición procedural validada en el catálogo y reconstruye `HashiPuzzle` con sus puentes guardados. **No vuelve a generar ni a resolver el tablero al abrir la aplicación**: no depende de presupuestos de una máquina distinta y no bloquea la apertura con una búsqueda. Los IDs y datos guardados se recuperan exactamente.

Validaciones antes de aceptar:

- Versiones, tipos, campos permitidos, tamaños y máximo de un procedural; límite total de 128 KiB conservado.
- Semilla decimal canónica, versión del algoritmo/esquema conocidas, parámetros enteros y dentro de los límites de H02-B.
- Islas clásicas válidas, cantidad y coordenadas coherentes con la receta.
- Recomputación del ID de H02-B a partir de semilla, contenido y pistas, tras normalizar enteros JSON.
- IDs conocidos, puentes canónicos 1/2 entre vecinos válidos y sin cruces, con las validaciones anteriores de partidas parciales. Los excesos numéricos permitidos al jugar no se rechazan al recuperar.
- Campos de solución, puentes ocultos dentro de la definición y metadatos adicionales no admitidos son rechazados.

La unicidad se demuestra en el worker al generar. El hash comprueba integridad y correspondencia de la receta/pistas recuperadas, **no autenticidad frente a una edición deliberada que recalcule el hash**; no hay un sistema antifraude ni se repite una prueba de unicidad al abrir.

La escritura mantiene el temporal, `flush` y reemplazo del archivo anterior. La sustitución de un procedural es transaccional: `HashiSession.install_procedural_and_save` prepara una sesión candidata con copias del catálogo, receta, puentes, completados y selección, intenta guardar esa instantánea y solo publica el nuevo estado después de confirmar la escritura. La UI no cambia de tablero ni borra el historial antes de esa confirmación.

Si falla el guardado del nuevo procedural, se descarta la candidata: continúan el tablero anterior, sus puentes, sus completados, el historial de deshacer/rehacer y los bytes del archivo previo. El aviso dice «No se pudo guardar el nuevo tablero. Se conserva tu partida. Inténtalo de nuevo.» y se puede volver a pulsar Nuevo tablero. La receta descartada no queda pendiente para activarse al pausar o cerrar. Si ya había cambios anteriores sin guardar, su aviso y política de reintento se mantienen, sin incorporar el tablero rechazado.

Para movimientos dentro de un tablero ya activo se conserva el comportamiento de H02-A: un fallo de autoguardado mantiene esos movimientos en memoria, muestra el aviso y reintenta al pausar/perder foco/cerrar. Una generación rechazada no cambia el archivo. Datos inválidos o versiones desconocidas se rechazan completos con un aviso; no se aplican parcialmente ni se sobrescriben solo por abrir. No se garantiza que aplicaciones antiguas puedan leer v2 si se instala una versión anterior del juego.

## Validación automatizada

```bash
./tests/run.sh
```

Godot 4.6.3, sin pantalla:

- 60 comprobaciones H01, 121 H02-A, 615 procedurales H02-B, 57 de identidad y 15 casos de seguridad de firma: aprobados.
- **112 comprobaciones H02-C**, aprobadas: worker real, inputs copiados, duplicados, resultado sin testigos, presentación 5×5/10, interacción táctil sintética, historial, victoria, navegación, errores, resultados obsoletos, cierre de escena, escritura fallida y recuperación.
- Regresión transaccional con un procedural anterior jugado, marca de completado y ambos historiales: se bloquea el temporal de la ruta de guardado real, se comprueban sesión/archivo/UI intactos y recuperación exacta, y se vuelve a generar con escritura disponible para verificar activación persistida.
- Compatibilidad v1→v2, persistencia de semilla de 64 bits, comprobación de identidad tras normalizar JSON, rechazo de archivos manipulados y prohibición de campos de solución.
- Dos procesos nuevos e independientes: el primero pulsa Nuevo tablero, juega, usa deshacer/rehacer, navega y termina; el segundo abre la app, compara el estado completo con la referencia del primero y continúa jugando. **Ambos PASS**, sin regenerar.
- Los dos procesos originales de H02-A siguen pasando.
- Controles y navegación dentro del área lógica a 360×640, 480×800 y 720×1280. Esto no equivale a inspección visual ni a una prueba táctil física.

La única actualización de una prueba previa es usar `Store.VERSION + 1` en lugar de la constante `2` para seguir comprobando rechazo de versiones futuras; no se elimina esa comprobación ni se debilita una regla.

## APK y validación manual Android, después de revisar

**No se ha iniciado un build de H02-C ni se ha publicado una APK de esta implementación antes de revisión.** El workflow sigue siendo manual; solo se ha añadido `feature/h02-c-playable-generation` a las ramas admitidas. La configuración de firma permanente, secretos, verificación de certificados, paquete y presets permanecen sin cambios.

Tras revisar la implementación:

1. En Actions → **Android Debug APK** → Run workflow, selecciona `feature/h02-c-playable-generation` y comprueba que el commit sea el del PR revisado.
2. Descarga `hashi-h01-debug-arm64-<número>` y extrae `hashi-h01-debug-arm64.apk` (nombres heredados del pipeline). No reutilices el artefacto de otra rama.
3. Actualiza la instalación firmada con la identidad permanente: `adb install -r <apk>` o abre el APK desde Archivos. **No desinstales ni borres datos** para probar migración y continuidad. Se necesita el mismo paquete/certificado y un versionCode compatible. Si el APK instalado fuera uno antiguo de firma efímera, el conflicto de identidad no puede resolverse borrando datos como parte de esta prueba; consulta la guía de firma antes de continuar.
4. Si existe una partida H02-A v1, comprueba nivel, puentes y completados antes de generar. Haz un movimiento y vuelve a abrir para probar v2.
5. Pulsa Nuevo tablero, verifica las 10 islas sin puentes revelados y prueba tocar/deslizar, Deshacer/Rehacer, Reiniciar y victoria. Prueba un segundo toque al botón mientras está ocupado.
6. Crea progreso, sal a Inicio, cierra/quita Hashi de recientes y vuelve a abrir **sin reinstalar**. Deben conservarse exactamente el procedural, sus puentes y su receta/ID.
7. Cambia a un prediseñado mientras se genera: el resultado tardío no debe sustituirlo. Repite mientras haces un movimiento. Verifica después los tres niveles y la entrada Procedural.
8. Comprueba tipografía, área segura, gestos y responsividad en el teléfono; registra modelo, Android, commit y ejecución de Actions.

Esta prueba física y la APK posterior a revisión quedan pendientes. El entorno actual no tiene dispositivo Android ni servidor gráfico. Tampoco se ha validado la generación con el preset web sin hilos; no se ha cambiado ese preset ni se declara compatibilidad web de esta integración.
