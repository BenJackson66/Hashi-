# Dirección interna — coordinación #8

Decisiones propuestas por Igor para revisión de Minerva. Solo se implementa ahora la entrega agrupada de navegación y partida libre. Este documento no afirma que existan los modos siguientes.

## Orden y contratos posteriores

1. Consolidar 0.2.0 con revisión independiente y la evidencia Android disponible. Los perfiles Directo/Reflexivo son contratos de técnicas suficientes, no categorías humanas calibradas.
2. **Dificultad fija:** una sesión conserva el perfil elegido y solo acepta tableros completamente clasificados de ese perfil, con presupuesto explícito y fallo recuperable; no subirlo por tamaño/CPU. **Progresión automática:** avanzar por hitos observables de partidas completas sin ayuda, con un cambio de repertorio explícito, reversible y sin saltos impuestos por tiempos del ordenador. Separar preferencias de próxima partida de las reglas de sesión.
3. **Historia:** secuencia de niveles reproducibles con IDs estables, solución única y desbloqueo por victoria conectada. No requiere una trama. Rejugar no borra hitos; partidas de Historia, libre y aprendizaje conservan estado separado. La elección de niveles y los desbloqueos se probarán con fixtures y reapertura, con migración versionada cuando corresponda.
4. **Alma de Hierro**, modo opcional: antes de activarlo, explicar la evaluación y el efecto de los errores. La partida normal sigue disponible.

## Definición prevista de error en Alma de Hierro

Para evitar castigar pulsaciones ambiguas, en ese modo una colocación requiere confirmación explícita. Un error es **confirmar un incremento de puentes que supera el número asignado a esa conexión por la solución única**. Se cuenta una vez por incremento confirmado, no por frame ni por cada propagación posterior. Ejemplos: añadir el primer puente en una conexión cuya solución es cero; añadir un segundo donde la solución exige uno. No se considera error una conexión que todavía está incompleta o una red parcial desconectada.

No cuentan como error: navegación, tap sin pareja, gesto cancelado, arrastre sin destino, conexión geométricamente rechazada, eliminación de puentes, reinicio ni fallo de generación/guardado. Deshacer revierte puentes, pero no borra un error ya confirmado. El mensaje previo al modo debe explicar esta diferencia respecto a la partida normal; no inferir intención de una pulsación.

El ledger de errores y racha se publicará solo después del guardado transaccional de la jugada. Un fallo de escritura conserva la jugada/racha previas y permite reintentar sin penalizar de nuevo. Una solución única puede verificarse transitoriamente en lógica, sin guardarla como testigo ni mostrarla en el estado jugable. Debe probarse el tratamiento de cierres, reintentos y movimientos repetidos antes de habilitar el modo.

Racha propuesta: partidas de Alma completadas sin errores, consecutivas dentro del modo; azul a las 3, morado a las 7, dorado a las 15. Un error confirmado rompe la racha actual; no borra el mejor hito. Salir al menú o pausar no la rompe. Abandonar explícitamente una partida iniciada sí la rompe, previa advertencia. Cambios de modo no convierten retrospectivamente partidas libres en victorias de Alma. Estos umbrales son decisiones de producto iniciales, no resultados del estudio H03-A, y requieren revisión antes de implementación.

## Acabado y validación del equipo

Revisar áreas seguras Android, lectores de pantalla, contraste y escalado de texto; vibración opcional con preferencia, sin castigar gestos; eficiencia de generación y cancelación. La validación de compatibilidad, firma, unicidad y recuperación pertenece al equipo. A Jack solo se le pide jugar y comentar sensaciones en entregas con cambios importantes.
