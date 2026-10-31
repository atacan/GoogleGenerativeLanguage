"""Regression coverage for composing two independently versioned Google sources."""

import copy
import importlib.util
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "merge_openapi", ROOT / "scripts/merge_openapi.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def source():
    return {
        "openapi": "3.0.3",
        "info": {"description": "Example"},
        "servers": [{"url": "https://generativelanguage.googleapis.com"}],
        "security": [{"GoogleAPIKey": []}],
        "paths": {"/example": {"get": {"operationId": "GetExample", "responses": {}}}},
        "components": {
            "schemas": {"Content": {"type": "object"}},
            "securitySchemes": {
                "GoogleAPIKey": {
                    "type": "apiKey",
                    "in": "header",
                    "name": "x-goog-api-key",
                }
            },
        },
    }


class MergeTests(unittest.TestCase):
    def inputs(self):
        first, second = source(), source()
        second["paths"]["/{api_version}/interactions"] = second["paths"].pop("/example")
        second["security"] = [{"bearer_auth": []}]
        second["components"]["securitySchemes"]["bearer_auth"] = {
            "type": "http",
            "scheme": "bearer",
        }
        return first, second

    def test_namespaces_references_and_preserves_each_sources_authentication(self):
        first, second = self.inputs()
        second["components"]["schemas"]["Union"] = {
            "oneOf": [{"$ref": "#/components/schemas/Content"}],
            "discriminator": {
                "propertyName": "type",
                "mapping": {"text": "#/components/schemas/Content"},
            },
        }
        originals = copy.deepcopy((first, second))
        merged = module.merge_specs(first, second)
        self.assertEqual((first, second), originals)
        self.assertEqual(
            merged["components"]["schemas"]["Content"],
            first["components"]["schemas"]["Content"],
        )
        union = merged["components"]["schemas"]["InteractionsUnion"]
        self.assertEqual(
            union["oneOf"][0]["$ref"], "#/components/schemas/InteractionsContent"
        )
        self.assertEqual(
            union["discriminator"]["mapping"]["text"],
            "#/components/schemas/InteractionsContent",
        )
        operation = merged["paths"]["/{api_version}/interactions"]["get"]
        self.assertEqual(operation["security"], [{"bearer_auth": []}])
        self.assertEqual(operation["operationId"], "InteractionsGetExample")
        self.assertEqual(
            merged["paths"]["/example"]["get"]["operationId"], "GetExample"
        )
        self.assertEqual(len(merged["components"]["securitySchemes"]), 2)

    def test_explicit_public_security_survives(self):
        first, second = self.inputs()
        second["paths"]["/{api_version}/interactions"]["get"]["security"] = []
        merged = module.merge_specs(first, second)
        self.assertEqual(
            merged["paths"]["/{api_version}/interactions"]["get"]["security"], []
        )

    def test_conflicting_paths_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Conflicting path"):
            module.merge_specs(source(), source())

    def test_conflicting_security_is_rejected(self):
        first, second = self.inputs()
        second["components"]["securitySchemes"]["GoogleAPIKey"]["name"] = (
            "another-header"
        )
        with self.assertRaisesRegex(ValueError, "Conflicting component"):
            module.merge_specs(first, second)

    def test_different_primary_server_is_rejected(self):
        first, second = self.inputs()
        second["servers"][0]["url"] = "https://other.example.com"
        with self.assertRaisesRegex(ValueError, "different primary"):
            module.merge_specs(first, second)

    @unittest.skipUnless(
        shutil.which("make") and shutil.which("curl"), "make and curl required"
    )
    def test_failed_downloads_preserve_each_source_and_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            invalid = Path(directory) / "invalid.json"
            invalid.write_text('{"error":"not an OpenAPI document"}')
            for name, variable in (
                ("discovery", "OPENAPI_URL"),
                ("interactions", "INTERACTIONS_OPENAPI_URL"),
            ):
                with self.subTest(source=name):
                    source_path = (
                        ROOT / "specifications" / name / "original_openapi.json"
                    )
                    before = source_path.read_bytes()
                    temporary_files = set(ROOT.glob(".original-openapi.*"))
                    result = subprocess.run(
                        [
                            "make",
                            f"download-{name}-openapi",
                            f"{variable}={invalid.as_uri()}",
                        ],
                        cwd=ROOT,
                        capture_output=True,
                        text=True,
                        timeout=15,
                    )
                    self.assertNotEqual(
                        result.returncode, 0, result.stdout + result.stderr
                    )
                    self.assertEqual(source_path.read_bytes(), before)
                    self.assertEqual(
                        set(ROOT.glob(".original-openapi.*")), temporary_files
                    )

    def test_all_upstream_const_only_tags_are_typed_by_the_generator(self):
        original = json.loads(
            (ROOT / "specifications/interactions/original_openapi.json").read_text()
        )
        merged = json.loads((ROOT / "original_openapi.json").read_text())
        count = 0
        for name, schema in original["components"]["schemas"].items():
            for property_name, prop in schema.get("properties", {}).items():
                if "type" not in prop and isinstance(prop.get("const"), str):
                    target = (
                        name
                        if name.startswith("Interactions")
                        else "Interactions" + name
                    )
                    typed = merged["components"]["schemas"][target]["properties"][
                        property_name
                    ]
                    with self.subTest(schema=name, property=property_name):
                        self.assertEqual(typed["type"], "string")
                        self.assertEqual(typed["enum"], [prop["const"]])
                    count += 1
        self.assertGreater(count, 0)

    def test_real_combined_schema_keeps_all_sources_and_resolves_local_references(self):
        merged = json.loads((ROOT / "original_openapi.json").read_text())
        discovery = json.loads(
            (ROOT / "specifications/discovery/original_openapi.json").read_text()
        )
        interactions = json.loads(
            (ROOT / "specifications/interactions/original_openapi.json").read_text()
        )
        self.assertEqual(
            len(merged["paths"]),
            len(discovery["paths"]) + len(interactions["paths"]) + 1,
        )
        self.assertEqual(
            merged["components"]["schemas"]["Part"],
            discovery["components"]["schemas"]["Part"],
        )
        self.assertNotIn(
            "enum", merged["components"]["schemas"]["InteractionsModelOption"]
        )
        self.assertEqual(
            merged["components"]["schemas"]["InteractionsModelOutputStep"][
                "properties"
            ]["type"]["type"],
            "string",
        )
        self.assertEqual(
            merged["paths"]["/{api_version}/interactions"]["post"]["security"],
            [{"GoogleAPIKey": []}, {"bearer_auth": []}],
        )
        names = [op["operationId"] for _, _, op in module.operations(merged)]
        self.assertEqual(len(names), len(set(names)))

        def check(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    if key == "$ref" and value.startswith("#/"):
                        current = merged
                        for part in value[2:].split("/"):
                            current = current[
                                part.replace("~1", "/").replace("~0", "~")
                            ]
                    else:
                        check(value)
            elif isinstance(node, list):
                for value in node:
                    check(value)

        check(merged)
