# H03-A — Investigación de dificultad lógica

Estado: investigación para revisión; **no habilitar aún tres niveles como clasificación validada**.
Base: `main`, `5df7fd7c0f77e85f8670399e1d17f0bb2ef44719`. Godot 4.6.3.
Analizador experimental: `h03a-1`. Generador conservado: `h02b-1`.

## Dictamen

Podemos reproducir y explicar dos perfiles en las muestras: resolución mediante restricciones locales y resolución que, con el repertorio ensayado, necesita además contradicciones de una sola hipótesis. No encontramos un tercer grupo intermedio resuelto exclusivamente mediante cortes de conectividad y paridad. **Los datos no justifican todavía una separación fiable Fácil/Normal/Difícil.**

Recomendamos conservar perfiles y pruebas explicables, ampliar el repertorio de deducciones de grupos y contrastar ejemplos con jugadores antes de implementar el selector. Una búsqueda pequeña no demuestra facilidad humana; que este analizador ensaye una hipótesis tampoco demuestra que toda persona necesite hacerlo.

No se modifican código de producción, interfaz, guardado, firma, reglas, tableros ni generación. Python estándar basta para las herramientas aisladas en `tools/research/`; no se añade dependencia al juego ni al CI.

## Qué mide el solucionador existente

Fuentes primarias: [solucionador](../scripts/hashi_solver.gd), [generador](../scripts/hashi_generator.gd), [reglas](../scripts/hashi_rules.gd), [identidad y evaluación H02-B](H02B_PROCEDURAL.md). Las técnicas propuestas abajo se justifican matemáticamente a partir de esas reglas; no se atribuyen a una escala publicada o validada con usuarios.

| Información actual | Interpretación y límite |
|---|---|
| Dominios 0/1/2 de conexiones vecinas | Base para razonar sin revelar la solución. Se excluyen islas intermedias y se calculan cruces geométricos. |
| `_propagate`: mínimos/máximos por isla y exclusión de cruces | Deducciones obligatorias **condicionadas al estado de esa rama**. En la raíz son incondicionales; bajo una conjetura pueden dejar de serlo. |
| `forced_decisions` | Cuenta reducciones a singleton, también en ramas descartadas; omite reducciones parciales. No es cantidad de pasos humanos ni repertorio de técnicas. |
| `_potentially_connected` | Descarta una rama cuyo grafo posible está desconectado. No deduce todos los cortes obligatorios ni paridad de grupos. |
| `assumptions`, `backtracks`, `max_depth` | Trabajo del DFS MRV con orden fijo de conexiones y valores. Incluye búsqueda de una segunda solución y ramas fallidas. No equivale a conjeturas inevitables para un humano. |
| `search_nodes`, `elapsed_ms` | Instrumentación computacional, sensible al algoritmo/orden y, para tiempo, al equipo/carga. No se usan como etiquetas de dificultad. |
| Islas, conexiones posibles, proporción de dobles | Estructura y densidad. Un doble o una isla adicional no implican una técnica más avanzada. |

El generador construye una red, deriva números, rechaza candidatos y pide al solucionador demostrar unicidad. Se detiene ante búsqueda incompleta: no trata un límite como prueba. Sus métricas `metrics` describen **la comprobación del candidato aceptado**, no la suma de todos los candidatos. `elapsed_ms` de generación sí incluye intentos rechazados. El análisis de dificultad ocurre después de esta demostración independiente; no sustituye ni cambia su criterio de aceptación.

## Modelo explicable, sin puntuación arbitraria

Representamos cada conexión candidata con un dominio de cantidades posibles. El analizador recibe solamente las islas: no recibe semilla, testigo ni solución. Reinicia siempre con `[0,1,2]`. Orden estable: islas/conexiones en el orden de `h02b-1`, valores ascendentes, una deducción cada vez. Se aplica primero todo el repertorio local, luego una técnica de grupo, y se vuelve a lo local. Solo cuando ambos se agotan se prueba contradicción. Repetir con las mismas pistas y versión produce la misma traza, excluyendo tiempos.

