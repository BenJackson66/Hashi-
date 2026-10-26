# H03-B1 — Inicio y navegación

Base: `main` en `01c5844`. Motor de validación: Godot 4.6.3 estable oficial. PR independiente; sin compilación APK ni fusión.

## Comportamiento

La creación de la escena principal siempre muestra Inicio. Se recupera la sesión en memoria sin escribir el archivo ni mostrar automáticamente la partida. Esto incluye partidas anteriores v1 y v2; no se modifica la ruta `user://hashi-save-v1.json`, el esquema ni `HashiSaveStore`.

- **Continuar partida** está deshabilitado si no se pudo recuperar una partida y todavía no se inició una. Abre el último tablero seleccionado y sus puentes. Un guardado inválido produce un aviso y permanece intacto al consultar reglas, navegar o pausar.
- **Nuevo tablero** solicita un procedural 5×5/10 a la infraestructura asíncrona existente. Inicio muestra el estado de generación; un resultado válido se guarda antes de publicarse y abrir Partida.
- **Aprender a jugar** permite elegir cualquiera de los tres tableros originales. Son tableros de práctica, sin tutorial guiado ni dificultad asignada. La selección se guarda antes de cambiar el tablero visible.
- **Cómo jugar** muestra reglas breves en español, un ejemplo de una isla 3 y los controles. Su contenido se desplaza verticalmente si no cabe; tiene botón para volver a Inicio.
- **Inicio**, en la cabecera de Partida, oculta la vista de juego y vuelve al menú sin guardar de nuevo ni reconstruir el tablero. **Continuar** conserva el mismo objeto y las pilas Deshacer/Rehacer. Cambiar de tablero o relanzar sigue reiniciando el historial como antes, conservando los puentes.

La navegación existente entre tableros prediseñados se mantiene. En un procedural resuelto, el control que vuelve al primer prediseñado ahora dice **Volver al primero**, para distinguirlo del nuevo **Inicio** que abre el menú; su acción no cambia.

## Protección de progreso

Se conserva el único slot procedural de H02-C y los estados independientes de los tres prediseñados. Antes de generar un sustituto se consulta el procedural almacenado, aunque la selección actual sea un prediseñado. Si tiene puentes y no satisface las reglas de victoria, se muestra una confirmación con **Conservar partida** y **Sustituir y generar**. La comprobación usa el estado actual, no la marca histórica de completado: deshacer tras una victoria vuelve a proteger un tablero sin resolver.

Cancelar devuelve a la pantalla de origen sin cambiar selección, pistas, puentes, historial o archivo. No se inicia un worker antes de confirmar. Un procedural vacío o actualmente resuelto no requiere advertencia.

Confirmar inicia una sola tarea. La sustitución sigue usando `HashiSession.install_procedural_and_save()`: copia temporal, validación, escritura atómica y publicación solo después del éxito. Ante fallo se conserva la partida completa, se muestra un aviso y se permite reintentar. Un intento rechazado no queda pendiente de publicación al pausar.

Se añade `HashiSession.select_and_save()` con el mismo principio para cambiar de tablero: conserva el modelo y el historial visible si falla la escritura de la selección. No modifica el formato ni obliga a migrar v1 al abrir Inicio o Continuar; elegir un tablero distinto realiza el guardado v2 habitual.

No hay una modificación incompatible que requiera migración nueva. La generación, el analizador experimental, las reglas, las pistas y la firma Android permanecen intactos.

## Separación de responsabilidades

- `scripts/hashi_home.gd`: componente visual independiente de menú, aprendizaje, reglas y confirmación. Emite señales de intención; no accede a archivos, recetas, reglas ni tareas.
- `scripts/main.gd`: coordina la sesión y dos vistas conservadas en memoria. Controla disponibilidad de Continuar, confirmación, mensajes y transiciones.
- `scripts/hashi_session.gd`: selección y sustitución transaccionales. Continúa separada del dibujo y las señales de la UI.
- `HashiGenerationTask`: se reutiliza sin cambios; el worker trabaja con copias y entrega resultados al hilo principal. No se añade generación al componente visual.

