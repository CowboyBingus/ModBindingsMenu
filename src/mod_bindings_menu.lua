-- HD2-Addon: mods/cowboybingus/mod_bindings_menu
-- Native bindings-page extension for Steam build 25327279.
if rawget(_G, 'ModBindingsMenu') then return end
local ffi = require('ffi')
local bit = require('bit')

ffi.cdef [[
typedef unsigned char MBM_u8;
typedef unsigned short MBM_u16;
typedef unsigned int MBM_u32;
typedef unsigned long long MBM_u64;
void *GetModuleHandleA(const char *name);
MBM_u32 GetModuleFileNameW(void *module, MBM_u16 *path, MBM_u32 capacity);
void *GetCurrentProcess(void);
int ReadProcessMemory(void *process, const void *address, void *buffer,
                      size_t size, size_t *received);
int VirtualProtect(void *address, size_t size, MBM_u32 protection, MBM_u32 *old);
short GetAsyncKeyState(int key);
void *CreateFileW(const MBM_u16 *path, MBM_u32 access, MBM_u32 share,
                  void *security, MBM_u32 disposition, MBM_u32 flags, void *template_file);
int ReadFile(void *file, void *buffer, MBM_u32 size, MBM_u32 *received, void *overlapped);
int CloseHandle(void *handle);
int BCryptOpenAlgorithmProvider(void **algorithm, const MBM_u16 *name,
                                const MBM_u16 *provider, MBM_u32 flags);
int BCryptCloseAlgorithmProvider(void *algorithm, MBM_u32 flags);
int BCryptCreateHash(void *algorithm, void **hash, void *object, MBM_u32 object_size,
                     const void *secret, MBM_u32 secret_size, MBM_u32 flags);
int BCryptHashData(void *hash, const void *data, MBM_u32 size, MBM_u32 flags);
int BCryptFinishHash(void *hash, void *digest, MBM_u32 size, MBM_u32 flags);
int BCryptDestroyHash(void *hash);
]]

local kernel32, user32, bcrypt = ffi.load('kernel32'), ffi.load('user32'), ffi.load('bcrypt')
local process = kernel32.GetCurrentProcess()
local loader = rawget(_G, 'CowboyBingusModLoader')
local log_file
if loader and type(loader.open_log) == 'function' then
    pcall(function() log_file = loader.open_log('ModBindingsMenu.log') end)
end
local function note(message)
    if log_file then pcall(function() log_file:write(message .. '\n'); log_file:flush() end) end
end

local GAME_SHA256 = '73374BD4E38386BEB9A23BEF480082B67D457EBC77485FBEC5F488B4E95E201F'
local EXE_SHA256 = 'D8E23968D1412B07E06785321727D63EDF74E711214D6F6ADEB3BFCA95CA6827'
local INPUT_OWNER_PTR_RVA = 0x347cf18
local MENU_SYSTEM_PTR_RVA = 0x347ce38
local UI_STATE_PTR_RVA = 0x347ce28
local ACTION_LABELS_RVA = 0x26438a0
local BUILD_ROWS_RVA = 0x1812870
local INPUT_KEY_TABLE_RVA = 0x263d1f0
local MODS_TITLE_PTR_RVA = 0x3328420
local MODS_TITLE_ID = 0x781e104c
local GROUP, FIRST_ACTION, SLOTS = 12, 1, 2
local SLOT_ACTIONS = {1, 0}
local ORIGINAL_LABELS = {0x62ea38bf, 0x82fbdcb2}
local MAP_LABEL = 0xb46c8096 -- Game-localized "OPEN MAP"
local ROW_LIST_OFFSET = 338344
local ROW_STRIDE, ROW_START = 24784, 7856
local state = {initialized = false, base = nil, build_rows = nil,
               screen = nil, last_action = nil,
               registry = {}, order = {}, errors = 0, input_logged = false,
               buckets = {}, title_active = false,
               mods_text = ffi.new('char[5]', 'MODS')}

local function read(address, size)
    local buffer, received = ffi.new('MBM_u8[?]', size), ffi.new('size_t[1]')
    if kernel32.ReadProcessMemory(process, ffi.cast('const void *', address),
            buffer, size, received) == 0 or tonumber(received[0]) ~= size then return nil end
    return ffi.string(buffer, size)
end
local function u32(blob)
    if not blob or #blob ~= 4 then return nil end
    local number = ffi.new('MBM_u32[1]')
    ffi.copy(number, blob, 4)
    return tonumber(number[0])