| Técnica | Explicación para el jugador y prueba de corrección |
|---|---|
| `local_capacity` | «Esta isla aún necesita N; los otros vecinos como máximo pueden aportar M». Para una conexión de dominio D, con suma de mínimos L y máximos U, conservar v solo si `v + L − min(D) ≤ número ≤ v + U − max(D)`. Ninguna solución puede violar esa desigualdad. Incluye isla completa, único vecino, capacidad máxima y puentes mínimos obligatorios. |
| `crossing_exclusion` | Si una conexión tiene mínimo positivo, todas las que la cruzan valen cero. Es la prohibición clásica de cruces. |
| `connectivity_cut` | En el grafo de conexiones todavía posibles, si retirar una conexión separa las islas en dos grupos, esa conexión debe existir. Es el único enlace posible entre ambos; no usarlo impide la red única. La traza guarda el grupo separado. |
| `cut_parity` | Si un grupo tiene una única conexión posible con el exterior, la suma de sus números es `2 × puentes internos + puentes de salida`. Su paridad determina una salida simple (impar) o doble (par), dado que debe ser positiva y como máximo dos. No se presupone que el grupo esté resuelto. |
| `single_assumption_contradiction` | «Si aquí hubiera v puentes, la propagación produciría una isla imposible, un cruce o una red imposible; por tanto v no sirve». Se copia el estado, fija una sola conexión y aplica exclusivamente técnicas locales/de grupo hasta contradicción o punto fijo. No se anidan hipótesis ni se adopta una hipótesis porque complete una solución. La traza incluye supuesto, deducciones condicionales y causa de contradicción. |

Los dominios solo pierden valores: como máximo dos eliminaciones por conexión. Cada cierre termina. Los ensayos recorren conexiones/valores finitos; presupuesto adicional de 10.000 ensayos, con resultado `probe_limit` sin clasificar si se agota. Esta herramienta offline no es un servicio interactivo ni implementa un límite de tiempo de Android. El generador conserva sus propios límites existentes.

Perfiles reproducibles, en orden de repertorio:

- `local`: resuelto exclusivamente con capacidad local y exclusión de cruces.
- `connectivity`: lo local se atasca; cortes/paridad permiten terminar sin suposiciones.
- `contradiction1`: requiere al menos una eliminación demostrada por una hipótesis dentro de este repertorio.
- `unclassified`: queda sin resolver, se alcanza presupuesto o aparece contradicción. Nunca convertir automáticamente «no clasificado» en Difícil.

El perfil expresa la potencia del repertorio utilizado, no una dificultad humana absoluta. Cada traza da una cota superior constructiva de técnicas suficientes. El atasco del repertorio inferior permite afirmar que **ese repertorio** no termina el tablero; no excluye otros patrones humanos. Se registran también número de reducciones, ensayos, tamaño de pruebas, conexiones y cruces para futuros estudios, sin sumar pesos ni fijar umbrales de carga mental.

## Experimento reproducible

Muestra principal: semillas enteras **1 a 200 inclusive** en cada una de cinco configuraciones: 1.000 solicitudes. Segunda ejecución completa: otras 1.000 solicitudes con las mismas semillas y parámetros, para verificar reproducibilidad, no ampliar la muestra estadística. No se seleccionan semillas por su resultado ni se cambia `h02b-1`.

Parámetros comunes: `max_attempts=100`, `max_time_ms=1500`, `solver_max_nodes=100000`. Equipo: AMD EPYC 9V74, Godot `4.6.3-stable (official)`, Python 3.12.14, Linux sin interfaz gráfica. Los tiempos de la primera ejecución final se conservan; no son mediciones Android ni garantías de latencia. La repetición comprueba identidades, pistas, soluciones, intentos, métricas no temporales y todas las trazas.

Los archivos de [evidencia](research/h03a/) contienen el resumen, registros crudos de generación y trazas de todos los tableros, comprimidos con gzip. Incluyen soluciones **solo como datos offline de investigación**; no se incorporan al juego ni al guardado. Los SHA-256 del generador y solucionador están en `summary.json`; `manifest.json` identifica los archivos y herramientas analizadas.

Comandos desde la raíz del repositorio (Godot 4.6.3 en PATH):

```sh
python3 tools/research/test_logical_difficulty.py
python3 tools/research/run_experiment.py --output .local/h03a-run
python3 tools/research/compare_experiments.py docs/research/h03a .local/h03a-run
python3 tools/research/audit_dataset.py docs/research/h03a
./tests/run.sh
```

El runner usa sin cambios `tools/evaluate_generation.gd`, conserva fallos por motivo y comprueba el resumen de cada lote. `--count` y `--seed` permiten ampliar la muestra; para comparar con la evidencia usar los valores por defecto. Los perfiles no dependen del testigo: se consulta únicamente después, como auditoría de corrección. Otro equipo puede agotar el presupuesto y devolver fallo en lugar del mismo tablero; eso se registra como diferencia, nunca como una nueva clasificación equivalente.

