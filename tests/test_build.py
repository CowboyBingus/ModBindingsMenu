"""Check that the resource patch preserves vanilla actions and adds reserved slots."""

import importlib.util
from pathlib import Path
import struct
import zipfile


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("mod_bindings_build", ROOT / "scripts" / "build.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


def members(data, offset):
    count = build.u32(data, offset)
    return [struct.unpack_from("<III", data, offset + 4 + i * 12) for i in range(count)]


base = build.BASE_CONFIG.read_bytes()
patched = build.extend_input_config(base)
assert patched[:164] == base[:164]
root = 12 + 13 * 12
assert patched[root:root + 12] == base[root:root + 12]
old_group = build.u32(base, root + 8)
new_group = build.u32(patched, root + 8)
assert new_group == old_group
assert len(members(patched, new_group)) == 2
assert members(patched, new_group)[1] == members(base, old_group)[1]
first = members(patched, new_group)[0][2]
assert first >= len(base)
assert build.u32(patched, first) == 6
assert build.u32(patched, first + 4) == 1
mapping = build.u32(patched, first + 8)
fields = members(patched, mapping)
assert any(patched[key:key + 6] == b"input\0" and patched[val:val + 4] == b"tab\0"
           for key, kind, val in fields)
assert patched[:old_group + 12] == base[:old_group + 12]

package = build.build(ROOT / "releases" / f"Mod-Bindings-Menu-v{build.VERSION}.zip")
with zipfile.ZipFile(package) as archive:
    assert archive.read("INSTALL.txt") == (ROOT / "INSTALL.txt").read_bytes()
    assert archive.read("thumbnail.png") == (ROOT / "assets" / "thumbnail.png").read_bytes()
    config_patch = archive.read("Addon/9ba626afa44a3aa3.patch_0")
    lua_patch = archive.read("Addon/9ba626afa44a3aa3.patch_1")
    assert struct.unpack_from("<Q", config_patch, 104)[0] == build.CONFIG_NAME
    assert struct.unpack_from("<Q", config_patch, 112)[0] == build.CONFIG_TYPE
    assert struct.unpack_from("<Q", lua_patch, 104)[0] == build.resource_hash(build.LUA_NAME)
print("Input config extension and addon archives OK")
