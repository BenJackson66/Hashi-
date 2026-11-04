# H06 — Historia con variantes visibles, candidata 0.5.0 / código 5

Base: candidata H05-A `ed884c45a508c1d360e875d246d1aa141dc46fb3` (fuente revisada `9db6a95d36be6015007a35981e30a6d08d952233`). PR apilado sobre `feature/h05-story`; no fusionado. Contrato y revisión independiente: issue#13.

## Juego

- Azul: conserva su número y cada conexión incidente admite como máximo un puente. Distintivo **S** además del color; el gesto alterna0→1→0. La generación exige al menos una azul con número≥ 2.
- Misteriosa: muestra **?**, no tiene número oculto ni ecuación de grado. Las otras pistas y la conectividad determinan sus conexiones. El único valor público válido de target es 0; cualquier otro se rechaza.
- Combinadas: ambos tipos en islas distintas. Las reglas habituales de vecindad, cruces y red conectada siguen vigentes.

Historia conserva sus 12 niveles iniciales clásicos y continúa en etapas de 4. En partidas nuevas, las etapas 4/5/6 introducen azules/misteriosas/combinadas; etapa 7 es clásica y el ciclo se repite. No se asignan etiquetas Directo/Reflexivo a las variantes. Las leyendas aparecen en mapa, tablero y Cómo jugar.

Se conservan los 12 iniciales y los 4 niveles más recientes de la ruta continua, con puentes y victoria. La frontera de desbloqueo es monotónica; repetir, reiniciar, deshacer o reabrir no la incrementa dos veces. Las series libre/fija/progresión siguen siendo clásicas y conservan su propio procedural.

## Modelo y generación

`HashiVariantRules`, `HashiVariantSolver`, `HashiVariantRecipe` y `HashiVariantGenerator` separan las nuevas reglas, búsqueda, identidad pública y producción. `HashiRuleSet` despacha en los límites de aplicación. Los archivos clásicos Rules/Solver/Generator y los 12 tableros H05 son idénticos a la base; se mantiene h02b-1 y su identidad golden.

El solver de variantes limita dominios incidentes a azules a0/1, mantiene0/1/2 en el resto, impone cardinalidad solo a islas numeradas y comprueba conectividad. Tiene límites de tiempo/nodos explícitos y devuelve incomplete sin afirmar unicidad si los alcanza.

El generador parte de un clásico único en el worker, selecciona una azul con todas sus aristas testigo simples y elimina hasta 2 pistas solo si el nuevo solver demuestra unicidad bajo las pistas visibles. multiple permite restaurar una pista; incomplete aborta la solicitud. none/invalid abortan por inconsistencia. No se omiten candidatos por límites dependientes de velocidad. La política conserva el presupuesto de tiempo solicitado y comparte una fecha límite entre los reintentos; un presupuesto nulo o inválido falla sin receta. La verificación final debe ser unique.

Solo se devuelve la receta pública: no hay solutions/construction_solution/bridges ni objetivo original de misteriosas en el handoff. El nuevo algoritmo e identidad SHA-256 incluyen versión de reglas, semilla y todas las pistas públicas canónicas. La receta de variantes se acepta exclusivamente en Historia; el normalizador de procedural libre sigue rechazándola. El solver no se ejecuta al abrir cada guardado.

## Guardado y migración

Snapshot atómico v5 en el archivo histórico, lectura v1/v2/v3/v4. Estado de Historia2 fija `variant_from` y política `visible-route-1`. Una Historia antigua fija su primera etapa nueva en el siguiente múltiplo de 4 estrictamente posterior a la frontera actual y al menos 12. No se reinterpretan recetas clásicas guardadas ni se reemplazan sus puentes. Abrir migra en memoria sin reescribir; el siguiente guardado válido publica todo junto.

Los fallos de escritura conservan selección, recetas, run y frontera anteriores; el Board más reciente se reintenta antes de navegar. La ventana acotada evita crecimiento ilimitado del archivo. Las recetas antiguas classic-continuation-1 siguen legibles sin cambiar identidad.

## Evidencia ejecutada

Godot 4.6.3 oficial verificado. `tests/run.sh`: **73.892 comprobaciones, 0 fallos**, confirmadas por CI de la fuente `1370510ca6157d60969d4801968a9f2dfb7b0609`: [run41758421615](https://github.com/BenJackson66/Hashi-/actions/runs/41758421615), success. También pasan las reaperturas clásica/procedural en procesos separados. Minerva revisó fuente, oráculo, migración y capturas, y autorizó una compilación agrupada; este commit documental activa ese build sin modificar juego ni workflows.

- `tests/variant_oracle.gd`: autoría/revisión independiente de Minerva,621 comprobaciones sobre 291 casos públicos. Enumeración autónoma de grafos 4/6 con cruce y caminos externos:258 sin solución, 31 únicos, 2 múltiples. Contrasta los conjuntos testigo sin usar reglas ni aristas productivas.
- `tests/variants.gd`:387 comprobaciones de generación determinista en 15 combinaciones semilla/tipo, unicidad visible, rechazo de target secreto, límites, ciclo azul, feedback de advertencias, leyendas,25 niveles de UI y reaperturas.
- `tests/variant_migration_review.gd`: revisión independiente de Minerva,71 comprobaciones. Archivo v4 real con frontera 14, receta clásica parcial y serie conservada; migración sin escritura, frontera futura 16, fallo real de escritura al entrar azul, reintento y reapertura exacta.
- Suites heredadas de reglas, identidad, perfiles, modos, Historia y firma continúan pasando. Sus comprobaciones históricas no son nuevas muestras estadísticas.

Render real Xvfb/llvmpipe a 360×640 y 480×800: `tools/variants_walkthrough.gd`,0 fallos. Capturas de tablero/mapa azul, misterioso y combinado en `docs/review/variants/`; tablero≥ 200px y cabecera/pie dentro del viewport. Son eventos/escenas de escritorio; instalación e interacción táctil Android físicas siguen pendientes del equipo.

## Distribución

Identidad `org.hashi.prototype`, candidata 0.5.0/versionCode 5. Workflow nuevo `variants-tests.yml` sin secretos y `variants-apk.yml` separado, permisos mínimos, gate[apk]. La compilación agrupada se activa únicamente después del dictamen favorable de Minerva sobre la fuente y CI indicados arriba. Comparación criptográfica con H02-C si el artefacto se conserva; declara UNAVAILABLE si no es descargable. Sin cambio de firma, secretos, publicación en tiendas ni merges.