## Resultados de la primera ejecución final

Todos los 1.000 tableros fueron generados y demostrados únicos: **100 % observado**, cero fallos de presupuesto. La segunda ejecución coincidió en los 1.000 contenidos y trazas. No es una garantía para otras semillas o equipos.

| Rejilla / islas | Local | Grupos sin hipótesis | Contradicción 1 | Generación media / p95 (ms) |
|---|---:|---:|---:|---:|
| 5×5 / 10 | 181 (90.5 %) | 0 | 19 (9.5 %) | 3.26 / 7.25 |
| 5×5 / 16 | 146 (73.0 %) | 0 | 54 (27.0 %) | 41.11 / 115.76 |
| 7×7 / 16 | 169 (84.5 %) | 0 | 31 (15.5 %) | 10.59 / 25.90 |
| 8×8 / 24 | 141 (70.5 %) | 0 | 59 (29.5 %) | 48.08 / 157.58 |
| 10×10 / 30 | 144 (72.0 %) | 0 | 56 (28.0 %) | 95.84 / 258.64 |

No quedaron casos sin clasificar ni se agotó el presupuesto de ensayos. Hubo algunas deducciones de corte/paridad dentro de resoluciones que también necesitaron contradicción; no bastaron para crear un perfil intermedio.

| Rejilla / islas | Conexiones posibles medias | Pares de cruces medios | Proporción de conexiones dobles media | Intentos medios |
|---|---:|---:|---:|---:|
| 5×5 / 10 | 10.65 | 0.46 | 0.543 | 2.04 |
| 5×5 / 16 | 22.01 | 1.85 | 0.581 | 5.43 |
| 7×7 / 16 | 18.65 | 2.08 | 0.514 | 2.61 |
| 8×8 / 24 | 32.23 | 6.51 | 0.526 | 3.83 |
| 10×10 / 30 | 40.50 | 10.78 | 0.517 | 6.03 |

El perfil local tuvo exactamente un nodo del solucionador en todos estos casos; es una coincidencia con su propagación actual, no la definición del perfil. Para los perfiles de contradicción:

| Rejilla / islas | Nodos medios / máximo | Tiempo solver medio (ms) | Ensayos medios / máximo del analizador | Análisis medio / p95 (ms) |
|---|---:|---:|---:|---:|
| 5×5 / 10 | 3.21 / 5 | 1.05 | 1.74 / 4 | 0.44 / 0.69 |
| 5×5 / 16 | 5.22 / 19 | 3.33 | 3.98 / 30 | 1.98 / 4.22 |
| 7×7 / 16 | 3.74 / 9 | 2.87 | 2.29 / 10 | 1.39 / 2.38 |
| 8×8 / 24 | 5.00 / 15 | 7.21 | 5.58 / 61 | 4.41 / 16.01 |
| 10×10 / 30 | 5.00 / 12 | 11.81 | 2.79 / 13 | 4.98 / 9.13 |

Coste amortizado observado para candidatos de producto, incluyendo generación y análisis de todos los descartados por perfil:

| Candidato | Configuración | Aceptación | Coste medio amortizado por aceptado |
|---|---|---:|---:|
| Fácil | 5×5 / 10 | 90.5 % | 3.87 ms |
| Difícil experimental | 5×5 / 10 | 9.5 % | 36.90 ms |
| Difícil experimental | 5×5 / 16 | 27.0 % | 156.50 ms |
| Normal | Ninguna acreditada | 0 % observado | No estimable |

Estas razones empíricas de coste no son p95 de espera ni una garantía de muestreo independiente. El resumen JSON conserva máximos y p95 por perfil.

Ejemplos reproducibles: 5×5/10 semilla 1 → `local`; semilla 28 → `contradiction1`; 5×5/16 semilla 8 → `contradiction1`. En la semilla 28, tras 15 reducciones locales, suponer cero en `i02–i03` fuerza tres reducciones adicionales y deja desconectado el grafo posible; se elimina ese cero y la propagación local completa el tablero. La prueba completa está en el registro de esa semilla.


## Interpretación y propuesta para niveles posteriores

**Fácil, candidato:** repertorio `local`, sin hipótesis. Inicialmente 5×5/10 como distribución de candidatos; aceptar por traza, no por tamaño. Aceptación observada 90,5 %. El coste amortizado se calcula incluyendo todos los tableros rechazados por perfil, no solo los aceptados. Sigue pendiente distinguir un paso local evidente de una cadena local larga: este perfil no garantiza accesibilidad para principiantes.

