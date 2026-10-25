#!/usr/bin/env python3
"""No real signing key, credential, Godot export or workflow run is used here."""
import base64
from contextlib import redirect_stdout, redirect_stderr
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('apk_signing', ROOT / 'tools/ci/apk-signing.py')
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class ExportGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        scripts = self.root / 'tools/ci'
        scripts.mkdir(parents=True)
        for name in ['export-android.sh', 'check-signing-secrets.sh']:
            shutil.copy2(ROOT / 'tools/ci' / name, scripts / name)
        shutil.copy2(ROOT / 'export_presets.cfg', self.root / 'export_presets.cfg')
        self.ci = self.root / '.local/android-ci'
        template = self.ci / 'data/godot/export_templates/4.6.3.stable/android_debug.apk'
        template.parent.mkdir(parents=True)
        template.touch()  # Only a guard fixture, never exported or executed.
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.write_executable('godot', '''#!/usr/bin/env bash
if [[ "$*" == --version ]]; then echo '4.6.3.stable.test'; exit 0; fi
touch "$TEST_ROOT/export-was-attempted"
exit 99
''')
        self.write_executable('keytool', '''#!/usr/bin/env bash
if [[ "$*" == *-exportcert* ]]; then touch "$TEST_ROOT/certificate-was-attempted"; exit 1; fi
if [[ "${TEST_ENTRY_TYPE:-}" == certificate ]]; then echo 'Entry type: trustedCertEntry'; exit 0; fi
echo 'PRIVATE_DIAGNOSTIC' >&2
exit 1
''')
        self.env = os.environ.copy()
        for name in list(self.env):
            if name.startswith(('HASHI_SIGNING_', 'GODOT_ANDROID_KEYSTORE_')):
                del self.env[name]
        self.env.update(PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        JAVA_HOME=str(self.root), ANDROID_HOME=str(self.root / 'sdk'),
                        TEST_ROOT=str(self.root))

    def write_executable(self, name, text):
        p = self.bin / name
        p.write_text(text)
        p.chmod(0o700)

    def run_guard(self):
        result = subprocess.run(['bash', '-x', str(self.root / 'tools/ci/export-android.sh')],
                                env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'export-was-attempted').exists())
        self.assertEqual(list(self.ci.glob('signing-*')), [])
        self.assertNotIn('PRIVATE_DIAGNOSTIC', result.stdout + result.stderr)
        self.assertFalse(any(self.env.get(name) and self.env[name] in result.stdout + result.stderr
                             for name in ('HASHI_SIGNING_KEYSTORE_BASE64', 'HASHI_SIGNING_PASSWORD')))
        return result.stdout + result.stderr

    def fixture_credentials(self):
        # Not a key or password: synthetic in-memory test input only.
        self.env['HASHI_SIGNING_KEYSTORE_BASE64'] = base64.b64encode(b'non-key fixture').decode()
        self.env['HASHI_SIGNING_PASSWORD'] = uuid.uuid4().hex

    def test_both_absent(self):
        self.assertIn('Missing persistent', self.run_guard())

    def test_password_absent(self):
        self.fixture_credentials()
        del self.env['HASHI_SIGNING_PASSWORD']
        self.assertIn('Missing persistent', self.run_guard())

    def test_keystore_absent(self):
        self.fixture_credentials()
        del self.env['HASHI_SIGNING_KEYSTORE_BASE64']
        self.assertIn('Missing persistent', self.run_guard())

    def test_empty_secret(self):
        self.fixture_credentials()
        self.env['HASHI_SIGNING_PASSWORD'] = ''
        self.assertIn('Missing persistent', self.run_guard())

    def test_partial_bad_decode_is_cleaned(self):
        self.fixture_credentials()
        self.env['HASHI_SIGNING_KEYSTORE_BASE64'] += '!'
        self.assertIn('Invalid signing keystore encoding', self.run_guard())

    def test_bad_identity_is_cleaned_without_diagnostics(self):
        self.fixture_credentials()
        self.assertIn('Unable to open signing identity', self.run_guard())

    def test_certificate_without_private_key_is_rejected(self):
        self.fixture_credentials()
        self.env['TEST_ENTRY_TYPE'] = 'certificate'
        self.assertIn('must contain a private key', self.run_guard())
        self.assertFalse((self.root / 'certificate-was-attempted').exists())

    def test_preset_credentials_cannot_override_identity(self):
        self.fixture_credentials()
        p = self.root / 'export_presets.cfg'
        p.write_text(p.read_text().replace('[preset.0.options]', '[preset.0.options]\nkeystore/debug="fixture"'))
        self.assertIn('must remain empty', self.run_guard())


class CertificateChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.first = self.root / 'first.apk'
        self.second = self.root / 'second.apk'
        self.first.touch()
        self.second.touch()

    def invoke(self, args, fingerprints):
        with patch.object(sys, 'argv', ['apk-signing.py', '--apksigner', 'fixture', *args]), \
             patch.object(signing, 'fingerprint', side_effect=fingerprints), \
             redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return signing.main()

    def test_matching_consecutive_certificates(self):
        self.assertEqual(self.invoke(['compare', str(self.first), str(self.second)], ['a' * 64, 'a' * 64]), 0)

    def test_different_certificates_rejected(self):
        self.assertEqual(self.invoke(['compare', str(self.first), str(self.second)], ['a' * 64, 'b' * 64]), 1)

    def test_same_path_not_two_builds(self):
        self.assertEqual(self.invoke(['compare', str(self.first), str(self.first)], []), 1)

    def test_expected_supplied_certificate(self):
        cert = self.root / 'public.der'
        cert.write_bytes(b'public certificate fixture')
        digest = hashlib.sha256(cert.read_bytes()).hexdigest()
        output = self.root / 'fingerprint.txt'
        self.assertEqual(self.invoke(['verify', str(self.first), '--certificate', str(cert), '--output', str(output)], [digest]), 0)
        self.assertEqual(output.read_text(), digest + '\n')

    def test_fallback_key_certificate_rejected(self):
        cert = self.root / 'public.der'
        cert.write_bytes(b'public certificate fixture')
        output = self.root / 'fingerprint.txt'
        self.assertEqual(self.invoke(['verify', str(self.first), '--certificate', str(cert), '--output', str(output)], ['b' * 64]), 1)
        self.assertFalse(output.exists())

    def test_parse_verified_public_fingerprint(self):
        result = subprocess.CompletedProcess([], 0, 'Signer #1 certificate SHA-256 digest: ' + 'A' * 64 + '\n', '')
        with patch.object(signing.subprocess, 'run', return_value=result):
            self.assertEqual(signing.fingerprint(self.first, 'fixture'), 'a' * 64)

    def test_bad_signature_or_missing_or_multiple_signers_rejected(self):
        outputs = [subprocess.CompletedProcess([], 1, '', ''),
                   subprocess.CompletedProcess([], 0, '', ''),
                   subprocess.CompletedProcess([], 0, '\n'.join('Signer #' + str(i) + ' certificate SHA-256 digest: ' + 'a' * 64 for i in [1, 2]), '')]
        for result in outputs:
            with self.subTest(code=result.returncode, size=len(result.stdout)), \
                 patch.object(signing.subprocess, 'run', return_value=result), self.assertRaises(ValueError):
                signing.fingerprint(self.first, 'fixture')


if __name__ == '__main__':
    unittest.main()
