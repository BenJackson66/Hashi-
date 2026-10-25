# Validación H01

## Ejecutado en este entorno

- Godot **4.6.3.stable.official.7d41c59c4**, Linux x86_64.
- `./tests/run.sh`: **60 comprobaciones, 0 fallos**. Importación, reglas independientes de la interfaz y pruebas de integración sin pantalla.
- Unicidad exhaustiva en Godot: `h01_1`, `h01_2`, `h01_3` tienen **exactamente una solución** cada uno. El enumerador de pruebas recorre todas las asignaciones posibles 0/1/2 para los vecinos, poda por capacidad restante y cruces, y exige conectividad. Se detiene al detectar dos soluciones y se comprueba también con un tablero ambiguo y otro imposible.
- La selección inicial de los tableros se contrastó además con una enumeración independiente en Python durante el desarrollo.
- Reglas: ciclo y simetría, doble puente, límites, islas inexistentes, autoenlaces, diagonales, islas intermedias, cruces, eliminación, grados completos, exceso, red desconectada, definiciones inválidas y reinicio.
- Integración: advertencias desactivadas por defecto, mensajes de exceso, dos toques y deslizamiento sintéticos, resolución completa mediante gestos, victoria, reinicio y selector de tablero.
- Geometría del layout: tablero con espacio útil e islas dentro de sus límites a 360×640, 480×800 y 720×1280.
- `./tools/dev.sh --headless --quit-after 10`: arranque de la escena principal sin errores de ejecución.

## Límites

No hay `DISPLAY` ni servidor gráfico disponible. **No se inspeccionó visualmente la interfaz**. Las pruebas táctiles usan eventos sintéticos dentro de Godot, no un dispositivo físico ni la entrada del sistema operativo. Quedan por probar tamaños de fuente reales, zonas seguras, contraste y manejo táctil en hardware.

**Android no validado:** falta el SDK/build-tools y no se generó ni instaló un APK. Al importar, el preset Android puede mostrar `Unable to open Android 'build-tools' directory`; no afecta a las pruebas de escritorio.

**Web no validado:** no se ejecutó una exportación ni un navegador. Los presets son configuración inicial, no prueba de compatibilidad. Se requieren plantillas de la misma versión del motor.

No se implementan autoguardado, generador, solucionador de juego ni variantes por color. Cambiar de tablero descarta los puentes de la partida anterior. El modo vertical es el objetivo de esta entrega.
