# H07 — Alma de Hierro y rachas, candidata 0.6.0

## Resultado para jugar

Alma de Hierro está disponible en Inicio con el perfil Directo o Reflexivo elegido. Cada tablero perfecto suma al desafío y a su récord persistente. La primera falta termina el desafío; desde Inicio puede comenzarse otro. Historia y las series normales siguen disponibles y conservan sus avances aunque se corte la racha.

La racha global colorea los puentes en todos los modos: azul desde 1 tablero perfecto, morado desde 3 y dorado desde 7. El primer umbral procede del acuerdo con Jack; 3/7 son decisiones provisionales de esta implementación. El nombre del color y el contador acompañan al color. Cada tablero retenido acredita una sola vez. Repetirlo o guardar de nuevo no produce crédito adicional.

Una falta es deshacer una acción real, retirar/reducir puentes o dejar una posición sin extensión posible añadiendo puentes. El primero de dos puentes correctos es válido. Los gestos rechazados y deshacer sin historial no son faltas. Las advertencias visuales continúan siendo opcionales y no cambian estas reglas.

## Modelo y conservación

`HashiExtensionJudge` comprueba dominios con límites inferiores dados por los puentes colocados, capacidades de azules, pistas visibles, cruces y conectividad. Devuelve viable/impossible/indeterminate/invalid, sin exponer soluciones. Los motores clásicos y de variantes existentes permanecen intactos.

`HashiQuality` conserva racha, máximo, récord de Alma y marcas acotadas a los tableros retenidos. El primer juicio de cada gesto tiene un límite de 5 ms/1.000 nodos. Un resultado indeterminado conserva el prefijo pendiente en el guardado y continúa en un worker (1 s, después 5 s, con límite de nodos). Mientras tanto la interfaz responde y muestra el estado; ninguna falta se deduce de un límite de cálculo. Si permanece pendiente ofrece Reintentar comprobación.

La sesión guarda puentes, acciones pendientes, faltas, victoria y créditos en una sola transacción. No concede victoria antes de resolver los prefijos pendientes ni tras terminar Alma. La cola de acciones sobrevive a un fallo de escritura y no pierde un deshacer aunque el estado final coincida con el anterior. Un fallo ofrece Reintentar guardado y conserva el último archivo válido. Alma solo termina por faltas en su tablero procedural activo; jugar Historia con el desafío pausado no lo termina.

El formato v6 lee v1–v5 sin reescribir al abrir. Las partidas históricas conservan selección, recetas, puentes, desbloqueos y series; no reciben perfectos retroactivos. Las marcas se podan al sustituir procedurales o niveles continuos. Los prefijos guardados contienen solo puentes colocados por el jugador, nunca soluciones del solver.

## Validación y autoría

Igor implementó el adjudicador, el modelo, la transacción, la interfaz y las pruebas de Alma. Minerva revisó el código y produjo dos pruebas independientes: `monotone_oracle.gd` (7.702 posiciones parciales; 15.405 comprobaciones, 0 fallos) y `quality_review.gd` (77 comprobaciones, 0 fallos). La primera enumera grafos y extensiones sin usar la geometría ni las reglas productivas. La segunda prueba archivos v5 reales, reapertura exacta, fallos reales de escritura, prefijos deshacer/rehacer, resultados pendientes, récord y separación de modos.

La revisión detectó y se corrigió la concesión prematura de una victoria de Alma tras una falta. Al interrumpirse Igor por un límite de uso, Minerva completó el cierre: esperas de adjudicación en los recorridos UI heredados, concordancia del botón Reiniciar con el bloqueo de escritura, documentación y publicación. Añadió un atajo exacto para posiciones ya resueltas: la red visible completa demuestra su propia extensión sin volver a buscar; los prefijos anteriores pendientes siguen bloqueando el crédito. Esos cambios de cierre no se atribuyen a una revisión por otro agente.

Recorrido renderizado real con Xvfb/llvmpipe en 360×640 y 480×800: Inicio, Alma activa, perfecto azul, desafío terminado, comprobación indeterminada y guardado fallido con recuperación. Cero fallos; tablero de al menos 200 px y controles dentro del viewport. Evidencia en `docs/review/iron-streaks/`.

La suite completa, la CI del SHA publicado y el APK se registran en el PR y en #15. Los recuentos de recorridos UI varían por el número de puentes de tableros aleatorios; no representan nuevas muestras estadísticas independientes. No se afirma revisión táctil o instalación física Android: este entorno no dispone de dispositivo/emulador. No se fusionaron PRs ni se publicó en tiendas.

## Identidad Android

Versión 0.6.0, versionCode 6, paquete `org.hashi.prototype`. Se conserva la identidad de firma persistente y se compara con el APK H02-C cuando el artefacto histórico está disponible. CI sin credenciales de firma para los pushes ordinarios; build agrupado solo tras revisión mediante el gate `[apk]`.
