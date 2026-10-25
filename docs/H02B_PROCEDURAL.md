# H02-B — Generación y verificación de unicidad

Base: `main` (`98fc112`), Godot **4.6.3**. Algoritmo de generación: **`h02b-1`**. Esta entrega añade lógica y herramientas de desarrollo; no conecta tableros generados a la interfaz, los controles Android, la secuencia de juego ni el guardado. Los tres tableros existentes, las reglas y la firma permanente permanecen intactos. No implementa H02-C.

## Arquitectura

- `HashiSolver` (`scripts/hashi_solver.gd`), `RefCounted`: definición de islas → estado de búsqueda, hasta dos soluciones y métricas. Sin escenas, nodos, archivos ni controles visuales.
- `HashiGenerator` (`scripts/hashi_generator.gd`), `RefCounted`: semilla y parámetros → resultado explícito de éxito/fallo. Construye una solución completa, deriva sus números y exige una prueba de unicidad con el solucionador.
- `tools/evaluate_generation.gd`: adaptador CLI mediante SceneTree, exclusivamente para evaluar lotes. No forma parte de la interfaz del juego.

Se reutilizan `HashiPuzzle` y `HashiRules` sin modificarlos. No se incorporan dependencias de aplicación distintas de Godot. Las pruebas usan las herramientas ya disponibles: Bash, Python estándar y `timeout` de GNU Coreutils para el watchdog Linux.

## Solucionador

```gdscript
var result = HashiSolver.new().solve(puzzle, {
    "max_nodes": 100000,
    "max_time_ms": 1000,
})
```

El solucionador interpreta las pistas de `puzzle.islands`; **ignora los puentes colocados** y no modifica el objeto de entrada. No es todavía un asistente para continuar una partida parcial.

Calcula conexiones únicamente entre vecinos visibles horizontales o verticales. Cada arista tiene un dominio `{0, 1, 2}`. La propagación aplica mínimos/máximos de grado por isla, excluye cruces cuando una arista debe existir y descarta estados cuyo grafo de conexiones todavía posibles ya está desconectado. Si quedan alternativas, elige una arista de dominio mínimo y explora sus valores en orden estable. Cada solución completa se valida además con `HashiRules.is_solved`, incluida su conectividad real.

Resultados:

| `status` | Interpretación |
| --- | --- |
| `invalid` | Entrada mal formada, variante no soportada o límites fuera del rango admitido; `reason` explica la causa. Más de 64 islas da `island_limit`, un límite de implementación, no una regla nueva de Hashi. |
| `none` | Se agotó la búsqueda sin soluciones. |
| `unique` | Se agotó la búsqueda y existe exactamente una solución. |
| `multiple` | Hay al menos dos soluciones; la búsqueda se detiene en dos y `count_capped` es verdadero. |
| `incomplete` | Se agotó tiempo o nodos. Puede contener cero o una solución encontrada, **sin demostrar unicidad ni ausencia de soluciones**. |

`solutions` contiene diccionarios de puentes canónicos y `solution_count` cuenta los testigos encontrados, como máximo dos. `max_nodes=0` o `max_time_ms=0` no autorizan una prueba: devuelven `incomplete`.

Límites del solucionador: hasta 64 islas, hasta 1 000 000 nodos y hasta 60 000 ms por invocación; los valores por defecto son 100 000 nodos y 1000 ms. Solo se resuelven reglas clásicas. Se rechazan metadatos de variante distintos de `classic`; no se adivina el comportamiento de variantes futuras.

## Generador

```gdscript
var result = HashiGenerator.new().generate(42, {
    "width": 5,
    "height": 5,
    "island_count": 10,
    "max_attempts": 100,
    "max_time_ms": 1500,
    "solver_max_nodes": 100000,
})
if result.status == "success":
    var puzzle = HashiPuzzle.new(result.puzzle) # Sin puentes colocados.
    # result.solution es el testigo de unicidad, no debe mostrarse al jugador.
```

1. Selecciona celdas distintas de una rejilla y ordena sus IDs por fila/columna.
2. Intenta construir un árbol de expansión sin cruces sobre los vecinos válidos, con uno o dos puentes por enlace. Rechaza geometrías que no logra conectar.
3. Añade algunas conexiones adicionales que no crucen la red. Los grados resultantes determinan los números 1..8 de las islas.
4. Verifica la solución construida con las reglas existentes.
5. Ejecuta el solucionador sobre las pistas. Solo acepta `unique`, y exige que la solución única coincida con el testigo construido. Un puzzle múltiple se descarta; una contradicción entre testigo y solucionador produce un fallo explícito, no se oculta como otro intento.

