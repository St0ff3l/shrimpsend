#!/usr/bin/env python3
"""One-shot: add cn/intl Xcode build configurations to Runner.xcodeproj/project.pbxproj."""
from __future__ import annotations

import re
import uuid
from pathlib import Path

PBX = Path(__file__).resolve().parent.parent / "Runner.xcodeproj" / "project.pbxproj"

CN = {
    "CUSTOM_GROUP_ID": "group.dev.ultrasend.app.cn",
    "PRODUCT_BUNDLE_IDENTIFIER": "dev.ultrasend.app.cn",
    "INFOPLIST_KEY_CFBundleDisplayName": "虾传",
    "SHARE_EXT_BUNDLE": "dev.ultrasend.app.cn.ShareExtension",
    "TESTS_BUNDLE": "dev.ultrasend.app.cn.RunnerTests",
}
INTL = {
    "CUSTOM_GROUP_ID": "group.dev.ultrasend.app",
    "PRODUCT_BUNDLE_IDENTIFIER": "dev.ultrasend.app",
    "INFOPLIST_KEY_CFBundleDisplayName": "ShrimpSend",
    "SHARE_EXT_BUNDLE": "dev.ultrasend.app.ShareExtension",
    "TESTS_BUNDLE": "dev.ultrasend.app.RunnerTests",
}

XCCONFIG_REFS = {
    "cn": {
        "Debug": "cnDebug.xcconfig",
        "Release": "cnRelease.xcconfig",
        "Profile": "cnProfile.xcconfig",
    },
    "intl": {
        "Debug": "intlDebug.xcconfig",
        "Release": "intlRelease.xcconfig",
        "Profile": "intlProfile.xcconfig",
    },
}


def gen_id() -> str:
    return uuid.uuid4().hex[:24].upper()


def set_bundle_display_name(body: str, display_name: str) -> str:
    quoted = f'BUNDLE_DISPLAY_NAME = "{display_name}";'
    if "BUNDLE_DISPLAY_NAME" in body:
        return re.sub(
            r'BUNDLE_DISPLAY_NAME = (?:"[^"]*"|[^;]+);',
            quoted,
            body,
        )
    return body.replace(
        "ENABLE_BITCODE = NO;\n",
        f"ENABLE_BITCODE = NO;\n\t\t\t\t{quoted}\n",
        1,
    )


def set_display_name(body: str, display_name: str) -> str:
    quoted = f'INFOPLIST_KEY_CFBundleDisplayName = "{display_name}";'
    if "INFOPLIST_KEY_CFBundleDisplayName" in body:
        return re.sub(
            r'INFOPLIST_KEY_CFBundleDisplayName = (?:"[^"]*"|[^;]+);',
            quoted,
            body,
        )
    return body.replace(
        "INFOPLIST_FILE = Runner/Info.plist;\n",
        "INFOPLIST_FILE = Runner/Info.plist;\n"
        f"\t\t\t\t{quoted}\n",
    )


def set_entitlements(body: str, path: str) -> str:
    return re.sub(
        r'CODE_SIGN_ENTITLEMENTS = (?:"[^"]+"|[^;]+);',
        f'CODE_SIGN_ENTITLEMENTS = {path};',
        body,
        count=1,
    )


