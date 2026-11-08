"""Finite native-link policy: no candidate host, URL, feature or tool authority."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from gnatdoc_migration_policy import direct_configuration, ROOT
from qualify_current_core import REFERENCED_TYPES


class DirectConfigurationTests(unittest.TestCase):
    def configuration(self, published):
        shadow = (ROOT / 'docs/shared-gnatdoc-shadow.toml').read_bytes()
        with patch('additive_gnatdoc_policy.authored_contract', return_value=(b'authored', shadow)):
            return direct_configuration(ROOT, ROOT, published)

    def test_ordinary_mappings_only_exact_inventory_and_top(self):
        types = json.loads((ROOT / 'docs/evidence/geometry-gnatdoc-003r1/referenced-types.json').read_text())
        authored, config = self.configuration(types)
        self.assertEqual(authored, b'authored')
        self.assertNotIn('external_dependencies', config)
        self.assertNotIn('external_symbol_bookmarks', config)
        self.assertEqual(set(config['external_types']), REFERENCED_TYPES)
        self.assertEqual(config['presentation']['external_type_target'], '_top')
        self.assertEqual(config['security']['external_hosts'], ['github.com', 'zackboll.github.io'])
        self.assertEqual(config['presentation']['theme_css_source'], 'docs/assets/gnatdoc-theme.css')
        for key in ('opencv.core.mat', 'unreviewed.type'):
            changed = copy.deepcopy(types)
            changed.pop(key) if key in changed else changed.update({key: {'url':'https://evil.invalid/a#b'}})
            with self.assertRaisesRegex(ValueError, 'unqualified Core type inventory'):
                self.configuration(changed)


if __name__ == '__main__':
    unittest.main()