Las acciones de generación y confirmación tienen guardas explícitas contra duplicados. Cambiar de página del menú, volver a Inicio, continuar, elegir otro tablero o jugar invalida la época del resultado pendiente. El worker acotado termina, pero su resultado obsoleto no escribe ni abre otro tablero. Mientras termina, Nuevo tablero permanece deshabilitado. Al ocultar la partida se cancela el gesto incompleto, sin modificar puentes.

## Validación automatizada

Ejecutar desde la raíz:

```sh
./tests/run.sh
```

Requiere Godot 4.6.3 y `timeout`. El harness usa datos/configuración temporales aislados: no toca partidas reales. Resultado:

| Suite | Comprobaciones | Resultado |
|---|---:|---|
| H01 | 60 | Sin fallos |
| Continuidad H02-A | 121 | Sin fallos |
| Generación H02-B | 615 | Sin fallos |
| Identidad procedural | 57 | Sin fallos |
| Integración H02-C | 112 | Sin fallos |
| Inicio y navegación H03-B1 | 88 | Sin fallos |
| Seguridad de firma | 15 | Sin fallos |
| Reapertura clásica, dos procesos | Escritura y lectura | PASS |
| Reapertura procedural, dos procesos | Escritura y lectura | PASS |

Los tests existentes se conservan. La aserción del nombre del botón de retorno procedural se adapta a su texto explícito; la reapertura procedural usa ahora Nuevo tablero de Inicio y Continuar, comprobando que ambos procesos arrancan en el menú.

`tests/home_navigation.gd` comprueba instalación nueva, compatibilidad v1/v2 sin reescritura inicial, Continuar con puentes, ida/vuelta al menú con Deshacer/Rehacer, elección de los tres prediseñados, independencia del procedural, confirmación/cancelación desde partida y menú, procedural vacío/resuelto, deshacer tras victoria, escritura fallida real en `.tmp`, selección transaccional fallida, generación sin intentos, recuperación del archivo anterior, pulsaciones repetidas, resultados obsoletos y gestos incompletos.

Las dimensiones de layout se comprueban a 360×640, 480×800 y 720×1280: botones de Inicio de al menos 56 unidades, cabecera y acciones dentro de la pantalla y tablero de al menos 200×200. Los controles de juego mantienen al menos 48 unidades. Esto valida geometría calculada y señales, no renderizado ni interacción física.

## Validación manual pendiente y límites

No se genera APK en esta misión. Tras revisión y autorización, compilar mediante el flujo Android existente conservando paquete y certificado; actualizar la instalación existente sin desinstalar ni borrar datos. Probar en un teléfono:

1. Abrir una instalación nueva: Inicio, Continuar deshabilitado, reglas desplazables y selección de los tres prediseñados.
2. Actualizar con partida H02-C existente: abrir Inicio, pulsar Continuar y comprobar selección y puentes anteriores.
3. Jugar, Deshacer, volver a Inicio, consultar reglas y Continuar; comprobar Rehacer y que no se añade un puente por un gesto interrumpido.
4. Alternar los tres prediseñados y el procedural; cerrar y relanzar, comprobando el último seleccionado.
5. Iniciar otro procedural desde Inicio y Partida, cancelar y confirmar; comprobar la advertencia incluso al estar jugando un prediseñado. Repetir tras deshacer una victoria.
6. Pulsar varias veces mientras se genera y navegar a otra pantalla; comprobar que un resultado antiguo no la sustituye. Revisar tamaños táctiles, scroll, contraste, márgenes del sistema y espacio de juego en el dispositivo.

El guardado sigue reteniendo un solo procedural reciente, sustituido solo tras confirmación cuando corresponde y guardado exitoso. No se añade biblioteca de procedurales ni historial persistido. El cierre forzado del proceso durante una generación no publica resultados; se recupera el último guardado completado. Un fallo de autoguardado de un movimiento ordinario sigue mostrando aviso y reintentándose al pausar, como en H02-C: ningún almacenamiento puede garantizar persistencia de una escritura que el sistema rechaza.

Sin inspección visual, prueba táctil real o validación Android en este entorno. No se modifica el workflow para habilitar esta rama ni se ejecuta una compilación; ese paso queda para la autorización posterior. No se inicia H03-B2.