def repair_flavor_settings(text: str) -> str:
    block_re = re.compile(
        r"(\t\t[A-F0-9]{24} /\* [^*]+ \*/ = \{\n"
        r"\t\t\tisa = XCBuildConfiguration;\n"
        r"(.*?)\n\t\t\tname = ([^;]+);\n\t\t\};)",
        re.DOTALL,
    )

    def patch_block(match: re.Match[str]) -> str:
        body = match.group(2)
        name = match.group(3).strip().strip('"')
        if name.endswith("-cn"):
            if "INFOPLIST_FILE = Runner/Info.plist;" in body:
                body = set_entitlements(body, "Runner/Runner-cn.entitlements")
                body = set_display_name(body, CN["INFOPLIST_KEY_CFBundleDisplayName"])
                body = set_bundle_display_name(
                    body, CN["INFOPLIST_KEY_CFBundleDisplayName"]
                )
            elif 'INFOPLIST_FILE = "Share Extension/Info.plist";' in body:
                body = set_entitlements(
                    body, '"Share Extension/Share Extension-cn.entitlements"'
                )
                body = set_display_name(body, CN["INFOPLIST_KEY_CFBundleDisplayName"])
        elif name.endswith("-intl"):
            if "INFOPLIST_FILE = Runner/Info.plist;" in body:
                body = set_entitlements(body, "Runner/Runner-intl.entitlements")
                body = set_display_name(body, INTL["INFOPLIST_KEY_CFBundleDisplayName"])
                body = set_bundle_display_name(
                    body, INTL["INFOPLIST_KEY_CFBundleDisplayName"]
                )
            elif 'INFOPLIST_FILE = "Share Extension/Info.plist";' in body:
                body = set_entitlements(
                    body, '"Share Extension/Share Extension-intl.entitlements"'
                )
                body = set_display_name(body, INTL["INFOPLIST_KEY_CFBundleDisplayName"])
        return match.group(0).replace(match.group(2), body, 1)

    return block_re.sub(patch_block, text)


