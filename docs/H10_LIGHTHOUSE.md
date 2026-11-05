# H10 — El faro · Hashi 0.9.0

## Resultado funcional

Historia tiene un paisaje original que recupera vida con cada nivel superado. Los doce niveles iniciales restauran cuatro lugares, con tres mejoras visibles por lugar:

| Niveles completados | Lugar | Cambios |
| --- | --- | --- |
| 1–3 | Desembarcadero | Pilares, cubierta y llegada de la barquita |
| 4–6 | Sendero | Camino, pasarela y flores |
| 7–9 | Casa del farero | Tejado, ventanas iluminadas y jardín |
| 10–12 | Faro | Torre, linterna y luz encendida |

No hay monedas ni una segunda tarea de construcción. Una victoria nueva de Historia, guardada y con la comprobación de calidad resuelta, abre una breve escena de restauración. Se puede seguir inmediatamente o volver al paisaje. La ruta y los niveles anteriores siguen accesibles. Al reabrir se ve el estado ya restaurado, sin repetir la celebración. El progreso anterior se reconoce automáticamente; no es necesario repetir niveles. Esta entrega incluye el primer paisaje; la continuación de Historia conserva su comportamiento.

## Arte y sonido

Ilustración vectorial original en trece capas: costa inicial y doce mejoras. Paleta de atardecer, verde salvia, madera y terracota; sin recursos externos ni arte temporal de otro juego. La barquita tiene un balanceo leve y el faro un pulso suave. Movimiento reducido deja el resultado estático sin impedir sonido ni progreso.

Nueve recursos de sonido originales, generados de forma determinista sin grabaciones ni muestras externas: puente, retirada, isla completa, victoria, restauración, activación de sonido, intento terminado y dos ambientes de mar/puerto. Máximo seis voces simultáneas, volumen moderado y ambiente más bajo. Silencio disponible en la ayuda y mediante un símbolo en la restauración; ambos controles se sincronizan y la preferencia persiste. Pausa o pérdida de foco detiene los sonidos; volver al juego solo reanuda el ambiente correspondiente, sin repetir efectos.

## Contrato técnico

- `HashiLandscapeProgress` deriva `clamp(story.frontier, 0, 12)`. No añade estado económico, migración del guardado ni una nueva fuente de verdad.
- El dominio, generadores, dificultad, identidad y reglas permanecen intactos. El formato de partida sigue en v7.
- Los efectos de jugada parten de cambios guardados. Jugadas rechazadas, escrituras fallidas y guardados pasivos no producen efectos nuevos; un reintento correcto los produce una sola vez.
- La restauración exige aumento real de frontera. Repetir, deshacer/rehacer o revisar un nivel completado no restaura otro elemento.
- La transición diferida tiene una época de navegación; seleccionar otro nivel la cancela. Una celebración no puede invalidar una generación nueva.
- Las preferencias cosméticas se escriben con archivo temporal y renombrado, sin reemplazar la partida. Cambiar sonido conserva movimiento y viceversa. Un fallo conserva el estado anterior y revierte ambos controles.
- Recursos vectoriales y PCM tienen generadores originales reproducibles en `tools/`; los generadores, pruebas, informes y capturas se excluyen del APK.

## Validación

La suite heredada completa conserva sus aserciones y terminó correctamente. Igor aportó `tests/lighthouse_review.gd`: 121 comprobaciones independientes correctas sobre progreso durable, errores y reintentos reales, preferencias, silencio, foco/pausa, navegación, reapertura, movimiento reducido, saturación y carrera hacia la continuación. El archivo se incorpora intacto al runner. Inspeccionó seis capturas concretas del recorrido, con revisión visual favorable; no se le atribuyen las otras veinticuatro. Los resultados CI finales se registran en PR e issue #21. Las 55 comprobaciones de audio verifican formato PCM mono de 24 kHz y 16 bits, duración, amplitud, RMS, componente continua y bordes del bucle sin clics.

Recorrido visual real con Godot 4.6.3, Xvfb y llvmpipe: treinta capturas a 360×640 y 480×800, con costa inicial, opciones de sonido, las doce victorias de Historia y paisaje final. Los tableros se resuelven con conexiones reales; no se sustituyen por una frontera inventada. Se comprueba que cada victoria durable abre su restauración y que los controles permanecen dentro de pantalla.

Algunas pruebas headless que reproducen sonidos y terminan inmediatamente muestran avisos de recursos de reproducción WAV al apagar el motor. Los resultados funcionales son correctos; el recorrido renderizado con cierre normal no presenta esos avisos. No se introduce espera artificial ni se desactiva el sonido en producto para ocultarlos.

No se afirma instalación, altavoz ni interacción física en Android. Se entregará un APK ARM64 con `org.hashi.prototype`, versionCode 9 y la firma persistente anterior, previa verificación criptográfica. Sin fusionar PRs ni publicar en tiendas. Jack solo juega; no se le delega comprobación técnica.

## Candidatura Android revisada

Fuente final: `c1a8c23459f521613d2d1d75741737c10d884525`. [CI fuente 41949409944](https://github.com/BenJackson66/Hashi-/actions/runs/41949409944) correcta: suite completa, 121 comprobaciones independientes y 55 comprobaciones de audio. La revisión visual del recorrido de treinta capturas resultó favorable. Este commit de candidatura solo modifica este informe; se compila un único candidato agrupado 0.9.0 / versionCode 9, manteniendo la identidad Android existente. Antes de entregarlo se verificarán firma, identidad histórica, hashes y recursos empaquetados.
