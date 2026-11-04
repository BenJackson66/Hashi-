# H08 — Identidad artística, 0.7.0

## Resultado

Hashi adopta una identidad nocturna cálida: azul profundo, verde petróleo, marfil y dorado. Marca vectorial de islas y puentes, fondo de trazos discretos, titulares serif y texto de interfaz sans. Menús, mapa, selectores, estados deshabilitados y foco comparten el mismo sistema visual. Inicio destaca Historia si aún no hay partida y Continuar cuando ya existe.

Las islas tienen volumen y sombra suaves, números más definidos y superficie marfil. Las resueltas, azules y misteriosas conservan su distinción funcional. S y ? permanecen visibles; las advertencias mantienen el rojo y las rachas mantienen azul/morado/dorado. Los puentes tienen sombra leve y separación doble proporcionada al tamaño de las islas.

Cada cambio inicia una interpolación de dibujo de 160 ms y una resolución produce un realce de borde de 700 ms. La actualización del puzle, adjudicación y guardado siguen siendo inmediatos; la animación nunca emite movimientos ni modifica créditos. Al cambiar/restaurar tablero se cancela la animación anterior. La opción Animaciones suaves se guarda por separado en `.appearance`, sin alterar el snapshot v6. Si no puede escribirse se conserva la preferencia anterior.

## Alcance técnico

Solo presentación y observación de cambios de Board. No se modifican Rules, Solver, Generator, variantes, Session, Store, políticas, catálogo, rachas ni dificultades. Los puentes siguen respondiendo a los gestos originales. Se mejora el espacio de dibujo y se conserva la detección del centro de cada isla.

`HashiArt` concentra recursos/paleta/tema; `HashiBackdrop` es decorativo e ignora entrada; `HashiArtPreferences` mantiene la preferencia cosmética. Fuentes DejaVu incluidas y subconjuntadas para español, símbolos y flechas, con su licencia en `assets/fonts/LICENSE.txt`, incluida también en exportación. Marca SVG original del proyecto. Sin recursos de pago ni dependencias de red durante el juego.

## Verificación

`tests/art_presentation.gd`: 22 comprobaciones, 0 fallos. Movimientos reales con animación, estado y guardado invariantes durante los frames, ausencia de eventos adicionales, rechazo de diagonales, movimiento desactivado, reapertura de preferencia, restauración sin animación, ciclo azul y centros táctiles.

Recorridos renderizados reales Xvfb/llvmpipe: 18 capturas de Inicio, Alma activa/resuelta/terminada, las tres recompensas de color, comprobación pendiente y guardado fallido con recuperación en 360×640 y 480×800. Seis capturas adicionales en 360×640 de azules/misteriosas/combinadas y su mapa, recorriendo 21 niveles reales. Total24 capturas, cero fallos de layout: tablero≥200px y controles dentro del viewport. Los colores3/7 en el recorrido de arte son fixtures visuales; la acreditación real permanece cubierta por las pruebas de Alma heredadas. Evidencia: `docs/review/art/`.

La suite completa y CI del SHA publicado se registran en el PR. Se conservan todos los tests anteriores. El formato de guardado continúa en v6. El cambio es de Minerva y fue comprobado con tests y revisión visual propia; no se atribuye revisión independiente a Igor, interrumpido por límite de uso.

## Entrega Android

0.7.0/versionCode7, ARM64, paquete `org.hashi.prototype` y certificado histórico. Workflow de tests sin secretos y build agrupado tras revisión mediante `[apk]`. La instalación e interacción Android física no se afirman: el entorno carece de teléfono/emulador. PR sin fusionar y sin tiendas. Contrato #17.

## Candidata agrupada

Fuente `09ae8b7689514a0a548ba2b6d88ba1f11f156764`, suite local completa y [CI41794193165](https://github.com/BenJackson66/Hashi-/actions/runs/41794193165) correctas. Este cambio solo documental habilita la compilación agrupada `[apk]`, sin modificar juego ni workflows. PR#18, abierto sin fusionar.