El éxito incluye `seed`, `algorithm_version`, `parameters`, `attempts`, `puzzle`, `solution`, `construction_solution`, `uniqueness`, `metrics` y `elapsed_ms`. El fallo incluye `status=failure`, `reason`, `attempts` y duración. No hay un tablero de reemplazo con unicidad sin demostrar.

Rangos: ancho/alto 1..16; cantidad de islas 2..64 y no superior al número de celdas; intentos 0..10 000; tiempo 0..60 000 ms; nodos por búsqueda 0..1 000 000. Los parámetros desconocidos se rechazan. El agotamiento se informa mediante `attempt_limit`, `time_limit` o `solver_*_limit`; no lanza un bucle de reintentos ilimitado.

### Reproducibilidad y tiempo

La selección aleatoria usa Park–Miller con aritmética entera de 64 bits y Fisher–Yates, sin depender del generador aleatorio global ni de su implementación en futuras versiones de Godot. Las semillas se normalizan módulo 2 147 483 646; distintas semillas pueden producir el mismo diseño, y el PRNG no es criptográfico.

Con la misma semilla, parámetros y versión, **los resultados exitosos tienen el mismo tablero, solución y número de intentos**. Los tiempos medidos no forman parte de esa igualdad. Se incluye una prueba dorada de la semilla 42, además de comparar procesos independientes. Cualquier cambio que altere el diseño determinista deberá actualizar `ALGORITHM_VERSION` y sus fixtures de reproducibilidad de forma explícita.

Un plazo de reloj puede agotarse en una máquina más lenta. En ese caso el resultado es fallo, nunca otro tablero: el generador **no salta un candidato cuya unicidad quedó incompleta** para aceptar otro que dependa de la velocidad de la máquina. Así no promete que un plazo de 1 ms tenga el mismo éxito en todos los dispositivos. Los límites de reloj son cooperativos, se comprueban entre pasos acotados y pueden excederse ligeramente por el paso en curso o por planificación del sistema operativo; no son una garantía de tiempo real.

## Métricas experimentales

- `islands`: número de islas.
- `possible_connections`: número de conexiones geométricas candidatas.
- `double_bridge_ratio`: conexiones dobles / conexiones no vacías de la primera solución encontrada; cero si no hay testigo.
- `forced_decisions`: dominios de aristas que pasan de varias opciones a una durante propagación.
- `assumptions`, `backtracks`, `used_assumptions`, `used_backtracking`: ramificaciones probadas y ramas sin nuevas soluciones.
- `search_nodes`, `max_depth`, `elapsed_ms`: trabajo y duración de resolución.

Los contadores abarcan la búsqueda de unicidad completa, incluidas ramas descartadas. Una misma arista puede contribuir varias veces en ramas distintas. No son un solucionador lógico humano ni una clasificación validada de dificultad. Cambiar las estrategias de búsqueda puede cambiar estas métricas sin cambiar las pistas. El generador no permite todavía seleccionar dificultad ni garantiza una distribución uniforme de tableros.

## Evaluar lotes

Desde la raíz del repositorio:

```bash
./tools/dev.sh --headless --script tools/evaluate_generation.gd -- \
  --seed=1 --count=100 --width=5 --height=5 --island_count=10 \
  --max_attempts=100 --max_time_ms=1500 --solver_max_nodes=100000 \
  --output=.local/hashis-5x5.jsonl
```

Las semillas del lote son consecutivas desde `--seed`. También pueden usarse rejillas no cuadradas y de una sola fila/columna. La herramienta imprime una fila JSON por tablero con semilla, dimensiones, métricas, resultado de unicidad, pistas y solución, además del entorno y un resumen. `--output` es opcional; su carpeta debe existir. Escribe solo el informe solicitado; no lee ni modifica partidas de `user://`. Devuelve código 1 si cualquier generación falla y 2 por errores de argumentos o archivo. El lote admite 1..1000 tableros; el límite de tiempo se aplica por tablero, no a todo el lote.

Ejemplos reproducibles con `h02b-1`:

