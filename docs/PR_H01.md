# H01: prototipo jugable de Hashi en Godot 4

## Resultado

Añade un proyecto Godot 4 con modelo `HashiPuzzle`, reglas independientes `HashiRules` y representación/interacción `HashiBoard`. Permite crear, duplicar y quitar puentes mediante dos toques o deslizamiento, reiniciar, elegir entre tres tableros y activar advertencias opcionales. La victoria requiere grados exactos, geometría válida y una única red conectada.

Incluye tres tableros de 4, 9 y 12 islas con solución única verificada exhaustivamente. Los datos contienen IDs y metadatos para extensiones futuras; no incorpora generador, solucionador de juego, variantes por color ni autoguardado.

## Validación

- Godot 4.6.3: `./tests/run.sh` — 60 comprobaciones, 0 fallos.
- Unicidad de los tres tableros, reglas independientes de UI e interacción táctil sintética hasta completar una partida.
- Layout medido en 360×640, 480×800 y 720×1280; arranque headless de la escena principal.
- Documentación de apertura, pruebas, arquitectura y exportaciones; presets Android/Web.

## Limitaciones

No hay inspección visual con pantalla, prueba Android real ni exportación web validada. Falta Android SDK/build-tools y deben instalarse las plantillas de exportación. Ver `docs/VALIDATION.md`.

El repositorio estaba vacío: `main` se inicializó con un commit vacío para establecer la base del PR. No fusionar sin autorización.
