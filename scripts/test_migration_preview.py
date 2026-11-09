"""Real released-output attacks. Run with GEOMETRY_MIGRATION_PREVIEW set.

This supplements, never replaces, historical/current/synthetic campaigns.
The fixture must be a completed preview from preview_gnatdoc_migration.py.
"""
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

from gnatdoc_migration_policy import validate_local_site, staged_public, regular


@unittest.skipUnless(os.environ.get("GEOMETRY_MIGRATION_PREVIEW"), "requires real production preview")
class ProductionMutations(unittest.TestCase):
    def setUp(self):
        self.workspace = Path(os.environ["GEOMETRY_MIGRATION_PREVIEW"])
        self.source = self.workspace / "candidate"
        self.core = self.workspace / "core"
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.site = Path(self.temp.name) / "site"
        shutil.copytree(self.source / "_site", self.site)

    def reject(self):
        with self.assertRaises((ValueError, OSError)):
            validate_local_site(self.source, self.site, self.core)

    def test_real_output_accepted(self):
        self.assertEqual(validate_local_site(self.source, self.site, self.core)["sections"], 138)

    def test_native_declaration_changed(self):
        path = next(p for p in (self.site / "api").glob("*.html") if '<h4 id=' in p.read_text())
        text = path.read_text()
        self.assertIn('Contour', text)
        path.write_text(text.replace('Contour', 'Forged_Contour', 1))
        self.reject()

    def test_fake_external_destination(self):
        path = next(p for p in (self.site / "api").glob("*.html")
                    if 'https://zackboll.github.io/opencv_core_ada/' in p.read_text())
        path.write_text(path.read_text().replace('https://zackboll.github.io/opencv_core_ada/',
                                               'https://evil.invalid/', 1))
        self.reject()

    def test_authored_landing_and_every_guide_and_css(self):
        names = ['index.html', 'guides/gnatdoc-guides.css'] + [
            p.relative_to(self.site).as_posix() for p in (self.site / 'guides').glob('*.html')]
        for name in names:
            path = self.site / name
            before = path.read_bytes()
            with self.subTest(name=name):
                path.write_bytes(before + b'\n<!-- unauthorized -->\n')
                self.reject()
            path.write_bytes(before)

    def test_missing_and_unexpected_output(self):
        (self.site / 'unexpected.ads').write_text('unapproved')
        self.reject()
        (self.site / 'unexpected.ads').unlink()
        (self.site / 'api/gnatdoc.css').unlink()
        self.reject()

    def test_substituted_native_metadata(self):
        path = self.site / 'api/presentation.json'
        data = json.loads(path.read_text())
        name = next(iter(data['original_api_html']))
        data['original_api_html'][name] += '\n'
        path.write_text(json.dumps(data))
        self.reject()

    def test_staged_bytes_extra_sources_and_symlinks(self):
        directory = self.source / 'qualification-public'
        path = directory / 'opencv-geometry.ads'
        before = regular(path)
        self.addCleanup(path.write_bytes, before)
        try:
            path.write_bytes(before + b'\n')
            with self.assertRaisesRegex(ValueError, 'staged source differs'):
                staged_public(self.source)
            path.unlink()
            path.symlink_to(self.source / 'src/opencv-geometry.ads')
            with self.assertRaisesRegex(ValueError, 'substituted policy input'):
                staged_public(self.source)
        finally:
            path.unlink()
            path.write_bytes(before)
        extra = directory / 'extra.ads'
        try:
            extra.write_text('unapproved')
            with self.assertRaisesRegex(ValueError, 'staging inventory'):
                staged_public(self.source)
        finally:
            extra.unlink()


if __name__ == '__main__':
    unittest.main()