# Hashi — H02-A

Prototipo jugable en **Godot 4.x** (probado con 4.6.3), GDScript y renderizador Compatibility. Orientado a pantallas verticales Android; incluye presets Android y Web. Sin dependencias externas ni credenciales para jugar.

## Abrir y jugar

1. Instala Godot 4.x estándar (no necesita .NET).
2. Importa `project.godot` desde el gestor de proyectos y pulsa **F6/F5** para ejecutar la escena/proyecto. La escena principal es `scenes/main.tscn`.
3. Selecciona uno de los tres tableros. Toca una isla y luego otra, o arrastra desde una isla hasta la otra. Con ratón funcionan clics y arrastre.
4. Cada gesto alterna **0 → 1 → 2 → 0** puentes. Los puentes deben unir vecinos horizontales/verticales y nunca cruzarse ni atravesar islas.
5. Completa el número de cada isla y conecta toda la red para obtener la victoria. **Reiniciar** borra los puentes del tablero actual y se puede deshacer. Cambiar de tablero conserva los puentes de cada nivel.

Las advertencias empiezan desactivadas. Al activarlas, las islas con exceso de puentes se marcan en rojo y aparece un mensaje. Los excesos numéricos se permiten durante la exploración, pero impiden ganar; las conexiones geométricamente imposibles siempre se rechazan. Verde indica que una isla tiene su grado completo, no que toda la solución sea correcta.

En Linux restringido, usa `./tools/dev.sh` para jugar o `./tools/dev.sh --editor` para abrir el editor. El script guarda cachés y configuración en `.local/`, ignorado por Git. Para importar sin pantalla: `./tools/dev.sh --headless --editor --import --quit`.

## Arquitectura y datos

- `scripts/hashi_puzzle.gd` — `HashiPuzzle`: estado independiente de nodos, islas con ID estable, coordenadas, objetivo y metadatos `variant`/`color`; puentes identificados por un par canónico de IDs.
- `scripts/hashi_rules.gd` — `HashiRules`: vecindad, geometría, ciclo de puentes, grados y victoria con conectividad. No depende de la interfaz.
- `scripts/hashi_board.gd` — `HashiBoard`: dibujo adaptable, selección y eventos de ratón/táctiles; delega las reglas.
- `scripts/main.gd` — controles de partida, selector y mensajes.
- `data/puzzles.json` — Inicio (4 islas), Conexiones (9), Cruces (12). Complejidad creciente por tamaño y conexiones candidatas; no se afirma una clasificación de dificultad lógica.

El historial, la secuencia y el guardado están separados en `HashiHistory`, `HashiSequence`, `HashiSession` y `HashiSaveStore`. El guardado automático conserva el tablero actual, los puentes de los tableros visitados y los niveles completados en `user://hashi-save-v1.json`. Los metadatos de variantes y los IDs dejan puntos de extensión para colores, generación y un solucionador. **Esos tres sistemas y las futuras modalidades aún no están implementados**. El enumerador exhaustivo existe exclusivamente en pruebas para comprobar unicidad, no forma parte del juego.

## Pruebas

```bash
./tests/run.sh
```

Requiere `godot` en PATH. Usa un directorio de usuario temporal aislado para no alterar partidas reales. Importa el proyecto y ejecuta las 60 comprobaciones originales de `tests/run.gd`, la suite `tests/continuity.gd` y dos procesos de `tests/relaunch.gd` sin pantalla; devuelve código distinto de cero si falla una comprobación. Comprueba las reglas sin interfaz, enumera hasta dos soluciones por tablero y exige exactamente una, y prueba eventos táctiles sintéticos, selección de tablero, reinicio, victoria y disposición a 360×640, 480×800 y 720×1280. Los controles del modelo y la enumeración no necesitan una escena.

Consulta [H02-A: continuidad y validación](docs/H02A_CONTINUITY.md) para las funciones nuevas, el formato de guardado y las pruebas, y `docs/VALIDATION.md` para la validación histórica de H01. Los eventos sintéticos y las medidas de layout no sustituyen la inspección visual ni una prueba en Android.

## Exportar

Instala las **plantillas de exportación de la misma versión exacta de Godot** desde Editor → Administrar plantillas de exportación. Los presets se encuentran en Proyecto → Exportar.

- **Android:** configura JDK 17 y Android SDK según la documentación oficial de tu versión de Godot, las rutas en ajustes del editor y una clave de depuración para exportaciones de prueba. El preset usa ARM64 y orientación vertical; no requiere Internet. Configura firma propia para distribución y no subas claves al repositorio. Prueba gestos, recortes/safe areas y legibilidad en un dispositivo real antes de publicar.
- **Web:** preset Compatibility sin hilos; incluye explícitamente `data/*.json`. Crea `build/web` y ejecuta `./tools/dev.sh --headless --export-debug Web build/web/index.html`. Sirve los archivos mediante HTTP(S), no mediante `file://`.

En H01 la exportación quedó como configuración inicial. Para el estado de compilación APK de H01-B consulta [la guía Android Debug](docs/ANDROID_DEBUG.md). La ejecución en un dispositivo Android y la exportación/navegador web siguen sin validar. No se necesitan esos SDK para desarrollar y probar las reglas en escritorio.

## APK debug automático (H01-B)

Consulta [la guía Android Debug](docs/ANDROID_DEBUG.md) para ejecutar el workflow manual, descargar el APK desde un teléfono y conocer los bloqueos de habilitación de GitHub Actions. El workflow usa Godot 4.6.3, ARM64 y firma efímera de depuración; no publica una versión comercial.

## Continuidad (H02-A)

**Deshacer** y **Rehacer** recorren cambios de puentes y reinicios. Un cambio nuevo descarta el futuro de rehacer; los gestos rechazados no lo descartan. Al resolver aparece **Siguiente** habilitado. Tras el tercer tablero, **Volver al primero** cierra la secuencia provisional conservando las partidas. La marca ✓ indica que un tablero se completó alguna vez. No es un sistema de progresión definitivo.

El autoguardado ocurre tras cada cambio y reintenta una escritura fallida al pausar/cerrar. Al volver se recupera la partida; el historial de deshacer se reinicia al cambiar de tablero o relanzar. Véase [la guía H02-A](docs/H02A_CONTINUITY.md) para probarlo en Android.
