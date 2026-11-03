# H04 — Dificultad fija y Progresión automática

Implementación sobre `44a84433c306b80db7d45fc8bbcba9a623373cef`, apilada sobre el PR #7; sin fusionar. La candidata 0.3.0/código3 se compila únicamente después de revisión de fuente, mediante un commit explícito `[apk]`. Contrato #8 y encargo #9. La revisión independiente corresponde a Minerva; este documento es el informe de implementación.

## Informe funcional

Inicio conserva Continuar y Partida libre. El perfil libre sigue aplicándose al próximo tablero libre. **Nueva serie · Dificultad fija** empieza una serie con el perfil elegido, que se mantiene al pulsar Nuevo/Siguiente aunque cambie la preferencia libre. **Nueva serie · Progresión** empieza en cero y aplica este recorrido:

| Victorias acreditadas antes del siguiente tablero | Perfil del siguiente |
|---|---|
| 0–2 | Directo |
| 3 | Directo |
| 4 | Reflexivo |
| 5 | Directo |
| 6 | Reflexivo |
| 7 o más | Reflexivo, sin final |

Son tres etapas de producto: tres tableros Directo, cuatro alternados, y Reflexivo continuo. No se presentan como tres dificultades lógicas distintas ni como escala científica. La cabecera indica etapa, contador y perfil del tablero actual. Al resolver se acredita la victoria; el cambio de perfil se aplica al siguiente tablero, no transforma el actual.

Continuar retoma la serie. Una nueva serie reinicia su contador y conserva los tres tableros de aprendizaje. Si existe un procedural parcial se exige confirmación; cancelar conserva modo, contador y puentes. Cambiar a aprendizaje y regresar al procedural conserva la serie.

Reiniciar, deshacer una victoria y volver a resolver el mismo tablero no suman otra victoria ni restan la acreditada. La acreditación persiste al cerrar antes de pulsar Siguiente. Cada serie comienza con un tablero nuevo; las victorias históricas v1/v2 no se convierten en progreso de una serie recién introducida.

## Informe técnico

- `HashiPlayMode`: política de perfiles, validación de la serie, crédito idempotente y descripción. No conoce UI ni archivos.
- `HashiSession`: incluye `run` en el snapshot; `capture_and_save` publica puentes, finalización y crédito únicamente después de escritura atómica. Instalación y selección usan la misma sesión candidata aislada.
- `HashiSaveStore`: formato v3 en la ruta histórica, lectura v1/v2/v3. La migración sucede en memoria al abrir, sin reescribir el archivo. El siguiente guardado válido escribe v3.
- `main.gd`: conserva intención de modo a través de confirmación y worker. Navegar invalida simultáneamente receta e intención. Una escritura fallida conserva el Board más reciente, no publica crédito y bloquea generación/selección hasta que un reintento capture ese Board correctamente.
- Menú: separa perfil libre, nueva serie y Continuar. La advertencia metodológica se sustituye por explicaciones para jugar.

`run` tiene seis campos constantes: versión, modo, perfil fijo, victorias, ID acreditado y perfil del tablero actual. El ID acreditado pertenece al único procedural retenido; al reemplazarlo se descarta solo el marcador, conservando contador. No hay un historial creciente de IDs que pueda llenar el guardado durante juego infinito. El contador entero satura en el máximo seguro JSON (aproximadamente 9×10^15); la etapa final sigue permitiendo tableros indefinidamente.

La semilla, receta, algoritmo `h02b-1`, esquema de identidad y reglas clásicas no cambian. La firma, el workflow Android anterior, el paquete y los secretos no se modifican. La candidata incrementa nombre/código a0.3.0/3; un workflow separado con permisos contents/actions read solo exporta si el commit contiene `[apk]` y publica resumen/artefacto sin modificar PRs. No hay transacción repartida entre dos archivos: modo/progreso y partida se guardan juntos. La preferencia libre sigue independiente y no puede cambiar una serie fija.

## Validación

Godot 4.6.3 oficial Linux obtenido del release oficial y verificado con el SHA-512 fijado en el instalador existente. `tests/run.sh` usa directorios temporales aislados. La nueva suite `tests/play_modes.gd` cubre escala exacta, perfil fijo, writes fallidos reales, reintentos, crédito único, replay/reset, restauración, migración v2 sin reescritura, metadatos inválidos, tamaño acotado y flujo UI de confirmar/cancelar/cambiar modo y resultados obsoletos. Las suites anteriores se conservan; únicamente la aserción que exigía escribir versión 2 se adapta a `Store.VERSION` manteniendo la comprobación de formato vigente.

`play-modes-tests.yml` ejecuta pruebas sin claves ni exportación, con `contents: read`. No cambia el job de exportación Android.

La suite completa ejecutada localmente pasó72.439 comprobaciones (61 nuevas de modos y60 de revisión independiente de fronteras), más procesos de reapertura. Se añadieron después cuatro regresiones focales, con65/0 en la suite de modos: el total final esperado en CI es72.443. El resultado real de CI y SHA exacto figuran en el PR.

Se ejecutó además `tools/modes_walkthrough.gd` con Xvfb/X11 y OpenGL llvmpipe: cero fallos. Las capturas en `docs/review/play-modes/` cubren menú arriba/abajo y modos Fijo Reflexivo/Progresión a360×640 y480×800. El recorrido pulsa controles bajo el scroll mediante eventos de ratón y verifica tablero y footer dentro del área; la selección del perfil se inyecta por señal y no equivale a selector nativo Android. Xvfb y sus dos bibliotecas faltantes se extrajeron de paquetes Ubuntu cuyos hashes se cotejaron contra índices firmados con la clave de Ubuntu instalada. El servidor y Godot se ejecutaron en el mismo shell debido al aislamiento de sockets entre ejecuciones. No se acredita prueba física Android, instalación/actualización ni interacción táctil en un teléfono. El aviso del editor sobre Android build-tools local no impide las suites de juego y no se presenta como una exportación realizada.
