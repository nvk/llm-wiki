#!/usr/bin/env python3
"""Behavior checks for the unified Hermes llm-wiki plugin."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_ROOT = ROOT / "hermes-plugin" / "llm-wiki"
sys.path.insert(0, str(PLUGIN_ROOT))

from llm_wiki_tools import inspect_wiki, validate_wiki  # noqa: E402


class HermesLlmWikiPluginTests(unittest.TestCase):
    def test_manifest_declares_tools_and_desktop_package(self) -> None:
        manifest = (PLUGIN_ROOT / "plugin.yaml").read_text(encoding="utf-8")
        self.assertIn("name: llm-wiki", manifest)
        self.assertIn("llm_wiki_status", manifest)
        self.assertIn("llm_wiki_lint", manifest)
        self.assertTrue((PLUGIN_ROOT / "desktop" / "plugin.js").is_file())
        self.assertTrue((PLUGIN_ROOT / "dashboard" / "manifest.json").is_file())
        self.assertTrue((PLUGIN_ROOT / "README.md").is_file())

    def test_inspect_wiki_reports_document_counts_and_missing_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / "raw" / "articles").mkdir(parents=True)
            (root / "wiki" / "concepts").mkdir(parents=True)
            (root / "raw" / "articles" / "source.md").write_text("# Source\n", encoding="utf-8")
            (root / "wiki" / "concepts" / "concept.md").write_text("# Concept\n", encoding="utf-8")

            report = inspect_wiki(str(root))

            self.assertTrue(report["exists"])
            self.assertEqual(report["raw_documents"], 1)
            self.assertEqual(report["wiki_articles"], 1)
            self.assertEqual(report["missing_required_directories"], ["output"])

        missing = inspect_wiki(str(root / "does-not-exist"))
        self.assertFalse(missing["exists"])
        self.assertEqual(missing["raw_documents"], 0)

    def test_validate_wiki_returns_command_result_without_shell_parsing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            (root / "_index.md").write_text("# Index\n", encoding="utf-8")

            report = validate_wiki(str(root), command=[sys.executable, "-c", "print('validated')"])

        self.assertEqual(report["returncode"], 0)
        self.assertEqual(report["stdout"], "validated\n")
        self.assertEqual(report["stderr"], "")


if __name__ == "__main__":
    unittest.main()
