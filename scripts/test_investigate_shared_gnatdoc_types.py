"""Independent parser and input-safety tests for the blocked-type diagnostic."""
from pathlib import Path
import tempfile
import unittest

from investigate_shared_gnatdoc_types import Navigation, Snippet, regular, sections


class OccurrenceTests(unittest.TestCase):
    def test_highlighting_does_not_change_offsets(self):
        parsed = Snippet('<span class="ada-keyword">subtype</span> C is '
                         '<a class="type-reference" href="p.html#a" '
                         'data-type="OpenCV.Point_Array" target="_top">'
                         'OpenCV.Point_Array</a>;')
        self.assertEqual(parsed.text, 'subtype C is OpenCV.Point_Array;')
        self.assertEqual(parsed.links[0]['offset'], 13)
        self.assertEqual(parsed.links[0]['identity'], 'opencv.point_array')
        self.assertEqual(parsed.links[0]['target'], '_top')

    def test_html_entities_use_decoded_offsets(self):
        parsed = Snippet('X &lt; Y : <a class="type-reference" href="#a" '
                         'data-type="P.T">T</a>')
        self.assertEqual(parsed.links[0]['offset'], len('X < Y : '))
        self.assertEqual(parsed.links[0]['spelling'], 'T')

    def test_unclosed_reference_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unclosed'):
            Snippet('<a class="type-reference" href="#a" data-type="P.T">T')

    def test_nested_reference_rejected(self):
        with self.assertRaisesRegex(ValueError, 'nested'):
            Snippet('<a class="type-reference" href="#a" data-type="P.T">'
                    '<a class="type-reference" href="#a" data-type="P.T">T')

    def test_unknown_markup_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unknown snippet markup'):
            Snippet('<script>bad()</script>')

    def test_symlink_input_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'original').write_text('native')
            (root / 'link').symlink_to(root / 'original')
            with self.assertRaisesRegex(ValueError, 'symlink'):
                regular(root / 'link')

    def test_duplicate_declaration_destination_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'api').mkdir()
            declaration = ('<h4 id=a>T</h4><pre class=ada-code-snippet>'
                           '<code>type T is private;</code></pre>')
            (root / 'api/p.html').write_text('<h1>P</h1>' + declaration * 2)
            with self.assertRaisesRegex(ValueError, 'duplicate declaration'):
                sections(root)

    def test_navigation_preserves_labels_category_and_order(self):
        parsed = Navigation('<section class="operation-group" data-category="a">'
                            '<a href="p.html#one">Insert (1)</a>'
                            '<a href="p.html#two">Insert (2)</a></section>'
                            '<a href="other.html">Other package</a>')
        self.assertEqual(parsed.entries, [
            ['a', 'p.html#one', 'Insert (1)'],
            ['a', 'p.html#two', 'Insert (2)']])


if __name__ == '__main__':
    unittest.main()