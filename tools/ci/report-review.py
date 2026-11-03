#!/usr/bin/env python3
"""Prepare public review JSON. Reads no signing secrets or private key material."""
import json
import os
import sys
from pathlib import Path

root = Path('build/android')
sha = os.environ['GITHUB_SHA']
repo = os.environ['GITHUB_REPOSITORY']
run = f"https://github.com/{repo}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
artifact = os.environ.get('APK_ARTIFACT_URL', '') or run
if '--failure' in sys.argv:
    root.mkdir(parents=True, exist_ok=True)
    failure = f"Minerva: la entrega agrupada del PR #7 encontró un fallo en [Actions]({run}), SHA `{sha}`. No se entrega una APK verificada disponible. La ejecución enlazada identifica el paso fallido; no se han fusionado cambios ni sustituido claves. Se requiere revisar ese fallo antes de dar la entrega por compilada."
    (root / 'review-comment.json').write_text(json.dumps({'body': failure}))
    raise SystemExit(0)
fingerprint = (root / 'signing-certificate-sha256.txt').read_text().strip()
assert len(fingerprint) == 64 and all(c in '0123456789abcdefABCDEF' for c in fingerprint)
historical = (root / 'historical-identity.txt').read_text().strip()
checksums = (root / 'SHA256SUMS.txt').read_text().strip()
report = f"""## Entrega agrupada para revisión de Minerva — Hashi 0.2.0

Minerva: se solicita revisión independiente del [PR #7](https://github.com/{repo}/pull/7), ampliado con navegación y partida libre variada. No se ha fusionado ni publicado en tiendas.

- SHA exacto: `{sha}`.
- [Workflow Android Debug APK]({run}); [artefacto APK ARM64]({artifact}).
- Artefacto: `hashi-h01-debug-arm64-{os.environ['GITHUB_RUN_NUMBER']}`; archivo `hashi-h01-debug-arm64.apk`.
- Paquete: `org.hashi.prototype`; versión `0.2.0`, `versionCode=2` (actualización de la versión anterior 1).
- Firma criptográfica y coincidencia con el keystore persistente: verificadas en CI, sin claves alternativas.
- Certificado público SHA-256: `{fingerprint}`.
- Comparación histórica: {historical}
- SHA-256 del APK: `{checksums}`.

### Informe funcional

Inicio, Continuar, aprendizaje y reglas forman parte de la misma experiencia. Partida libre ofrece Directo (deducción local) y Reflexivo (contradicciones sin hipótesis anidadas), como perfiles provisionales. Varía formas y conexiones, conserva el progreso y permite ir al siguiente procedural al resolver, sin pasar por aprendizaje.

### Informe técnico y pruebas

[Informe técnico y funcional por SHA](https://github.com/{repo}/blob/{sha}/docs/FREE_PLAY_DELIVERY.md).
El generador `h02b-1`, las reglas y el esquema v1/v2 permanecen intactos. El clasificador de ejecución coincide con H03-A en 1.000 tableros archivados. Suite existente, migración/reapertura, escrituras fallidas, unicidad, selección, límites y regresiones ejecutados por el equipo; CI repite la suite antes de exportar. Una muestra de 100 partidas seleccionadas cubre ambos perfiles y las tres configuraciones. Se incluyen capturas y recorrido reproducible con renderizado X11/OpenGL y eventos de ratón/touch.

Límites: validación visual de escritorio sobre llvmpipe; no equivale a un teléfono. No hay dispositivo ni emulador Android disponible en el entorno. La APK tiene verificación estática, no prueba de instalación/actualización ni de tacto Android. No se asigna QA técnico a Jack. Las etiquetas no son tres dificultades humanas acreditadas. La revisión independiente de Minerva y la validación Android del equipo quedan pendientes.

La API local del entorno está bloqueada por red; este informe lo publica el workflow mediante su token de repositorio limitado. No se han modificado secretos ni el certificado.
"""
(root / 'review-comment.json').write_text(json.dumps({'body': report}))
(root / 'review-pr.json').write_text(json.dumps({
    'title': 'Entrega jugable: Inicio, partida libre variada y desafíos provisionales',
    'body': report + '\n\nReferencias: contrato #8; incluye y completa H03-B1. Revisión solicitada, no fusionar automáticamente.\n'}))
(root / 'review-report.md').write_text(report)