**Normal, hipótesis de diseño:** lo local se atasca y una deducción directa de grupos/cortes/paridad permite terminar, sin suposiciones. Investigar 5×5/16 y 7×7/16: mantienen el número de islas y varían la densidad, facilitando comparar patrones. Aceptación observada del perfil `connectivity`: **0/200 en cada configuración**, por tanto no existe una configuración recomendada con rendimiento demostrado ni coste finito estimable para abastecer este nivel. No fabricar Normal dividiendo tiempos, nodos, número de islas o una mediana de puntuaciones. Ampliar técnicas de grupos con pruebas de corrección antes de volver a medir.

**Difícil, candidato experimental:** atasco local/de grupos y resolución completa por contradicciones de una hipótesis, sin anidamiento. 5×5/16 aporta 27 % de aceptación; 5×5/10 aporta 9,5 % y permite una comparación con Fácil a dimensiones idénticas. Es un repertorio superior, pero una relación de grupos aún no implementada podría reemplazar la hipótesis. No tratarlo como dificultad humana validada. Si en otro lote no se resuelve con este repertorio, conservar «sin clasificar».

Los costes medidos no constituyen un compromiso de generación en teléfono. Un filtro de dificultad debe tener presupuesto propio, conservar la generación asíncrona y devolver fallo explícito si no obtiene el perfil solicitado; nunca relajar el perfil o cambiar el algoritmo silenciosamente. No se integra tal filtro en esta investigación.

## Límites, controles y siguiente decisión

- Cinco configuraciones y semillas consecutivas; son un estudio exploratorio del sesgo de este generador, no un muestreo representativo de todos los Hashi. 200 casos por configuración permiten detectar tendencias amplias, no tasas exactas. Para una tasa cero en 200 casos, el límite superior binomial unilateral del 95 % es aproximadamente 1,49 %, **solo bajo un supuesto de muestras independientes que aquí no demostramos**. Repetir semillas no reduce esa incertidumbre.
- La densidad importa: con 16 islas, 5×5 produce más perfiles de contradicción que 7×7. El tamaño no es una escala lógica. Los perfiles locales existen en todas las dimensiones estudiadas.
- El repertorio de grupos es deliberadamente pequeño: no explora subconjuntos arbitrarios, balances de múltiples salidas, patrones visuales ni cadenas de contradicciones anidadas. La ausencia de un grupo Normal describe este experimento; no demuestra que ese grupo no exista en Hashi.
- El orden de deducciones y ensayos afecta longitudes y pruebas elegidas. Se versiona y se conserva la traza; no se afirma encontrar la explicación humana más corta. Para entradas externas habría que normalizar/validar antes; la herramienta consume definiciones válidas del generador, no reemplaza el validador de producción.
- Tests: oráculo exhaustivo independiente de asignaciones 0/1/2 sobre 256 combinaciones de pistas de un cuadrado y 256 de una geometría cruzada; se preserva **toda** solución, no solo la primera. Se añaden casos cruzados satisfacibles, islas intermedias, cortes de grupos/paridad, tableros ambiguos, presupuesto y determinismo. La auditoría de los 1.000 registros reproduce clasificaciones y comprueba cada deducción aceptada contra su testigo único. No constituye una prueba formal exhaustiva para tableros arbitrarios; las justificaciones anteriores explican la corrección general de cada regla.
- Suite existente conservada y ejecutada: H01 60, continuidad 121, H02-B 615, identidad 57, H02-C 112, firma 15; procesos de reapertura v1 y procedural aprobados. Cinco tests de investigación adicionales aprobados. Sin APK nueva, prueba visual ni validación en dispositivo. La importación del editor advirtió que no encuentra el directorio Android `build-tools` en su configuración local; no impidió las pruebas y no se intentó exportar.

Antes de implementar tres niveles: ampliar conjuntos de semillas y geometrías; añadir deducciones de grupos justificadas y medir si aparece un perfil intermedio; seleccionar ejemplos con igual tamaño y distinto repertorio; realizar un piloto con jugadores (errores, bloqueos, pistas solicitadas, explicación de pasos y tiempos humanos); comprobar concordancia entre perfiles y experiencia. Fijar después umbrales de carga y contratos de aceptación versionados. Si el perfil intermedio sigue sin aparecer, ofrecer temporalmente dos perfiles explicados o aplazar el selector, en vez de prometer tres dificultades sin evidencia.
