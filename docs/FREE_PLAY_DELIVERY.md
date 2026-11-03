# Entrega jugable 0.2.0 — Inicio y partida libre

Entrega agrupada conforme al contrato [#8](https://github.com/BenJackson66/Hashi-/issues/8). Revisión independiente solicitada a Minerva mediante el PR #7; sin fusión ni publicación en tiendas. La autoevaluación de implementación que sigue no sustituye su revisión.

Base verificada: `main=01c5844eccddf209c80f84b2c6993e140a34309b`; PR #7 abierto en `8d0b4559bb8e4968dd1fd69a78a793f5480fc8e2`. Esta entrega amplía ese mismo PR, conservando su trazabilidad. El SHA final exacto, el enlace de Actions y el artefacto se publican automáticamente en #8 tras compilar la etiqueta de revisión; el workflow hace checkout de esa etiqueta inmutable, no de una rama que pueda avanzar durante la compilación.

## Informe funcional

El jugador puede abrir Inicio, recuperar la partida anterior, elegir aprendizaje o crear una partida libre. **Directo** usa deducciones locales; **Reflexivo** incluye descartes por contradicción sin hipótesis anidadas dentro del repertorio estudiado. Son dos perfiles provisionales, no tres dificultades humanas acreditadas. La variedad procede de nuevas semillas y distintas configuraciones: 5×5/10, 6×6/12 y 7×7/16. La configuración no asigna el perfil: todos los candidatos deben superar el mismo análisis lógico.

Al resolver un procedural, **Siguiente tablero** genera otro con la preferencia elegida; ya no conduce a los tableros de aprendizaje. Cambiar esa preferencia en Inicio afecta al próximo tablero, sin cambiar la partida abierta. La preferencia sobrevive al cierre, pero no constituye un modo de dificultad fija ni una progresión automática. La cabecera muestra el nombre del perfil del tablero generado.

Continuar, Deshacer/Rehacer, reinicio, advertencias opcionales, aprendizaje y confirmación para sustituir un procedural sin resolver se mantienen. Un fallo conserva el tablero anterior y permite reintentar; nunca se instala un candidato sin guardar. Inicio conserva el historial de la partida en memoria; al cambiar de tablero o relanzar sigue reiniciándose como antes.

Durante la inspección visual se corrigieron números prediseñados que aparecían como `1.0`: ahora se dibujan enteros, conservando sus pistas originales. Se amplían los círculos/números en rejillas densas sin cambiar la selección por proximidad, las reglas ni el ciclo de puentes. La indicación de instalación nueva se limita a Inicio y no se añade al final de las reglas. Atrás de Android, comprobado mediante su notificación sintética, vuelve de Partida o reglas a Inicio y cancela una confirmación; en Inicio sale de la aplicación.

## Informe técnico

| Componente | Responsabilidad |
|---|---|
| `HashiGenerator`, `HashiSolver`, `HashiRules` | Algoritmo `h02b-1`, demostración de unicidad y reglas clásicas, sin cambios. |
| `HashiLogicalProfile` | Puerto GDScript acotado del repertorio justificado de H03-A; ignora testigos, conserva trazas y devuelve «sin clasificar» ante límites. No demuestra unicidad. |
| `HashiFreePlay` | Política `free-play-1`: propuestas deterministas de geometría y semillas, generación y rechazo por perfil. No conoce escenas ni archivos. |
| `HashiGenerationTask` | Trabajo asíncrono con datos copiados y entrega única protegida por mutex. Descarta soluciones dentro del worker. Conserva también el API original sin filtro. |
| `HashiSession`, `HashiSaveStore` | Estado independiente por tablero y escritura antes de publicación. Sin cambios respecto a H03-B1, ruta y esquema de partida v1/v2 intactos. |
| `hashi_free_settings.gd` | Preferencia opcional en `<ruta de partida>.preferences`, ConfigFile versionado 1, tamaño máximo 4 KiB, valores permitidos y escritura temporal/renombrado. Un fallo solo impide retener la preferencia entre sesiones; no cambia el guardado ni el tablero. |
| `hashi_home.gd`, `main.gd`, `HashiBoard` | Presentación, navegación, coordinación y dibujo. No incluyen el generador ni la política de dificultad. |

### Clasificación y límites

El clasificador reproduce capacidad local, exclusión de cruces, corte de conectividad, paridad de un grupo con salida única y contradicción de una hipótesis. H03-A contiene las justificaciones matemáticas. El analizador Python experimental `h03a-1` permanece intacto. El puerto conserva orden estable de conexiones, valores y técnicas; se contrasta contra los 1.000 registros archivados, no contra una copia de sus propias salidas.

Solo un tablero demostrado único por el solucionador original y resuelto completamente por el repertorio recibe un perfil jugable. Los casos de conectividad sin hipótesis no se fuerzan a una tercera etiqueta. Un clasificador incompleto no recibe perfil; una contradicción sobre un candidato único produce fallo interno explícito, no se oculta buscando otro candidato.

La política ensaya como máximo 64 candidatos y dispone de 3.000 ms compartidos entre generación y clasificación. Cada generador conserva sus presupuestos existentes, limitados por el tiempo restante. Los presupuestos pueden producir fallo, nunca asignan dificultad. Misma semilla de solicitud/perfil/versión produce el mismo primer candidato aceptado si el presupuesto alcanza; equipos más lentos pueden informar fallo. La receta guardada contiene la semilla efectiva y dimensiones del candidato aceptado, manteniendo su identidad H02-B. El título del perfil no forma parte de esa identidad. El último procedural se excluye por ID.

Se mantienen una sola tarea y una sola plaza procedural. Navegar o modificar la partida invalida resultados pendientes; la tarea acotada termina sin escribir ni cambiar de pantalla. Deshacer tras una victoria vuelve a exigir confirmación si se solicita reemplazar el tablero ahora incompleto. El siguiente procedural resuelto utiliza la misma transición transaccional y mantiene la victoria visible si falla su guardado.

## Evidencia y reproducción

`./tests/run.sh`, ejecutado con Godot 4.6.3 oficial en AMD EPYC 9V74/Linux:

| Suite | Comprobaciones | Resultado |
|---|---:|---|
| H01 | 60 | 0 fallos |
| Continuidad | 121 | 0 fallos |
| Generación H02-B | 615 | 0 fallos |
| Identidad | 57 | 0 fallos |
| H02-C, incluida transición al siguiente | 114 | 0 fallos |
| H03-B1 | 88 | 0 fallos |
| Puerto lógico contra evidencia H03-A | 70.808 | 0 fallos |
| Partida libre, selección, preferencia y ciclo | 440 | 0 fallos |
| Seguridad de firma | 15 | 0 fallos |
| Reapertura clásica y procedural, procesos separados | Escritura/lectura | PASS |

Total: **72.318 comprobaciones**, más las parejas de procesos de reapertura. Las 70.808 aserciones cubren 1.000 tableros; no representan 70.808 muestras independientes. También se prueban definición inválida, ambigüedad, cruces, red desconectada, límites, escrituras fallidas reales y recuperación.

Muestra adicional: semillas de solicitud 1–50 para cada perfil, 100 solicitudes, todas exitosas; 50 definiciones de pistas distintas por perfil, con las tres configuraciones presentes. Cada tablero se vuelve a clasificar y se verifica de nuevo con el solucionador independiente. Se repiten las primeras cinco semillas por perfil para comprobar reproducción de receta y pistas. [Mediciones completas](review/free-play/performance.json), orientativas de escritorio:

| Perfil | Candidatos medios | Selección media | p95 | Máximo |
|---|---:|---:|---:|---:|
| Directo | 1,14 | 8,16 ms | 28,26 ms | 32,76 ms |
| Reflexivo | 7,36 | 52,37 ms | 121,96 ms | 267,61 ms |

Es una muestra exploratoria; no garantiza tiempos ni éxito en otras semillas o teléfonos. Estos tiempos miden selección, no dificultad humana. La tasa de éxito 100/100 incluye rechazo de candidatos internos, por eso la columna de candidatos es relevante.

### Inspección visual e interacción

Se ejecutó `tools/review_walkthrough.gd` sobre X11/Xvfb con OpenGL real de software, Mesa llvmpipe. Xvfb se extrajo localmente de un paquete oficial Debian, verificando firma del índice con el keyring instalado y SHA-256 del paquete. No se hizo pasar una ejecución headless por inspección visual.

El recorrido tiene cero fallos, captura [Inicio](review/free-play/01-home-480.png), [reglas](review/free-play/02-rules-480.png), [aprendizaje](review/free-play/03-learn-480.png), [tablero prediseñado](review/free-play/04-learning-game-480.png), procedural, confirmación, [victoria y siguiente](review/free-play/07-victory-480.png), ambos perfiles y las resoluciones 360×640, 480×800 y 720×1280. Se revisan las capturas renderizadas. Los botones se activan mediante eventos de ratón en el viewport; un puente se coloca con eventos de touch enrutados por el viewport. La elección del segundo perfil se inyecta por señal y se inspecciona renderizada; no se presenta como prueba táctil del selector nativo de Android.

Reproducir con Godot y un servidor X11 disponible, usando datos de usuario de prueba aislados:

```sh
DISPLAY=:99 ./tools/dev.sh --rendering-method gl_compatibility --audio-driver Dummy --script tools/review_walkthrough.gd
```

Las capturas se escriben en `.local/visual-review/`. La advertencia de VSync no disponible procede de Xvfb; no impidió el renderizado. No hay `/dev/kvm`, emulador ni dispositivo Android disponible en este entorno. No se acredita instalación, actualización efectiva ni respuesta táctil Android.

## APK y revisión

Paquete conservado: `org.hashi.prototype`, ARM64, API mínima 24, Godot 4.6.3. Versión **0.2.0 / versionCode 2**, incremento para identificar esta entrega sustancial y permitir actualizar el APK anterior de código 1. No se cambian claves, alias, contraseñas ni secretos; CI continúa exigiendo la identidad persistente y verificando el certificado del APK contra el keystore suministrado. El verificador comprueba también versión real frente al preset.

El workflow manual existente se habilita para la rama del PR #7 y admite etiquetas explícitas `review-free-play-v*`: una etiqueta inicia una compilación de revisión, sin generar APK por cada arreglo o push de rama. No se crea una release comercial. El artefacto conserva su nombre histórico `hashi-h01-debug-arm64-<run_number>` e incluye APK, checksum, manifiesto y huella pública. Retención: 14 días.

CI intenta comparar el APK con el H02-C aprobado de la ejecución `40225429852`; si el artefacto anterior sigue disponible, una diferencia de certificados hace fallar la compilación. Si ya no se puede descargar, informa `UNAVAILABLE` de esa comparación, sin darla por aprobada; mantiene la verificación contra la identidad persistente actual. El resultado exacto se registra en `historical-identity.txt`, el resumen de Actions y #8.

La API de GitHub está denegada por la red del entorno local, aunque Git y la lectura web funcionan. Se utiliza el evento de etiqueta de GitHub, no un proxy alternativo: el workflow ejecuta la compilación en Actions y publica el informe por sus APIs normales. Su token limitado dispone de `contents: read`, `actions: read`, `issues: write` y `pull-requests: write` para descargar la referencia y publicar la revisión solicitada; no puede modificar secretos. El PR solo se actualiza si su head sigue siendo exactamente el SHA compilado. Si la publicación carece de permisos, se conserva el artefacto y el paso muestra la limitación; no se finge entrega en la incidencia.

Minerva revisará este PR y el artefacto concreto antes de integrar. La validación de Android que falte corresponde al equipo; Jack recibe un juego y puede comentar comodidad y disfrute, sin hojas de QA técnico ni responsabilidad sobre firma, unicidad o guardado.
