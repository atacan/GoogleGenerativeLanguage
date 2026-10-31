"""Compose Google's separately published Discovery and Interactions schemas.

Inputs have already passed through the bootstrapper and their provider overlays.
Keep Discovery API names stable, namespace added components, and preserve each
source's effective security requirements before using one generated Swift client.
"""

import argparse
import copy
import json
import os
import tempfile
from pathlib import Path

HTTP_METHODS = {"get", "put", "post", "delete", "options", "head", "patch", "trace"}


def operations(spec):
    for path, item in spec.get("paths", {}).items():
        for method, operation in item.items():
            if method in HTTP_METHODS:
                yield path, method, operation


def merge_specs(discovery, interactions):
    if discovery["openapi"] != interactions["openapi"]:
        raise ValueError("The two sources must use the same OpenAPI version")
    # Discovery additionally advertises a regional endpoint; Interactions only
    # advertises the global endpoint. Preserve existing Servers names while
    # requiring both sources to agree on the primary/default server.
    if discovery["servers"][0]["url"] != interactions["servers"][0]["url"]:
        raise ValueError("Cannot merge schemas with different primary server URLs")
    result = copy.deepcopy(discovery)
    added = copy.deepcopy(interactions)
    names = {
        (section, name): name
        if name.startswith("Interactions")
        else "Interactions" + name
        for section, entries in added["components"].items()
        if section != "securitySchemes"
        for name in entries
    }

    def rewrite_ref(value):
        if not value.startswith("#/components/"):
            return value
        parts = value.split("/")
        section, encoded_name = parts[2:4]
        name = encoded_name.replace("~1", "/").replace("~0", "~")
        replacement = names.get((section, name), name)
        parts[3] = replacement.replace("~", "~0").replace("/", "~1")
        return "/".join(parts)

    used_ids = {op["operationId"] for _, _, op in operations(result)}
    renamed_ids = {}
    for _, _, op in operations(added):
        name = op["operationId"]
        if name in used_ids:
            replacement = "Interactions" + name[0].upper() + name[1:]
            if replacement in used_ids:
                raise ValueError(f"Conflicting operation ID: {replacement}")
            renamed_ids[name] = replacement
        used_ids.add(renamed_ids.get(name, name))

    def rewrite(node):
        if isinstance(node, list):
            return [rewrite(value) for value in node]
        if not isinstance(node, dict):
            return node
        rewritten = {}
        for key, value in node.items():
            if key == "$ref":
                rewritten[key] = rewrite_ref(value)
            elif key == "operationId":
                rewritten[key] = renamed_ids.get(value, value)
            elif key == "discriminator" and isinstance(value, dict):
                rewritten[key] = rewrite(value)
                if "mapping" in value:
                    rewritten[key]["mapping"] = {
                        k: rewrite_ref(v) for k, v in value["mapping"].items()
                    }
            else:
                rewritten[key] = rewrite(value)
        return rewritten

    added = rewrite(added)
    for path, method, op in operations(added):
        if "security" not in op:
            op["security"] = copy.deepcopy(added.get("security", []))
        # Operation/server overrides would need explicit handling instead of
        # accidentally inheriting the Discovery document's configuration.
        if "servers" in op or "servers" in added["paths"][path]:
            raise ValueError(f"Unexpected server override for {method} {path}")
    for path, item in added["paths"].items():
        if path in result["paths"]:
            raise ValueError(f"Conflicting path: {path}")
        result["paths"][path] = item
    for section, entries in added["components"].items():
        destination = result["components"].setdefault(section, {})
        for name, definition in entries.items():
            target = names.get((section, name), name)
            if target in destination:
                existing = {
                    k: v for k, v in destination[target].items() if k != "description"
                }
                incoming = {k: v for k, v in definition.items() if k != "description"}
                if section != "securitySchemes" or existing != incoming:
                    raise ValueError(f"Conflicting component: {section}/{target}")
            else:
                destination[target] = definition
    tags = result.setdefault("tags", [])
    seen_tags = {tag["name"] for tag in tags}
    for tag in added.get("tags", []):
        if tag["name"] not in seen_tags:
            tags.append(tag)
            seen_tags.add(tag["name"])
    result["info"]["description"] += (
        "\n\nIncludes Google's separately published beta Interactions API."
    )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("discovery", type=Path)
    parser.add_argument("interactions", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    merged = merge_specs(
        json.loads(args.discovery.read_text()),
        json.loads(args.interactions.read_text()),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", dir=args.output.parent, delete=False, encoding="utf-8"
    ) as file:
        temporary = Path(file.name)
        try:
            json.dump(merged, file, indent=2, ensure_ascii=False)
            file.write("\n")
            file.close()
            os.replace(temporary, args.output)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