end
local function u64(blob)
    if not blob or #blob ~= 8 then return nil end
    local number = ffi.new('MBM_u64[1]')
    ffi.copy(number, blob, 8)
    return tonumber(number[0])
end
local function pointer(blob)
    local value = u64(blob)
    if not value then return nil end
    if value < 0x10000 or value >= 0x800000000000 then return nil end
    return value
end
local function module_sha256(module)
    local path = ffi.new('MBM_u16[32768]')
    local length = kernel32.GetModuleFileNameW(module, path, 32768)
    assert(length > 0 and length < 32768, 'cannot resolve module path')
    local file = kernel32.CreateFileW(path, 0x80000000, 7, nil, 3, 0x08000000, nil)
    assert(file ~= ffi.NULL and file ~= ffi.cast('void *', -1), 'cannot read module file')
    local algorithm, hash = ffi.new('void *[1]'), ffi.new('void *[1]')
    local ok, result = pcall(function()
        local name = ffi.new('MBM_u16[7]', {83, 72, 65, 50, 53, 54, 0})
        assert(bcrypt.BCryptOpenAlgorithmProvider(algorithm, name, nil, 0) == 0)
        assert(bcrypt.BCryptCreateHash(algorithm[0], hash, nil, 0, nil, 0, 0) == 0)
        local buffer, received = ffi.new('MBM_u8[1048576]'), ffi.new('MBM_u32[1]')
        while true do
            assert(kernel32.ReadFile(file, buffer, 1048576, received, nil) ~= 0)
            if received[0] == 0 then break end
            assert(bcrypt.BCryptHashData(hash[0], buffer, received[0], 0) == 0)
        end
        local digest, parts = ffi.new('MBM_u8[32]'), {}
        assert(bcrypt.BCryptFinishHash(hash[0], digest, 32, 0) == 0)
        for i = 0, 31 do parts[#parts + 1] = string.format('%02X', digest[i]) end
        return table.concat(parts)
    end)
    if hash[0] ~= nil then bcrypt.BCryptDestroyHash(hash[0]) end
    if algorithm[0] ~= nil then bcrypt.BCryptCloseAlgorithmProvider(algorithm[0], 0) end
    kernel32.CloseHandle(file)
    if not ok then error(result) end
    return result
end

local function make_writable(address, size, fn)
    local old = ffi.new('MBM_u32[1]')
    assert(kernel32.VirtualProtect(ffi.cast('void *', address), size, 0x04, old) ~= 0,
           'VirtualProtect failed')
    local ok, result = pcall(fn)
    local ignored = ffi.new('MBM_u32[1]')
    kernel32.VirtualProtect(ffi.cast('void *', address), size, old[0], ignored)
    if not ok then error(result) end
end

local function action_bucket(action)
    if not state.base then return nil end
    local cached = state.buckets[action]
    local code = GROUP * 65536 + action
    if cached and u32(read(cached, 4)) == code then return cached end
    local owner = pointer(read(state.base + INPUT_OWNER_PTR_RVA, 8))
    if not owner then return nil end
    local buckets = pointer(read(owner + 686800, 8))
    local capacity = u32(read(owner + 686808, 4))
    if not buckets or capacity ~= 256 then return nil end
    for index = 0, capacity - 1 do
        local bucket = buckets + index * 328
        if u32(read(bucket, 4)) == code then
            state.buckets[action] = bucket
            return bucket
        end
    end
    return nil
end
local function action_present(action) return action_bucket(action) ~= nil end

local function log_input_probe()
    if state.input_logged then return end
    state.input_logged = true
    local bucket = action_bucket(FIRST_ACTION)
    if bucket then
        local count = u32(read(bucket + 4, 4)) or 0
        local mappings = {}
        for index = 0, math.min(count, 8) - 1 do
            local bytes = read(bucket + 8 + index * 20, 20)
            if bytes then
                local hex = bytes:gsub('.', function(c) return string.format('%02X', c:byte()) end)
                mappings[#mappings + 1] = hex
            end
        end
        note('Slot 1 native mappings: ' .. table.concat(mappings, ' '))
    end
    local engine = rawget(_G, 'stingray')
    local keyboard = engine and engine.Keyboard
    if keyboard then
        for _, name in ipairs({'tab', 'enter'}) do
            local ok, id = pcall(keyboard.button_id, name)
            if ok then note('Keyboard button ID ' .. name .. ': ' .. tostring(id)) end
        end
        if type(keyboard.button_name) == 'function' then
            for _, id in ipairs({76, 88}) do
                local ok, name = pcall(keyboard.button_name, id)
                if ok then note('Keyboard button name ' .. id .. ': ' .. tostring(name)) end
            end
        end
    end
end

local function initialize()
    if state.initialized then return end
    state.initialized = true
    local ok, err = pcall(function()
        local game, exe = kernel32.GetModuleHandleA('game.dll'), kernel32.GetModuleHandleA(nil)
        assert(game ~= nil and game ~= ffi.NULL and exe ~= nil and exe ~= ffi.NULL)
        assert(module_sha256(game) == GAME_SHA256, 'unsupported game.dll build')
        assert(module_sha256(exe) == EXE_SHA256, 'unsupported helldivers2.exe build')
        state.base = tonumber(ffi.cast('MBM_u64', game))
        assert(read(state.base + BUILD_ROWS_RVA, 13) ==
               '\x48\x8b\xc4\x53\x41\x56\x48\x81\xec\xd8\x00\x00\x00',
               'binding list builder changed')
        assert(u32(read(state.base + ACTION_LABELS_RVA +
               (GROUP * 97 + FIRST_ACTION) * 4, 4)) == ORIGINAL_LABELS[1],
               'debug input label table changed')
    end)
    if ok then note('Native binding layout verified for current game build.')
    else state.base = nil; note('Mod binding integration unavailable: ' .. tostring(err)) end
end

local function activate_actions()
    if state.build_rows or not action_present(FIRST_ACTION) then return end
    state.build_rows = ffi.cast('void (__fastcall *)(void *, const void *)',
                                state.base + BUILD_ROWS_RVA)
    note('Mod input actions loaded; native keyboard and controller bindings ready.')
    log_input_probe()
end

local function mods_title(active)
    if not state.base then return end
    local address = state.base + MODS_TITLE_PTR_RVA
    local current = read(address, 8)
    if not current then return end
    local ours = ffi.cast('MBM_u64', state.mods_text)
    if active and not state.title_active then
        if current ~= string.rep('\0', 8) then
            note('MODS title slot is already in use; leaving localization unchanged.')
            return
        end
        make_writable(address, 8, function()
            ffi.cast('MBM_u64 *', address)[0] = ours
        end)
        state.title_active = true
    elseif not active and state.title_active then
        if u64(current) == tonumber(ours) then
            make_writable(address, 8, function()
                ffi.cast('MBM_u64 *', address)[0] = 0
            end)
        end
        state.title_active = false
    end
end

local api = {api = 1}
function api.register_binding(id, label_id, slot)
    if type(id) ~= 'string' or id == '' or type(label_id) ~= 'number'
       or label_id < 1 or label_id >= 0x100000000
       or type(slot) ~= 'number' or slot < 1 or slot > SLOTS
       or slot % 1 ~= 0 then return false, 'invalid binding registration' end
    local existing = state.registry[id]
    if existing then
        if existing.slot == slot and existing.label_id == label_id then return true end
        return false, 'binding already registered differently'
    end
    for _, record in ipairs(state.order) do
        if record.slot == slot then return false, 'slot already in use' end
    end
    local record = {id = id, label_id = label_id, slot = slot,
                    action = SLOT_ACTIONS[slot]}
    state.registry[id] = record
    state.order[#state.order + 1] = record
    table.sort(state.order, function(a, b) return a.slot < b.slot end)
    note('Registered ' .. id .. ' in mod slot ' .. slot .. '.')
    return true
end
function api.is_down(id)
    local record = state.registry[id]
    if not record or not state.build_rows then return nil end
    local bucket = action_bucket(record.action)
    if not bucket then return nil end
    local count = u32(read(bucket + 4, 4))
    if not count or count > 16 then return nil end
    for index = 0, count - 1 do
        local mapping = bucket + 8 + index * 20
        local kind = u32(read(mapping, 4))
        local input = u32(read(mapping + 4, 4))
        local device = u32(read(mapping + 8, 4))
        if kind and input and bit.band(kind, 0xf) == 3
           and bit.band(bit.rshift(kind, 4), 0xf) == 4
           and device == 0
           and input >= 49 and input <= 304
           and u32(read(state.base + INPUT_KEY_TABLE_RVA + input * 4, 4)) == 0 then
            local key = input - 49
            local engine = rawget(_G, 'stingray')
            local keyboard = engine and engine.Keyboard
            if keyboard and type(keyboard.button) == 'function' then
                local ok, value = pcall(keyboard.button, key)
                if ok and (value == true or type(value) == 'number' and value > 0.5) then
                    return true
                end
            end
            if bit.band(user32.GetAsyncKeyState(key), 0x8000) ~= 0 then return true end
        end
    end
    return false
end
function api.ready() return state.build_rows ~= nil end
_G.ModBindingsMenu = api

local function active_screen()
    local ui = pointer(read(state.base + UI_STATE_PTR_RVA, 8))
    if not ui then return nil end
    local depth = u32(read(ui + 0x429c + 20, 4))
    if not depth or depth < 1 or depth > 5
       or u32(read(ui + 0x429c + 4 * (depth - 1), 4)) ~= 26 then return nil end
    local menu = pointer(read(state.base + MENU_SYSTEM_PTR_RVA, 8))
    if not menu then return nil end
    return pointer(read(menu + 208, 8))
end
local function extend_page(screen)
    if u32(read(screen + 8, 4)) ~= 0 or #state.order == 0 then return end
    local listing = screen + ROW_LIST_OFFSET
    local visible = u32(read(listing + 2411916, 4))
    local requested = u32(read(listing + 2411928, 4))
    if not visible or visible < 1 or visible > 80 or requested ~= visible then return end
    local last_row = listing + ROW_START + ROW_STRIDE * (visible - 1)
    local final_code = GROUP * 65536 + state.order[#state.order].action
    if u32(read(last_row + 24760, 4)) == final_code then return end
    if visible ~= 44 and visible ~= 49 then return end
    local count = visible + 1 + #state.order
    assert(count <= 97, 'binding list capacity exceeded')
    local rows = ffi.new('MBM_u32[?]', count * 3)
    -- Recreate the descriptors the game already displayed. The keyboard
    -- page has 49 visible General rows; the controller page has 44.
    for index = 0, visible - 1 do
        local row = listing + ROW_START + ROW_STRIDE * index
        local kind = u32(read(row + 24752, 4))
        if kind == 4 then
            local header = u32(read(row + 4264 + 272, 4))
            assert(header and header ~= 0, 'binding section label unavailable')
            rows[index * 3] = 13
            rows[index * 3 + 1] = 0
            rows[index * 3 + 2] = header
        elseif kind == 1 or kind == 2 then
            local code = u32(read(row + 24760, 4))
            assert(code and code ~= 0xffffffff and
                   math.floor(code / 65536) <= 12 and code % 65536 < 97,
                   'binding action code changed')
            rows[index * 3] = math.floor(code / 65536)
            rows[index * 3 + 1] = code % 65536
            rows[index * 3 + 2] = 0
        else
            error('unknown binding row kind ' .. tostring(kind))
        end
    end
    rows[visible * 3] = 13
    rows[visible * 3 + 1] = 0
    mods_title(true)
    rows[visible * 3 + 2] = MODS_TITLE_ID
    for index, record in ipairs(state.order) do
        assert(action_present(record.action), 'mod input action absent: ' .. record.id)
        local label_address = state.base + ACTION_LABELS_RVA +
                              (GROUP * 97 + record.action) * 4
        local previous = u32(read(label_address, 4))
        assert(previous == ORIGINAL_LABELS[record.slot] or previous == record.label_id,
               'mod action label slot claimed')
        if previous ~= record.label_id then
            make_writable(label_address, 4, function()
                ffi.cast('MBM_u32 *', label_address)[0] = record.label_id
            end)
        end
        local j = visible + index
        rows[j * 3] = GROUP
        rows[j * 3 + 1] = record.action
        rows[j * 3 + 2] = 0
    end
    -- The game's own list constructor clears, rebuilds and lays out rows.
    ffi.cast('MBM_u32 *', listing + 2411928)[0] = count
    state.build_rows(ffi.cast('void *', listing), rows)
    state.screen = screen
    note('Added MODS section with ' .. #state.order ..
         ' native mod bindings (base rows ' .. visible .. ').')
end

local function step()
    if not state.initialized then initialize() end
    if not state.base then return end
    activate_actions()
    if not state.build_rows then return end
    local screen = active_screen()
    if screen then extend_page(screen)
    else mods_title(false) end
end
local previous_update = rawget(_G, 'update')
update = function(dt)
    local ok, err = pcall(step)
    if not ok then
        state.errors = state.errors + 1
        if state.errors <= 8 then note('Menu update error: ' .. tostring(err)) end
    end
    if type(previous_update) == 'function' then return previous_update(dt) end
end
note('Mod Bindings Menu initialized; waiting for native input actions.')
