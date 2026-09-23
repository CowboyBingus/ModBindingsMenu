"""Build the native input action resource and discoverable menu addon."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import uuid
import zipfile


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "BingusSharedLoader" / "scripts"))
from archive import ARCHIVE, make_archive, resource_hash  # noqa: E402
from build_addon import entry_source  # noqa: E402


HERE = Path(__file__).resolve().parents[1]
BASE_CONFIG = Path(os.environ.get("HD2_INPUT_CONFIG", str(HERE / "research" / "input.config")))
VERSION = "1.0"
CONFIG_SHA256 = "E509D85AC3603721E5AFE5686C7041798587A108AA86E2DA961A2EA451881A1B"
CONFIG_NAME = resource_hash("content/input")
CONFIG_TYPE = resource_hash("config")
LUA_NAME = "mods/cowboybingus/mod_bindings_menu"
GUID = "e40fc537-c2a2-493b-ad0f-2255c6a0174e"
SLOTS = 2


def u32(data: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def put_u32(data: bytearray, offset: int, value: int) -> None:
    struct.pack_into("<I", data, offset, value)


def padded_string(data: bytearray, value: str) -> int:
    offset = len(data)
    data.extend(value.encode("utf-8") + b"\0")
    data.extend(b"\0" * (-len(data) % 4))
    return offset


def extend_input_config(base: bytes) -> bytes:
    data = bytearray(base)
    assert len(base) == 52128, "input.config size changed"
    assert u32(base, 0) == 6 and u32(base, 8) == 14, "input.config root changed"
    root = 12 + 13 * 12
    key, kind, group = struct.unpack_from("<III", base, root)
    assert base[key:key + 10] == b"Debugmenu\0" and kind == 6
    assert u32(base, group) == 2
    select_key, select_kind, select_value = struct.unpack_from("<III", base, group + 4)
    open_key, open_kind, open_value = struct.unpack_from("<III", base, group + 16)
    assert base[select_key:select_key + 7] == b"Select\0"
    assert base[open_key:open_key + 5] == b"Open\0"
    assert select_kind == open_kind == 5
    assert u32(base, open_value) == 6 and u32(base, open_value + 4) == 4
    # Bind the already registered Debugmenu.Select action to Tab. This input
    # context is dormant in normal play; the addon observes its binding.
    assert u32(base, select_value) == 6 and u32(base, select_value + 4) == 4
    keyboard_press = u32(base, select_value + 8 + 2 * 4)
    assert u32(base, keyboard_press) == 5
    assert base[u32(base, keyboard_press + 4):][:8] == b"trigger\0"
    tab = padded_string(data, "tab")
    mapping = len(data)
    data.extend(base[keyboard_press:keyboard_press + 64])
    for item in range(5):
        descriptor = mapping + 4 + item * 12
        input_key = u32(data, descriptor)
        if base[input_key:input_key + 6] == b"input\0":
            put_u32(data, descriptor + 8, tab)
            break
    else:
        raise AssertionError("Keyboard mapping has no input field")
    value = len(data)
    data.extend(struct.pack("<III", 6, 1, mapping))
    put_u32(data, group + 12, value)
    return bytes(data)


def typed_archive(name_hash: int, type_hash: int, payload: bytes) -> bytes:
    # One resource per archive keeps the Stingray patch type directory simple.
    count = 1
    offset = (104 + 80 * count + 15) & ~15
    final_size = (offset + len(payload) + 15) & ~15
    header = struct.pack("<III20sQQ24s", 0xF0000011, 1, count,
                         b"", final_size, 0, b"")
    type_record = struct.pack("<IIQIIII", 0, 0, type_hash, count, 0, 16, 16)
    entry = struct.pack("<7Q6I", name_hash, type_hash, offset, 0, 0, 0, 0,
                        len(payload), 0, 0, 16, 16, 0)
    body = header + type_record + entry + b"\0" * (offset - 184) + payload
    return body + b"\0" * (-len(body) % 16)


def build(output: Path) -> Path:
    base = BASE_CONFIG.read_bytes()
    digest = hashlib.sha256(base).hexdigest().upper()
    if digest != CONFIG_SHA256:
        raise ValueError(f"Unexpected input.config SHA256 {digest}")
    config = extend_input_config(base)
    source = entry_source(LUA_NAME, (HERE / "src" / "mod_bindings_menu.lua").read_bytes())
    lua = struct.pack("<II", len(source), 2) + source
    manifest = {
        "Version": 1, "Guid": str(uuid.UUID(GUID)), "Name": "Mod Bindings Menu v" + VERSION,
        "IconPath": "thumbnail.png",
        "Description": "Adds native mod binding rows. Keyboard activation supported; controller activation pending. Requires Bingus Shared Loader v16+.",
        "Options": [{"Name": "Mod Bindings Menu", "Description": "Native mod binding slots", "Image": "thumbnail.png", "Include": ["Addon"]}],
    }
    files = {
        "INSTALL.txt": (HERE / "INSTALL.txt").read_bytes(),
        "thumbnail.png": (HERE / "assets" / "thumbnail.png").read_bytes(),
        "manifest.json": (json.dumps(manifest, indent=2) + "\n").encode(),
        "Addon/" + ARCHIVE: typed_archive(CONFIG_NAME, CONFIG_TYPE, config),
        "Addon/" + ARCHIVE + ".stream": b"",
        "Addon/" + ARCHIVE + ".gpu_resources": b"",
        "Addon/9ba626afa44a3aa3.patch_1": make_archive({resource_hash(LUA_NAME): lua}),
        "Addon/9ba626afa44a3aa3.patch_1.stream": b"",
        "Addon/9ba626afa44a3aa3.patch_1.gpu_resources": b"",
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for path, payload in sorted(files.items()):
            info = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            package.writestr(info, payload)
    return output


if __name__ == "__main__":
    path = HERE / "releases" / f"Mod-Bindings-Menu-v{VERSION}.zip"
    print(build(path))
