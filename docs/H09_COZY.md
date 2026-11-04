# H09 — Interfaz cozy, tacto y correcciones de Historia

## Resultado para jugar

Inicio contiene Historia y Modos, más un símbolo de continuar cuando existe una partida. Modos ofrece Libre, Dificultad fija, Progresión y Alma, con Directo/Reflexivo sin explicaciones intercaladas. La ayuda opcional se abre mediante tres líneas dentro de la partida y explica el modo actual, reglas, controles y ajustes. La paleta es crema/salvia y los controles son símbolos SVG con nombres accesibles y tooltips.

El encabezado de Historia centra el identificador1-2/1-3. Aprender usa su propio número; las series mantienen su ordinal. La llama muestra el contador de racha, el corazón las correcciones y la corona el récord de Alma. El tablero gana espacio al ocultar párrafos de estado e instrucciones; los mensajes de final de intento son breves. Mapa con códigos de nivel y bloqueos gráficos. Las explicaciones técnicas de conservación/caché no aparecen en el juego.

## Correcciones e intentos

Historia dispone de3correcciones por intento. Deshacer real consume una, incluso si repone puentes; toda retirada/reducción por ciclo o corte consume una. Rehacer que solo añade no consume. Un trazo puede retirar varios puentes y consume una sola corrección. Un no-op, rechazo, cancelación o trazo sin corte no consume.

Al llegar a0 termina y se bloquea el intento si ese gesto no ha resuelto la red. La tercera corrección ganadora puede ganar. La derrota se mantiene aunque un sufijo de acciones posterior deje una red resuelta; nunca acredita una victoria tardía. En0, tanto ganadores como perdedores quedan inmutables, con Siguiente o Repetir según corresponda.

Repetir restaura3correcciones y el tablero vacío en una única escritura, sin borrar niveles superados ni récords. El historial visual se limpia tras confirmar la transacción. El crédito previo de racha se conserva y un reinicio con cambios corta la racha; no permite farmear perfectos. Reiniciar vacío/con3/no perdido es un no-op y no corta racha. Estas reglas mantienen la política previa de rachas y Alma.

## Gestos y tacto

Área de isla: max(radio+14,34) píxeles lógicos, con selección por el centro más cercano cuando se solapan. Un toque breve conserva su isla inicial para que el temblor no cree una conexión al cruzar la frontera de dos áreas. El corte observa toda la trayectoria y un salto rápido puede cruzar varios puentes. Requiere excursión de18px para ignorar temblor pequeño, protege extremos y rechaza tangencia/colinealidad como cortes. Los puentes dobles se retiran completos.

Una conexión clara entre islas tiene prioridad; un rechazo de esa rama nunca cae al borrado. En zonas densas, un corredor lateral distingue un corte por el hueco entre columnas de una conexión paralela. Un segundo dedo no confirma el gesto activo. Cancelar, cambiar tablero/pantalla, abrir ayuda o perder foco limpia toda la trayectoria y sus candidatos. La previsualización no cambia datos; cada corte confirmado produce un solo evento e historial.

## Datos y transacciones

`HashiStoryAttempts` separa el presupuesto de correcciones de la adjudicación de rachas. Session guarda puentes, crédito, presupuesto y derrota conjuntamente; valida la cadena before/after y rechaza acciones ya aplicadas. Un fallo real de escritura no publica nada; el reintento aplica la corrección una vez. La adjudicación indeterminada nunca se trata como derrota por tiempo.

Snapshotv7 lee v1–v6 sin reescribir al abrir. Un guardado anterior inicia presupuestos de3sin sanciones retroactivas. El presupuesto se poda con los niveles continuos retenidos. No se modificaron motores clásicos/variantes, generador, identidad de puzles ni catálogo. Se mantienen paquete y certificado Android; versión0.8.0/code8.

## Verificación y autoría

Minerva implementó; Igor revisó independientemente sin editar producto. Pruebas incorporadas intactas:

- `cozy_domain_review.gd`:73comprobaciones de atomicidad, terceros gastos, latcheado, reapertura, v6sinreescritura, replay, no-op, validación y reinicio sin perder progreso/duplicar créditos.
- `cozy_touch_review.gd`:20comprobaciones de eventos táctiles y ratón, cortes dobles/múltiples, campo denso, prioridad, cancelación, segundo dedo, jitter y lazo amplio.
- `cozy_ui_review.gd`:52comprobaciones integradas en360×640 y480×800: cabecera, ayuda, Android Back simulado, corte real y guardado fallido/reintento/cancelación/derrota/reinicio.

Total independiente145,0fallos. La suite heredada conserva sus aserciones funcionales; se adaptan fixtures antiguos para omitir el nuevo campo, texto de botones a sus nombres accesibles y geometría a las páginas donde ahora viven las acciones. Los iconos tienen mínimo48px (implementados52); las tarjetas64px. Android Back desde reglas vuelve a Modos.

Recorrido real Xvfb/llvmpipe:28capturas de Inicio, Modos, mapa, juego, ayuda, corte, derrota, reinicio, victoria,1-2, continuar y otros modos a360×640 y480×800;0fallos de geometría. Tablero≥300px, nivel centrado y controles dentro de viewport. Igor inspeccionó visualmente7capturas concretas y emitió dictamen favorable; no se le atribuyen las otras21.

Suite completa y CI se registran en PR/issue#19. No se afirma instalación/interacción física en Android: la revisión de tacto usa eventos reales de Godot y no un teléfono/emulador. Sin fusionar PRs ni publicar en tiendas.
