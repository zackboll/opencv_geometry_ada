#!/usr/bin/env python3
"""Mutation tests for the package- and operation-level browser.

Adapted from opencv_imgproc_ada for Geometry's two packages.
"""

import contextlib
import io
import json
import re
import shutil
import tempfile
import unittest
from pathlib import Path

from enhance_gnatdoc_navigation import (CATEGORIES, check_navigation, enhance,
                                        entries, load_categories)
from link_gnatdoc_types import CrossReferenceError
from validate_docs import DocumentationError, validate

ROOT = Path(__file__).resolve().parent.parent


class CategoryManifestTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary.name) / "categories.json"
        self.data = json.loads(CATEGORIES.read_text(encoding="utf-8"))

    def tearDown(self):
        self.temporary.cleanup()

    def write(self):
        self.path.write_text(json.dumps(self.data), encoding="utf-8")
        return self.path

    def test_repository_manifest_covers_each_public_name_once(self):
        packages, owner = load_categories()
        self.assertEqual([name for name, _ in packages],
                         ["OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"])
        self.assertEqual([len(categories) for _, categories in packages], [7, 5])
        self.assertEqual(len(owner), 106)
        self.assertEqual(owner[("OpenCV.Geometry", "Convex_Hull")], "hulls-convexity")
        self.assertEqual(owner[("OpenCV.Geometry", "Is_Natively_Supported")],
                         "capability")
        self.assertEqual(owner[("OpenCV.Geometry.Subdiv2D", "Find_Nearest")],
                         "subdivision-queries")
        self.assertEqual(owner[("OpenCV.Geometry.Subdiv2D", "Voronoi_Facets")],
                         "subdivision-voronoi")

    def test_duplicate_membership_is_rejected(self):
        self.data["packages"][0]["categories"][0]["declarations"].append("Convex_Hull")
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())

    def test_duplicate_category_id_across_packages_is_rejected(self):
        self.data["packages"][1]["categories"][0]["id"] = "transforms"
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())

    def test_bad_version_and_empty_category_are_rejected(self):
        self.data["version"] = 2
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())
        self.data["version"] = 1
        self.data["packages"][0]["categories"][0]["declarations"] = []
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())

    def test_package_listed_twice_is_rejected(self):
        self.data["packages"].append(self.data["packages"][0])
        with self.assertRaises(CrossReferenceError):
            load_categories(self.write())


@unittest.skipUnless((ROOT / "_site/api/gnatdoc-navigation.js").is_file(),
                     "generated site not present; run scripts/generate_docs.sh")
class GeneratedNavigationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary.name) / "_site"
        shutil.copytree(ROOT / "_site", self.site)
        self.api = self.site / "api"
        self.index = self.api / "index.html"

    def tearDown(self):
        self.temporary.cleanup()

    def edit(self, old, new):
        text = self.index.read_text(encoding="utf-8")
        self.assertIn(old, text, "mutation did not apply")
        self.index.write_text(text.replace(old, new, 1), encoding="utf-8")

    def assertRejected(self, fragment="unapproved navigation"):
        with self.assertRaises(CrossReferenceError) as caught:
            check_navigation(self.api)
        self.assertIn(fragment, str(caught.exception))
        with self.assertRaises(DocumentationError):
            validate(self.site, ROOT)

    def test_every_declaration_has_one_verified_entry(self):
        packages = entries(self.api)
        self.assertEqual([package for package, _, _ in packages],
                         ["OpenCV.Geometry", "OpenCV.Geometry.Subdiv2D"])
        total = 0
        for package, page, groups in packages:
            items = [item for _, _, group in groups for item in group]
            total += len(items)
            text = (self.api / page).read_text(encoding="utf-8")
            anchors = set(re.findall(r"<h4 id=([^ >]+)>", text))
            self.assertEqual({item["href"] for item in items},
                             {f"{page}#{anchor}" for anchor in anchors})
            self.assertTrue(all(item["package"] == package for item in items))
        self.assertEqual(total, 130)
        index = self.index.read_text(encoding="utf-8")
        self.assertEqual(index.count("<li data-package="), 130)
        geometry = [item for _, _, groups in packages[:1] for _, _, group in groups
                    for item in group]
        hulls = [i for i in geometry if i["name"] == "Convex_Hull"]
        self.assertEqual([(i["overload"], i["overloads"]) for i in hulls],
                         [(1, 2), (2, 2)])
        self.assertIn("overload 2 of 2", index)

    def test_enhancement_is_idempotent(self):
        before = {p.name: p.read_bytes() for p in self.api.iterdir()}
        with contextlib.redirect_stdout(io.StringIO()):
            enhance(self.api)
        self.assertEqual({p.name: p.read_bytes() for p in self.api.iterdir()}, before)

    def test_wrong_but_existing_destination_is_rejected(self):
        index = self.index.read_text(encoding="utf-8")
        hrefs = re.findall(r'<li data-package="OpenCV.Geometry" '
                           r'data-op="(?:Contour_Area|Arc_Length)"[^>]*><a href=([^ >]+)',
                           index)
        self.assertEqual(len(hrefs), 4)
        self.edit(hrefs[0], hrefs[2])
        self.assertRejected()

    def test_entry_moved_to_the_other_package_is_rejected(self):
        self.edit('<li data-package="OpenCV.Geometry.Subdiv2D" data-op="Insert"',
                  '<li data-package="OpenCV.Geometry" data-op="Insert"')
        self.assertRejected()

    def test_missing_entry_is_rejected(self):
        entry = re.search(r'<li data-package="OpenCV.Geometry.Subdiv2D" '
                          r'data-op="Find_Nearest".*?</a>',
                          self.index.read_text(encoding="utf-8"))[0]
        self.edit(entry, "")
        self.assertRejected()

    def test_inline_handler_is_rejected(self):
        self.edit("<button id=api-clear type=button>",
                  "<button id=api-clear type=button onclick=alert(1)>")
        self.assertRejected()

    def test_second_script_is_rejected(self):
        self.edit('<body class=main>', '<script src=x.js></script><body class=main>')
        self.assertRejected()

    def test_script_on_a_package_page_is_rejected(self):
        page = next(p for p in self.api.glob("*.html") if p.name != "index.html")
        text = page.read_text(encoding="utf-8")
        page.write_text(text.replace("<h1>", '<script src="gnatdoc-navigation.js" '
                                     'defer></script><h1>', 1), encoding="utf-8")
        with self.assertRaises(DocumentationError) as caught:
            validate(self.site, ROOT)
        self.assertIn("unapproved active content", str(caught.exception))

    def test_tampered_script_asset_is_rejected(self):
        asset = self.api / "gnatdoc-navigation.js"
        asset.write_text(asset.read_text(encoding="utf-8") + "\n//x\n", encoding="utf-8")
        self.assertRejected("navigation asset differs")

    def test_changed_frame_target_is_rejected(self):
        self.edit("target=document-content title=", "target=_blank title=")
        self.assertRejected()

    def test_package_heading_link_redirected_is_rejected(self):
        packages = entries(self.api)
        pages = [page for _, page, _ in packages]
        self.edit(f'<h3><a href={pages[1]} target=document-content>',
                  f'<h3><a href={pages[0]} target=document-content>')
        self.assertRejected()


if __name__ == "__main__":
    unittest.main()