| Semilla | Rejilla / islas | Intentos | Conexiones posibles | Suposiciones / retrocesos |
| --- | --- | --- | --- | --- |
| 1 | 5×5 / 10 | 1 | 10 | 0 / 0 |
| 38 | 5×5 / 10 | 1 | 11 | 4 / 2 |
| 42 | 5×5 / 10 | 4 | 10 | 0 / 0 |
| 50 | 8×8 / 24 | 4 | 33 | 13 / 9 |

Por ejemplo, `--seed=42 --count=1 --width=5 --height=5 --island_count=10` reproduce la prueba dorada. [H02B_BENCHMARK.json](H02B_BENCHMARK.json) contiene hashes SHA-256 de las islas serializadas como JSON canónico para estos ejemplos, parámetros, métricas y mediciones completas del resumen.

## Validación y rendimiento observados

`./tests/run.sh`, Godot 4.6.3 en Linux:

- 60 comprobaciones originales de H01 y 121 de H02-A, intactas y aprobadas.
- Los dos procesos de escritura/recuperación de partidas siguen pasando.
- **615 comprobaciones de H02-B**, sin fallos: definiciones válidas/incorrectas, cero/una/múltiples soluciones, cruces forzados, islas intermedias, desconexión, límites, reproducción, dimensiones y testigos de construcción.
- Contraste con enumeración independiente de 256 combinaciones de pistas sobre un cuadrado y 64 sobre una topología con cruce posible. El oráculo no comparte propagación ni dominios con el solucionador.
- Incluye el caso de encontrar una solución antes de agotar presupuesto: el resultado sigue siendo incompleto. Se prueban intentos positivos agotados y límites de tiempo positivos, no solo presupuestos cero.
- Watchdog externo Linux de 30 s para la suite H02-B; las aserciones de tiempo usan márgenes amplios para detectar bloqueos y no comparar microsegundos entre máquinas. La suite H02-B tardó aproximadamente 0,21 s en este entorno.
- 15 pruebas de seguridad de firma existentes, aprobadas; no se suministraron secretos ni se ejecutaron compilaciones Android.

CPU disponible: **AMD EPYC 9V74 80-Core Processor**, Godot 4.6.3 oficial. Medidas de generación completa, incluyendo candidatos rechazados y prueba de unicidad:

| Lote | Éxito | Media | Mediana | p95 | Máximo |
| --- | --- | --- | --- | --- | --- |
| Semillas 1..100, 5×5, 10 islas | 100/100 | 2,95 ms | 2,13 ms | 7,02 ms | 8,93 ms |
| Semillas 1..50, 8×8, 24 islas | 50/50 | 54,59 ms | 33,85 ms | 195,21 ms | 232,30 ms |

Ambos lotes se repitieron en procesos independientes: los **150 tableros, soluciones e intentos coincidieron**. Son datos de una máquina de la nube, no de Android ni una promesa de rendimiento para todas las semillas o todos los tamaños admitidos.

## Límites e integración futura propuesta

La generación es por rechazo y puede fallar para geometrías dispersas, tamaños grandes o presupuestos pequeños. La búsqueda es exponencial en el peor caso; los límites evitan trabajo ilimitado. Las cotas superiores del API son límites de recursos, no una garantía de éxito para toda combinación de parámetros.

Las llamadas del núcleo son síncronas y no acceden a nodos. **No deben ejecutarse directamente en el hilo de la interfaz**: la integración posterior deberá usar una instancia independiente por tarea en `WorkerThreadPool` y entregar el resultado al hilo principal una vez terminada. No compartir la misma instancia mutable entre tareas. Esta entrega no llama al generador desde ninguna escena, por lo que no introduce esperas en el juego actual.

Para integrar más adelante: seleccionar parámetros mediante una política separada, ejecutar en segundo plano, aceptar solo `success` y construir un `HashiPuzzle` con las pistas, sin mostrar la solución. Antes de cambiar la continuidad habrá que decidir cómo registrar semilla, parámetros y versión del algoritmo y recuperar esos IDs en el catálogo; el guardado actual solo conoce los tableros registrados. **No se ha cambiado su formato ni se ha implementado esa integración.**

No se han probado exportaciones Android/web del generador ni rendimiento en un dispositivo real. No se modificó la firma permanente ni se usaron sus secretos.
