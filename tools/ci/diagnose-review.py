#!/usr/bin/env python3
"""Publish failed step names and filtered diagnostics; never environment dumps."""
import json
import os
import re
import subprocess
from pathlib import Path
repo = os.environ['GITHUB_REPOSITORY']
run = '41686653836'
jobs = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repo}/actions/runs/{run}/jobs'], text=True))
failed = [f"{job['name']} / {step['name']}: {step['conclusion']}" for job in jobs['jobs']
          for step in job['steps'] if step.get('conclusion') == 'failure']
logs = subprocess.run(['gh', 'run', 'view', run, '--repo', repo, '--log-failed'], text=True, capture_output=True)
selected = []
for line in logs.stdout.splitlines():
    if re.search(r'FAIL|ERROR|Error|Traceback|AssertionError|RESULT:|error:|exit code|Unable to', line):
        if re.search(r'KEYSTORE|PASSWORD|TOKEN|BASE64', line, re.I):
            continue
        line = re.sub(r'https?://\S+', '[URL omitted]', line)
        selected.append(line[-900:])
body = f"Minerva — diagnóstico técnico de [ejecución fallida {run}](https://github.com/{repo}/actions/runs/{run}):\n\n" + '\n'.join('- ' + step for step in failed)
body += '\n\nExtracto filtrado (sin variables de entorno ni credenciales):\n```text\n' + '\n'.join(selected[-80:]) + '\n```\nIgor continúa la corrección; no se solicita QA técnico a Jack.'
p = Path(os.environ['RUNNER_TEMP']) / 'diagnostic-comment.json'
p.write_text(json.dumps({'body': body}))
subprocess.run(['gh', 'api', '--method', 'POST', f'repos/{repo}/issues/8/comments', '--input', str(p), '--jq', '.html_url'], check=True)