def main() -> None:
    text = PBX.read_text(encoding="utf-8")
    if "Debug-cn" in text:
        repaired = repair_flavor_settings(text)
        if repaired != text:
            PBX.write_text(repaired, encoding="utf-8")
            print(f"Repaired flavor entitlements/display names in {PBX}")
        else:
            print("Already configured; nothing to repair.")
        return

    # --- Add PBXFileReference for flavor xcconfigs ---
    flutter_group_marker = "9740EEB21CF90195004384FC /* Debug.xcconfig */"
    new_refs: list[str] = []
    ref_ids: dict[tuple[str, str], str] = {}
    for flavor, modes in XCCONFIG_REFS.items():
        for mode, filename in modes.items():
            rid = gen_id()
            ref_ids[(flavor, mode)] = rid
            new_refs.append(
                f"\t\t{rid} /* {filename} */ = {{isa = PBXFileReference; "
                f"lastKnownFileType = text.xcconfig; name = {filename}; "
                f"path = Flutter/{filename}; sourceTree = \"<group>\"; }};"
            )
    insert_at = text.index(flutter_group_marker)
    text = text[:insert_at] + "\n".join(new_refs) + "\n\t\t" + text[insert_at:]

    # Add refs to Flutter PBXGroup children
    group_children = "9740EEB21CF90195004384FC /* Debug.xcconfig */"
    extra_children = "".join(
        f"\n\t\t\t\t{ref_ids[(f, m)]} /* {XCCONFIG_REFS[f][m]} */,"
        for f in ("cn", "intl")
        for m in ("Debug", "Release", "Profile")
    )
    text = text.replace(
        f"\t\t\t\t{group_children},",
        f"\t\t\t\t{group_children},{extra_children}",
        1,
    )

    # --- Parse XCBuildConfiguration blocks ---
    block_re = re.compile(
        r"\t\t([A-F0-9]{24}) /\* ([^*]+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n"
        r"(.*?)\n\t\t\tname = (Debug|Release|Profile);\n\t\t\};",
        re.DOTALL,
    )

    config_ids: dict[tuple[str, str, str], str] = {}  # (target_kind, mode, flavor) -> id
    new_blocks: list[str] = []

    def target_kind_from_body(body: str, name: str) -> str | None:
        if "Pods-RunnerTests" in body or "RunnerTests" in name:
            return "tests"
        if "Pods-Share Extension" in body or "Share Extension" in name:
            return "share"
        if "baseConfigurationReference" in body and "Runner/" in body:
            return "runner"
        if name in ("Debug", "Release", "Profile") and "IPHONEOS_DEPLOYMENT_TARGET" in body:
            if "PRODUCT_BUNDLE_IDENTIFIER" not in body:
                return "project"
        if "249021D4" in body or ("Profile" in name and "Runner.entitlements" in body):
            return "runner"
        return None

    for m in block_re.finditer(text):
        cid, _comment, body, mode = m.group(1), m.group(2), m.group(3), m.group(4)
        kind = target_kind_from_body(body, _comment)
        if kind is None:
            continue

        # intl: rename existing block
        intl_id = cid
        intl_body = body
        if kind == "runner":
            intl_body = re.sub(
                r"\t\t\tbaseConfigurationReference = [A-F0-9]{24} /\* [^*]+ \*/;\n",
                f"\t\t\tbaseConfigurationReference = {ref_ids[('intl', mode)]} /* {XCCONFIG_REFS['intl'][mode]} */;\n",
                intl_body,
                count=1,
            )
            intl_body = set_entitlements(intl_body, "Runner/Runner-intl.entitlements")
            intl_body = set_display_name(
                intl_body, INTL["INFOPLIST_KEY_CFBundleDisplayName"]
            )
            intl_body = set_bundle_display_name(
                intl_body, INTL["INFOPLIST_KEY_CFBundleDisplayName"]
            )
        elif kind == "share":
            intl_body = set_entitlements(
                intl_body, '"Share Extension/Share Extension-intl.entitlements"'
            )
            intl_body = set_display_name(
                intl_body, INTL["INFOPLIST_KEY_CFBundleDisplayName"]
            )
        config_ids[(kind, mode, "intl")] = intl_id
        new_blocks.append(
            f"\t\t{intl_id} /* {mode}-intl */ = {{\n\t\t\tisa = XCBuildConfiguration;\n"
            f"{intl_body}\n\t\t\tname = {mode}-intl;\n\t\t}};"
        )

        # cn: duplicate
        cn_id = gen_id()
        cn_body = body
        if kind == "runner":
            cn_body = re.sub(
                r"\t\t\tbaseConfigurationReference = [A-F0-9]{24} /\* [^*]+ \*/;\n",
                f"\t\t\tbaseConfigurationReference = {ref_ids[('cn', mode)]} /* {XCCONFIG_REFS['cn'][mode]} */;\n",
                cn_body,
                count=1,
            )
            cn_body = cn_body.replace(CN["CUSTOM_GROUP_ID"], CN["CUSTOM_GROUP_ID"])
            cn_body = re.sub(
                r"CUSTOM_GROUP_ID = [^;]+;",
                f"CUSTOM_GROUP_ID = {CN['CUSTOM_GROUP_ID']};",
                cn_body,
            )
            cn_body = re.sub(
                r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
                f"PRODUCT_BUNDLE_IDENTIFIER = {CN['PRODUCT_BUNDLE_IDENTIFIER']};",
                cn_body,
            )
            cn_body = set_entitlements(cn_body, "Runner/Runner-cn.entitlements")
            cn_body = set_display_name(cn_body, CN["INFOPLIST_KEY_CFBundleDisplayName"])
            cn_body = set_bundle_display_name(
                cn_body, CN["INFOPLIST_KEY_CFBundleDisplayName"]
            )
        elif kind == "share":
            cn_body = re.sub(
                r"CUSTOM_GROUP_ID = [^;]+;",
                f"CUSTOM_GROUP_ID = {CN['CUSTOM_GROUP_ID']};",
                cn_body,
            )
            cn_body = re.sub(
                r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
                f"PRODUCT_BUNDLE_IDENTIFIER = {CN['SHARE_EXT_BUNDLE']};",
                cn_body,
            )
            cn_body = set_entitlements(
                cn_body, '"Share Extension/Share Extension-cn.entitlements"'
            )
            cn_body = set_display_name(cn_body, CN["INFOPLIST_KEY_CFBundleDisplayName"])
        elif kind == "tests":
            cn_body = re.sub(
                r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;",
                f"PRODUCT_BUNDLE_IDENTIFIER = {CN['TESTS_BUNDLE']};",
                cn_body,
            )

        config_ids[(kind, mode, "cn")] = cn_id
        new_blocks.append(
            f"\t\t{cn_id} /* {mode}-cn */ = {{\n\t\t\tisa = XCBuildConfiguration;\n"
            f"{cn_body}\n\t\t\tname = {mode}-cn;\n\t\t}};"
        )

    # Replace entire XCBuildConfiguration section
    start = text.index("/* Begin XCBuildConfiguration section */")
    end = text.index("/* End XCBuildConfiguration section */") + len(
        "/* End XCBuildConfiguration section */"
    )
    text = text[:start] + "/* Begin XCBuildConfiguration section */\n" + "\n".join(
        new_blocks
    ) + "\n" + text[end:]

    # Update XCConfigurationList sections
    list_re = re.compile(
        r"(buildConfigurations = \(\n)([\s\S]*?)(\n\t\t\t\);)",
    )

    def reorder_list(match: re.Match[str]) -> str:
        inner = match.group(2)
        ids_in_list = re.findall(r"\t\t\t\t([A-F0-9]{24})", inner)
        if len(ids_in_list) != 3:
            return match.group(0)
        # Map old ids to kinds by scanning config_ids reverse
        ordered = []
        for mode in ("Debug", "Release", "Profile"):
            for flavor in ("cn", "intl"):
                for (k, m, f), i in config_ids.items():
                    if m == mode and f == flavor and i in ids_in_list:
                        ordered.append(i)
                        break
        if len(ordered) != 6:
            return match.group(0)
        lines = "".join(f"\n\t\t\t\t{i} /* {m}-{f} */," for i, m, f in [
            (config_ids[(k, m, f)], m, f)
            for m in ("Debug", "Release", "Profile")
            for f in ("cn", "intl")
            for k in ("project", "runner", "share", "tests")
            if (k, m, f) in config_ids and config_ids[(k, m, f)] in ids_in_list
        ][:6])
        # Simpler: rebuild from first id's target kind
        first = ids_in_list[0]
        kind = None
        for (k, m, f), i in config_ids.items():
            if i == first:
                kind = k
                break
        if kind is None:
            return match.group(0)
        lines = ""
        for mode in ("Debug", "Release", "Profile"):
            for flavor in ("cn", "intl"):
                cid = config_ids.get((kind, mode, flavor))
                if cid:
                    lines += f"\n\t\t\t\t{cid} /* {mode}-{flavor} */,"
        return match.group(1) + lines + match.group(3)

    # Fix configuration lists - find each list's 3 original IDs and expand
    for list_name in (
        "RunnerTests",
        "PBXProject",
        "PBXNativeTarget \"Runner\"",
        "Share Extension",
    ):
        pass

    # Manual list updates by known list IDs from file
    lists = {
        "331C8087294A63A400263BE5": "tests",
        "97C146E91CF9000F007C117D": "project",
        "97C147051CF9000F007C117D": "runner",
        "9A7ADFB72F697EA6008C616B": "share",
    }
    for list_id, kind in lists.items():
        pattern = (
            rf"({list_id} /\* Build configuration list[^*]+\*/ = \{{\n"
            rf"\t\t\tisa = XCConfigurationList;\n"
            rf"\t\t\tbuildConfigurations = \(\n)([\s\S]*?)(\n\t\t\t\);)"
        )
        m = re.search(pattern, text)
        if not m:
            continue
        lines = ""
        for mode in ("Debug", "Release", "Profile"):
            for flavor in ("cn", "intl"):
                cid = config_ids[(kind, mode, flavor)]
                lines += f"\n\t\t\t\t{cid} /* {mode}-{flavor} */,"
        text = text[: m.start(2)] + lines + text[m.end(2) :]

    PBX.write_text(text, encoding="utf-8")
    print(f"Updated {PBX}")


if __name__ == "__main__":
    main()
