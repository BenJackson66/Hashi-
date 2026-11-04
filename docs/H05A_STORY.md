# H05-A — Historia, ruta clásica

## Resultado funcional

Historia contiene doce niveles estables en tres etapas de cuatro. Resolver un nivel desbloquea el siguiente. Después de los doce iniciales, las etapas clásicas continúan con generación determinista: dos perfiles Directo y dos Reflexivo por etapa. El catálogo inicial mezcla los perfiles existentes; no introduce una tercera clasificación de dificultad ni un límite de tiempo de juego.

El mapa permite seguir la frontera desbloqueada y repetir niveles disponibles. Conserva los doce iniciales y los cuatro niveles más recientes de la ruta continua. Los anteriores a esa ventana dejan de ofrecerse; no se promete recuperar sus puentes. Repetir una victoria, reiniciar o deshacer conserva el hito sin volver a desbloquear. Siguiente desde el último inicial o un nivel antiguo retoma la ruta disponible cuando el siguiente ya fue archivado.

El procedural libre y las series fija/progresión se conservan al jugar Historia. Continuar retoma el último tablero seleccionado. Historia y aprendizaje no acreditan victorias de la serie procedural. Los niveles bloqueados también se rechazan en sesión, aunque se omita la UI.

Esta entrega implementa la ruta clásica y su infraestructura. El acuerdo original contempla después islas azules, misteriosas y combinaciones; aún no están implementadas y no se presentan como disponibles. No existe final de campaña.

## Arquitectura y persistencia

- `HashiStoryCatalog`: introducción versionada `story-classic-v1`, solo pistas, sin testigos ni soluciones empaquetadas. Conserva una caché privada de las definiciones; las copias públicas no alteran el catálogo.
- `HashiStoryPolicy`: continuación `classic-continuation-1`, perfiles por ordinal y semillas derivadas de SHA-256 de versión/ordinal/reintento. Rechaza IDs o pistas repetidas frente a los niveles retenidos. El paso de semillas no coincide con el stride interno del selector, evitando búsquedas consecutivas superpuestas.
- `HashiStoryState`: frontera monótona y ventana máxima de cuatro recetas, sin lista infinita de victorias. Cada etapa tiene cuatro niveles. El contador utiliza enteros seguros para JSON, con un límite práctico muy superior a una vida de juego.
- `HashiSession`: canal de Historia separado del procedural. Selección, instalación y victoria se publican después de guardar la sesión candidata; una escritura fallida mantiene la partida anterior y su desbloqueo.
- `HashiSaveStore`: formato v4 en la ruta histórica, lectura de v1/v2/v3/v4. Migra en memoria sin reescribir al abrir. La siguiente escritura válida incluye modo y progreso de Historia en el mismo archivo atómico. El tamaño sigue limitado a128KiB.
- `HashiStoryView`: mapa desplazable, bloqueos, mensajes de error y estado ocupado. Atrás permanece disponible para invalidar solicitudes pendientes. `main.gd` coordina señales e intenciones; el worker entrega solo recetas jugables.

Las reglas, el generador `h02b-1`, el solucionador y la identidad de recetas permanecen iguales. El esquema de política y los IDs introducidos no deben reinterpretarse cuando se añadan variantes.

## Verificación

Godot4.6.3 oficial. Suite completa anterior a la optimización de caché: **72.813 comprobaciones sin fallos**, más reaperturas clásicas/procedurales. Incluye185 pruebas de Historia,160 del recorrido de18niveles escrito y ejecutado por Minerva, y25 sobre errores visibles, fallos reales de escritura y resultados obsoletos. El recorrido verifica además repetición, frontera12, ventana4 y conservación exacta de una serie fija parcialmente jugada. CI repite la suite sobre el SHA publicado, incluida la caché final.

La revisión completa detectó y corrigió la anchura mínima de la cabecera al añadir los niveles al selector. Se actualizaron las comprobaciones históricas del tamaño de catálogo y del índice fuera de rango para incluir los doce niveles nuevos, conservando su propósito. Las comprobaciones del esquema usan la versión vigente y las fixtures antiguas mantienen sus campos originales.

`tools/story_walkthrough.gd` ejecuta un recorrido con render real X11/OpenGL llvmpipe a360x640 y480x800: mapa, bloqueos, selección por eventos de ratón, victoria, entrada en ruta continua y regreso al menú. Cero fallos; capturas en `docs/review/story/`. La selección desplegable Android y la instalación/tacto físicos no se acreditan con este recorrido.

## Candidata

Versión0.4.0/código4, paquete `org.hashi.prototype`. Workflow aislado `story-apk.yml`, permisos mínimos contents/actions read, gate explícito `[apk]` y verificación de certificado actual/histórico. Ningún cambio de secretos ni claves. La APK se prepara tras cerrar revisión de fuente/CI/capturas; los enlaces y SHA finales se registran en el PR y la incidencia#11. No se fusiona ni se publica en tiendas en este encargo.

La sesión implementadora de Igor se interrumpió por límite de uso después del primer bloque probado. Minerva retomó la revisión y el cierre, corrigió la cabecera y la caché de catálogo, añadió los recorridos de frontera/errores y preparó la entrega. No se presenta este cierre como una segunda revisión independiente de esos ajustes propios.

## Cierre de fuente

Fuente `9db6a95d36be6015007a35981e30a6d08d952233`: CI run41750140172/job126312907733 confirma72.813 comprobaciones sin fallos y reaperturas PASS, incluida la caché final. Minerva inspeccionó las capturas renderizadas y publicó el cierre técnico en PR#12, indicando los ajustes propios y la falta de una segunda revisión independiente de ellos. El commit de candidata solo añade este registro, sin alterar código de juego ni workflows.
