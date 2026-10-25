-- AFUI v1.9.29
-- Requires SuperBLT and BeardLib MenuUI.
-- End: open/close. Esc: close.
-- Standalone AFUI implementation; no code is copied from the AFUI repository.

if not Hooks then
    return
end

-- All persistent mod options are stored together in mods/saves/AFUI.json.
-- Older version files are read once for backwards-compatible migration.
SimpleBeardLibFullscreenSettings = SimpleBeardLibFullscreenSettings or {
    loaded = false,
    data = {}
}

local function afui_settings_path()
    return (type(SavePath) == "string" and SavePath ~= "" and SavePath or "mods/saves/") .. "AFUI.json"
end

local function read_json_settings(path)
    if not io then
        return nil, false, false
    end

    local exists = true
    if type(io.file_is_readable) == "function" then
        local readable_ok, readable = pcall(io.file_is_readable, path)
        if not readable_ok then
            return nil, false, false
        end
        exists = readable == true
        if not exists then
            return nil, true, false
        end
    end

    if type(io.load_as_json) == "function" then
        local load_ok, data = pcall(io.load_as_json, path)
        if load_ok and type(data) == "table" then
            return data, true, exists
        end
        if log and exists then
            log("[SimpleBeardLibFullscreenMenu] Could not decode settings file: " .. tostring(path))
        end
        return nil, exists == false, exists
    end

    if type(io.open) == "function" and json and type(json.decode) == "function" then
        local open_ok, data = pcall(function()
            local file = io.open(path, "r")
            if not file then
                return nil
            end
            local contents = file:read("*a")
            file:close()
            return json.decode(contents)
        end)
        if open_ok and type(data) == "table" then
            return data, true, exists
        end
        return nil, exists == false, exists
    end

    return nil, false, exists
end

local load_afui_settings
local save_afui_settings

save_afui_settings = function()
    local storage = SimpleBeardLibFullscreenSettings
    if not storage.loaded then
        local _, ready = load_afui_settings()
        if not ready then
            return false
        end
    end

    local path = afui_settings_path()
    local data = storage.data or {}
    if io and type(io.save_as_json) == "function" then
        local save_ok, result = pcall(io.save_as_json, data, path)
        if save_ok and result ~= false then
            if log then
                log("[SimpleBeardLibFullscreenMenu] Saved unified AFUI settings.")
            end
            return true
        end
    end

    if io and type(io.open) == "function" and json and type(json.encode) == "function" then
        local save_ok, result = pcall(function()
            local file = io.open(path, "w+")
            if not file then
                return false
            end
            file:write(json.encode(data))
            file:close()
            return true
        end)
        if save_ok and result then
            if log then
                log("[SimpleBeardLibFullscreenMenu] Saved unified AFUI settings with fallback writer.")
            end
            return true
        end
    end

    if log then
        log("[SimpleBeardLibFullscreenMenu] ERROR: Could not save unified settings to " .. tostring(path))
    end
    return false
end

load_afui_settings = function()
    local storage = SimpleBeardLibFullscreenSettings
    if storage.loaded then
        return storage.data, true
    end

    local data, ready, exists = read_json_settings(afui_settings_path())
    if not ready or (exists and type(data) ~= "table") then
        return nil, false
    end
    data = type(data) == "table" and data or {}
    local migrated = false

    -- Import the three files used by versions 1.9.20-1.9.22 without discarding
    -- any sections already present in AFUI.json.
    if type(data.spoofer) ~= "table" then
        local old, old_ready = read_json_settings((type(SavePath) == "string" and SavePath ~= "" and SavePath or "mods/saves/") .. "SimpleBeardLibFullscreen_settings.json")
        if old_ready and type(old) == "table" and (old.enabled ~= nil or old.level ~= nil or old.rank ~= nil) then
            data.spoofer = { enabled = old.enabled, level = old.level, rank = old.rank }
            migrated = true
        end
    end

    if data.fov == nil then
        local old, old_ready = read_json_settings((type(SavePath) == "string" and SavePath ~= "" and SavePath or "mods/saves/") .. "SimpleBeardLibFullscreen_fov.json")
        if old_ready and type(old) == "table" and old.fov ~= nil then
            data.fov = old.fov
            migrated = true
        end
    end

    if type(data.mod_hider) ~= "table" then
        local old, old_ready = read_json_settings((type(SavePath) == "string" and SavePath ~= "" and SavePath or "mods/saves/") .. "SimpleBeardLibFullscreen_mod_hider.json")
        if old_ready and type(old) == "table" and (old.enabled ~= nil or type(old.keywords) == "table") then
            data.mod_hider = { enabled = old.enabled, keywords = old.keywords }
            migrated = true
        end
    end

    storage.data = data
    storage.loaded = true
    if migrated then
        if log then
            log("[SimpleBeardLibFullscreenMenu] Migrating older settings into AFUI.json.")
        end
        save_afui_settings()
    end
    return storage.data, true
end

-- Both mod.txt hooks point to this file. The first load registers the menu;
-- the NetworkPeer hook load installs the network wrapper, without duplicating menu creation.
SimpleBeardLibFullscreenSpoofer = SimpleBeardLibFullscreenSpoofer or {
    enabled = false,
    level = 100,
    rank = 0,
    settings_loaded = false,
    hook_installed = false,
    menu_hook_registered = false
}

local function clamp_spoofer_value(value, minimum, maximum, fallback)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return fallback
    end
    return math.max(minimum, math.min(maximum, math.floor(number)))
end

local function load_shared_spoofer_settings()
    local state = SimpleBeardLibFullscreenSpoofer
    if state.settings_loaded then
        return
    end

    local all_settings, ready = load_afui_settings()
    if not ready then
        return
    end

    local data = type(all_settings.spoofer) == "table" and all_settings.spoofer or {}
    state.enabled = data.enabled == true
    state.level = clamp_spoofer_value(data.level, 0, 100, 100)
    state.rank = clamp_spoofer_value(data.rank, 0, 500, 0)
    state.settings_loaded = true
    if log then
        log("[SimpleBeardLibFullscreenMenu] Unified AFUI spoofer settings loaded.")
    end
end

local function install_networkpeer_spoofer_hook()
    local state = SimpleBeardLibFullscreenSpoofer
    if state.hook_installed then
        return true
    end
    if not NetworkPeer or type(NetworkPeer.send_after_load) ~= "function" then
        return false
    end

    load_shared_spoofer_settings()
    local original_send_after_load = NetworkPeer.send_after_load
    local unpack_args = unpack or (table and table.unpack)

    NetworkPeer.send_after_load = function(self, message_type, ...)
        local current_state = SimpleBeardLibFullscreenSpoofer
        if current_state and current_state.enabled
            and (message_type == "sync_profile" or message_type == "lobby_info") then
            local arg_count = select("#", ...)
            if arg_count >= 2 then
                local forwarded_args = {...}
                forwarded_args[1] = clamp_spoofer_value(current_state.level, 0, 100, 100)
                forwarded_args[2] = clamp_spoofer_value(current_state.rank, 0, 500, 0)
                if unpack_args then
                    return original_send_after_load(self, message_type, unpack_args(forwarded_args, 1, arg_count))
                end
            end
        end

        return original_send_after_load(self, message_type, ...)
    end

    state.hook_installed = true
    if log then
        log("[SimpleBeardLibFullscreenMenu] NetworkPeer.send_after_load hook installed from main.lua.")
    end
    return true
end

-- This runs on both SuperBLT hook points. It installs only once when NetworkPeer exists.
SimpleBeardLibFullscreenSpoofer.install_networkpeer_hook = install_networkpeer_spoofer_hook
install_networkpeer_spoofer_hook()

-- Equipment/outfit spoofer. This changes the loadout serialized for other peers,
-- not the player's actual crafted inventory or currently equipped weapons.
SimpleBeardLibFullscreenEquipmentSpoofer = SimpleBeardLibFullscreenEquipmentSpoofer or {
    enabled = false,
    primary = "amcar",
    secondary = "glock_17",
    melee = "current",
    deployable = "current",
    secondary_deployable = "current",
    grenade = "current",
    settings_loaded = false,
    blackmarket_hooks_installed = false,
    network_hook_installed = false,
    originals = {}
}

local function load_equipment_spoofer_settings()
    local state = SimpleBeardLibFullscreenEquipmentSpoofer
    if state.settings_loaded then
        return true
    end

    local all_settings, ready = load_afui_settings()
    if not ready then
        return false
    end
    local data = type(all_settings.equipment_spoofer) == "table" and all_settings.equipment_spoofer or {}
    state.enabled = data.enabled == true
    state.primary = type(data.primary) == "string" and data.primary or "amcar"
    state.secondary = type(data.secondary) == "string" and data.secondary or "glock_17"
    state.melee = type(data.melee) == "string" and data.melee or "current"
    state.deployable = type(data.deployable) == "string" and data.deployable or "current"
    state.secondary_deployable = type(data.secondary_deployable) == "string" and data.secondary_deployable or "current"
    state.grenade = type(data.grenade) == "string" and data.grenade or "current"
    state.settings_loaded = true
    return true
end

local function save_equipment_spoofer_settings()
    local state = SimpleBeardLibFullscreenEquipmentSpoofer
    local all_settings, ready = load_afui_settings()
    if not ready then
        return false
    end

    all_settings.equipment_spoofer = {
        enabled = state.enabled == true,
        primary = state.primary or "amcar",
        secondary = state.secondary or "glock_17",
        melee = state.melee or "current",
        deployable = state.deployable or "current",
        secondary_deployable = state.secondary_deployable or "current",
        grenade = state.grenade or "current"
    }
    state.settings_loaded = true
    local ok = save_afui_settings()
    if log then
        log("[AFUI] Equipment spoofer settings " .. (ok and "saved." or "could not be saved."))
    end
    return ok
end

local function equipment_spoofer_active()
    load_equipment_spoofer_settings()
    local state = SimpleBeardLibFullscreenEquipmentSpoofer
    return Global and Global.IS_SENDING_OUTFIT == true and state and state.enabled == true
end

local function make_spoofed_weapon(weapon_id)
    if type(weapon_id) ~= "string" or not tweak_data or not tweak_data.weapon or not tweak_data.weapon[weapon_id] then
        return nil
    end
    if not managers or not managers.weapon_factory then
        return nil
    end

    local factory_manager = managers.weapon_factory
    local ok_factory, factory_id = pcall(factory_manager.get_factory_id_by_weapon_id, factory_manager, weapon_id)
    if not ok_factory or not factory_id then
        return nil
    end
    local ok_blueprint, blueprint = pcall(factory_manager.get_default_blueprint_by_factory_id, factory_manager, factory_id)
    if not ok_blueprint or type(blueprint) ~= "table" then
        return nil
    end

    return {
        weapon_id = weapon_id,
        equipped = true,
        global_values = {},
        factory_id = factory_id,
        blueprint = afui_safe_clone(blueprint)
    }
end

local function get_spoofed_deployable(slot)
    local state = SimpleBeardLibFullscreenEquipmentSpoofer
    local key = tonumber(slot) == 2 and "secondary_deployable" or "deployable"
    local id = state and state[key]
    if id == "current" or id == nil then
        return false, nil
    end
    if id == "none" then
        return true, nil
    end
    if type(id) == "string" and tweak_data and tweak_data.equipments and tweak_data.equipments[id]
        and tweak_data.equipments[id].quantity then
        return true, id
    end
    return false, nil
end

local function install_equipment_spoofer_blackmarket_hooks()
    local state = SimpleBeardLibFullscreenEquipmentSpoofer
    if state.blackmarket_hooks_installed or not BlackMarketManager then
        return false
    end

    local methods = state.originals
    local installed_any = false

    if type(BlackMarketManager.equipped_primary) == "function" and not methods.equipped_primary then
        methods.equipped_primary = BlackMarketManager.equipped_primary
        BlackMarketManager.equipped_primary = function(self, ...)
            if equipment_spoofer_active() then
                local spoofed = make_spoofed_weapon(SimpleBeardLibFullscreenEquipmentSpoofer.primary)
                if spoofed then
                    return spoofed
                end
            end
            return methods.equipped_primary(self, ...)
        end
        installed_any = true
    end

    if type(BlackMarketManager.equipped_secondary) == "function" and not methods.equipped_secondary then
        methods.equipped_secondary = BlackMarketManager.equipped_secondary
        BlackMarketManager.equipped_secondary = function(self, ...)
            if equipment_spoofer_active() then
                local spoofed = make_spoofed_weapon(SimpleBeardLibFullscreenEquipmentSpoofer.secondary)
                if spoofed then
                    return spoofed
                end
            end
            return methods.equipped_secondary(self, ...)
        end
        installed_any = true
    end

    if type(BlackMarketManager.equipped_deployable) == "function" and not methods.equipped_deployable then
        methods.equipped_deployable = BlackMarketManager.equipped_deployable
        BlackMarketManager.equipped_deployable = function(self, slot, ...)
            if equipment_spoofer_active() then
                local handled, result = get_spoofed_deployable(slot)
                if handled then
                    return result
                end
            end
            return methods.equipped_deployable(self, slot, ...)
        end
        installed_any = true
    end

    if type(BlackMarketManager.equipped_grenade) == "function" and not methods.equipped_grenade then
        methods.equipped_grenade = BlackMarketManager.equipped_grenade
        BlackMarketManager.equipped_grenade = function(self, ...)
            if equipment_spoofer_active() then
                local id = SimpleBeardLibFullscreenEquipmentSpoofer.grenade
                if id and id ~= "current" and tweak_data and tweak_data.blackmarket
                    and tweak_data.blackmarket.projectiles and tweak_data.blackmarket.projectiles[id]
                    and tweak_data.blackmarket.projectiles[id].throwable then
                    local global_grenades = Global and Global.blackmarket_manager and Global.blackmarket_manager.grenades
                    local grenade_data = global_grenades and global_grenades[id]
                    return id, grenade_data and grenade_data.amount or 0
                end
            end
            return methods.equipped_grenade(self, ...)
        end
        installed_any = true
    end

    if type(BlackMarketManager.equipped_melee_weapon) == "function" and not methods.equipped_melee_weapon then
        methods.equipped_melee_weapon = BlackMarketManager.equipped_melee_weapon
        BlackMarketManager.equipped_melee_weapon = function(self, ...)
            if equipment_spoofer_active() then
                local melee_id = SimpleBeardLibFullscreenEquipmentSpoofer.melee
                local melee_data = tweak_data and tweak_data.blackmarket
                    and tweak_data.blackmarket.melee_weapons and tweak_data.blackmarket.melee_weapons[melee_id]
                if melee_id and melee_id ~= "current" and type(melee_data) == "table" then
                    return melee_id
                end
            end
            return methods.equipped_melee_weapon(self, ...)
        end
        installed_any = true
    end

    state.blackmarket_hooks_installed = installed_any
    if installed_any and log then
        log("[AFUI] Equipment spoofer BlackMarketManager hooks installed.")
    end
    return installed_any
end

local function install_equipment_spoofer_network_hook()
    local state = SimpleBeardLibFullscreenEquipmentSpoofer
    if state.network_hook_installed or not BaseNetworkSession
        or type(BaseNetworkSession.check_send_outfit) ~= "function" then
        return false
    end

    local original_check_send_outfit = BaseNetworkSession.check_send_outfit
    BaseNetworkSession.check_send_outfit = function(self, ...)
        if not Global then
            return original_check_send_outfit(self, ...)
        end
        local previous = Global.IS_SENDING_OUTFIT
        Global.IS_SENDING_OUTFIT = true
        local ok, result = pcall(original_check_send_outfit, self, ...)
        Global.IS_SENDING_OUTFIT = previous
        if not ok then
            error(result, 0)
        end
        return result
    end

    state.network_hook_installed = true
    if log then
        log("[AFUI] BaseNetworkSession.check_send_outfit hook installed.")
    end
    return true
end

local function refresh_equipment_spoofer_outfit()
    if not (managers and managers.network and type(managers.network.session) == "function") then
        return false
    end
    local ok_session, session = pcall(managers.network.session, managers.network)
    if not ok_session or not session or type(session.check_send_outfit) ~= "function" then
        return false
    end
    local ok_send = pcall(session.check_send_outfit, session)
    return ok_send
end

-- Repeated loads come from the four SuperBLT hook points, but each class gets wrapped once.
load_equipment_spoofer_settings()
install_equipment_spoofer_blackmarket_hooks()
install_equipment_spoofer_network_hook()


-- FOV helper and vanilla-menu cleanup. The game defines MenuOptionInitiator in
-- lib/managers/menumanager.lua, which is one of this mod's hook points.
SimpleBeardLibFullscreenFOV = SimpleBeardLibFullscreenFOV or {
    vanilla_menu_hooks_installed = false,
    default_fov = 65,
    minimum_fov = 55,
    maximum_fov = 160,
    settings_loaded = false,
    has_saved_fov = false,
    saved_fov = nil
}

local function clamp_fov_value(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return nil
    end
    number = math.max(55, math.min(160, number))
    return tonumber(string.format("%.1f", number))
end

-- The selected FOV is persisted in the shared AFUI.json settings table.
local function load_saved_fov()
    local state = SimpleBeardLibFullscreenFOV
    if state.settings_loaded then
        return state.has_saved_fov and state.saved_fov or nil
    end

    local all_settings, ready = load_afui_settings()
    if not ready then
        if log then
            log("[SimpleBeardLibFullscreenMenu] Unified settings not ready; FOV load will retry later.")
        end
        return nil
    end

    state.settings_loaded = true
    local saved = clamp_fov_value(all_settings.fov)
    if saved then
        state.saved_fov = saved
        state.has_saved_fov = true
        if log then
            log("[SimpleBeardLibFullscreenMenu] Loaded saved FOV from AFUI.json: " .. string.format("%.1f", saved) .. ".")
        end
        return saved
    end
    return nil
end

local function save_fov_setting(fov)
    local state = SimpleBeardLibFullscreenFOV
    local selected_fov = clamp_fov_value(fov)
    if not selected_fov then
        return false
    end

    local all_settings, ready = load_afui_settings()
    if not ready then
        return false
    end
    all_settings.fov = selected_fov

    if not save_afui_settings() then
        if log then
            log("[SimpleBeardLibFullscreenMenu] ERROR: Could not save FOV to AFUI.json.")
        end
        return false
    end

    state.saved_fov = selected_fov
    state.has_saved_fov = true
    state.settings_loaded = true
    if log then
        log("[SimpleBeardLibFullscreenMenu] Saved FOV to AFUI.json: " .. string.format("%.1f", selected_fov) .. ".")
    end
    return true
end

local function get_current_fov()
    local fov_state = SimpleBeardLibFullscreenFOV
    local default_fov = fov_state.default_fov or 65
    if not managers or not managers.user or type(managers.user.get_setting) ~= "function" then
        return fov_state.has_saved_fov and fov_state.saved_fov or default_fov
    end

    local multiplier = tonumber(managers.user:get_setting("fov_multiplier"))
    if not multiplier or multiplier <= 0 then
        return fov_state.has_saved_fov and fov_state.saved_fov or default_fov
    end

    local fov = tonumber(string.format("%.1f", default_fov * multiplier)) or default_fov
    return math.max(fov_state.minimum_fov or 55, math.min(fov_state.maximum_fov or 160, fov))
end

local function apply_fov(fov, skip_persist)
    local fov_state = SimpleBeardLibFullscreenFOV
    local selected_fov = clamp_fov_value(fov)
    if not selected_fov then
        return false
    end

    local minimum_fov = fov_state.minimum_fov or 55
    local maximum_fov = fov_state.maximum_fov or 160
    local default_fov = fov_state.default_fov or 65
    selected_fov = math.max(minimum_fov, math.min(maximum_fov, selected_fov))
    selected_fov = tonumber(string.format("%.1f", selected_fov)) or default_fov

    -- Persist the requested value independently of Payday 2's settings autosave.
    if not skip_persist then
        save_fov_setting(selected_fov)
    else
        fov_state.saved_fov = selected_fov
        fov_state.has_saved_fov = true
    end

    if not managers or not managers.user or type(managers.user.set_setting) ~= "function" then
        if log then
            log("[SimpleBeardLibFullscreenMenu] Cannot apply FOV yet: user settings manager unavailable.")
        end
        return false
    end

    managers.user:set_setting("fov_multiplier", selected_fov / default_fov)

    if managers.player and type(managers.player.player_unit) == "function" and alive then
        local player_unit = managers.player:player_unit()
        if alive(player_unit) then
            local movement = player_unit:movement()
            if movement and type(movement.current_state) == "function" then
                local current_state = movement:current_state()
                if current_state and type(current_state.update_fov_external) == "function" then
                    current_state:update_fov_external()
                end
            end
        end
    end

    if log then
        log("[SimpleBeardLibFullscreenMenu] FOV set to " .. string.format("%.1f", selected_fov) .. ".")
    end
    return true, selected_fov
end

local function restore_saved_fov()
    local saved_fov = load_saved_fov()
    if not saved_fov then
        return false
    end
    local applied = apply_fov(saved_fov, true)
    if applied and log then
        log("[SimpleBeardLibFullscreenMenu] Restored saved FOV: " .. string.format("%.1f", saved_fov) .. ".")
    end
    return applied
end

SimpleBeardLibFullscreenFOV.GetCurrentFOV = get_current_fov
SimpleBeardLibFullscreenFOV.ApplyFOV = apply_fov
SimpleBeardLibFullscreenFOV.RestoreSavedFOV = restore_saved_fov

-- Restore early when possible; the menu callback below retries if the settings manager
-- was not initialized yet during the first hook load.
restore_saved_fov()

if not SimpleBeardLibFullscreenFOV.vanilla_menu_hooks_installed and MenuOptionInitiator then
    local function remove_vanilla_fov_item(self, node)
        if not node or type(node.item) ~= "function" then
            return
        end
        local fov_item = node:item("fov_multiplier")
        if fov_item and type(node.delete_item) == "function" then
            node:delete_item("fov_multiplier")
            if log then
                log("[SimpleBeardLibFullscreenMenu] Removed vanilla FOV slider from " .. tostring(self) .. ".")
            end
        end
    end

    Hooks:PostHook(MenuOptionInitiator, "modify_video", "SimpleBeardLibFullscreen_RemoveVanillaFOVVideo", remove_vanilla_fov_item)
    Hooks:PostHook(MenuOptionInitiator, "modify_adv_video", "SimpleBeardLibFullscreen_RemoveVanillaFOVAdvancedVideo", remove_vanilla_fov_item)
    SimpleBeardLibFullscreenFOV.vanilla_menu_hooks_installed = true
    if log then
        log("[SimpleBeardLibFullscreenMenu] Vanilla FOV menu hooks installed.")
    end
end

-- Keyword-based mod-list hider. The toggle is available in the Functions tab.
-- It filters the vanilla PAYDAY 2 / SuperBLT Mods list without uninstalling or disabling mods.
SimpleBeardLibFullscreenModHider = SimpleBeardLibFullscreenModHider or {
    enabled = true,
    settings_loaded = false,
    build_hook_installed = false,
    add_hook_installed = false,
    keywords = { "!", "AFUI" }
}

local function normalize_mod_hider_keyword(value)
    if type(value) ~= "string" and type(value) ~= "number" then
        return nil
    end

    local keyword = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
    if keyword == "" then
        return nil
    end

    -- Keep accidental pasted paragraphs and excessively long entries out of the settings.
    if #keyword > 64 then
        keyword = keyword:sub(1, 64)
    end
    return keyword
end

local function normalize_mod_hider_keywords(values)
    local result, seen = {}, {}
    if type(values) ~= "table" then
        return result
    end

    for _, value in ipairs(values) do
        local keyword = normalize_mod_hider_keyword(value)
        local key = keyword and keyword:lower() or nil
        if key and not seen[key] then
            result[#result + 1] = keyword
            seen[key] = true
            if #result >= 100 then
                break
            end
        end
    end
    return result
end

-- Preserve the defaults on first launch and sanitize previously stored values.
if type(SimpleBeardLibFullscreenModHider.keywords) ~= "table" then
    SimpleBeardLibFullscreenModHider.keywords = { "!", "AFUI" }
else
    SimpleBeardLibFullscreenModHider.keywords = normalize_mod_hider_keywords(SimpleBeardLibFullscreenModHider.keywords)
end

local function load_mod_hider_settings()
    local state = SimpleBeardLibFullscreenModHider
    if state.settings_loaded then
        return
    end

    local all_settings, ready = load_afui_settings()
    if not ready then
        return
    end

    local data = type(all_settings.mod_hider) == "table" and all_settings.mod_hider or nil
    if data then
        if data.enabled ~= nil then
            state.enabled = data.enabled == true
        end
        if type(data.keywords) == "table" then
            state.keywords = normalize_mod_hider_keywords(data.keywords)
        end
    end
    state.settings_loaded = true
end

local function save_mod_hider_settings()
    local state = SimpleBeardLibFullscreenModHider
    local all_settings, ready = load_afui_settings()
    if not ready then
        return false
    end

    local keywords = normalize_mod_hider_keywords(state.keywords)
    state.keywords = keywords
    all_settings.mod_hider = { enabled = state.enabled == true, keywords = keywords }
    local saved = save_afui_settings()
    if saved and log then
        log("[SimpleBeardLibFullscreenMenu] Saved mod hider settings to AFUI.json.")
    end
    return saved
end

local function find_mod_hider_keyword(keyword)
    local needle = tostring(keyword or ""):lower()
    for index, existing in ipairs(SimpleBeardLibFullscreenModHider.keywords or {}) do
        if tostring(existing):lower() == needle then
            return index
        end
    end
    return nil
end

local function add_mod_hider_keyword(value)
    local keyword = normalize_mod_hider_keyword(value)
    if not keyword then
        return false, "Enter a non-empty keyword."
    end

    local state = SimpleBeardLibFullscreenModHider
    if find_mod_hider_keyword(keyword) then
        return false, "That keyword is already in the list."
    end
    if #(state.keywords or {}) >= 100 then
        return false, "The keyword limit (100) has been reached."
    end

    state.keywords = state.keywords or {}
    state.keywords[#state.keywords + 1] = keyword
    local saved = save_mod_hider_settings()
    if log then
        log("[SimpleBeardLibFullscreenMenu] Added mod hider keyword: " .. keyword)
    end
    return true, saved and ("Added and saved: " .. keyword) or ("Added for this session, but save failed: " .. keyword)
end

local function remove_mod_hider_keyword(value)
    local keyword = normalize_mod_hider_keyword(value)
    if not keyword then
        return false, "Enter the keyword to remove."
    end

    local state = SimpleBeardLibFullscreenModHider
    local index = find_mod_hider_keyword(keyword)
    if not index then
        return false, "Keyword not found: " .. keyword
    end

    local removed = table.remove(state.keywords, index)
    local saved = save_mod_hider_settings()
    if log then
        log("[SimpleBeardLibFullscreenMenu] Removed mod hider keyword: " .. tostring(removed))
    end
    return true, saved and ("Removed and saved: " .. tostring(removed)) or ("Removed for this session, but save failed: " .. tostring(removed))
end

local function mod_hider_keywords_summary()
    local keywords = SimpleBeardLibFullscreenModHider.keywords or {}
    if #keywords == 0 then
        return "Keywords (0): none"
    end

    local shown = {}
    local current_length = 13
    -- Keep this live summary short enough to fit a compact card without words colliding.
    local max_summary_length = 48
    for index, keyword in ipairs(keywords) do
        local part = tostring(keyword)
        local extra = (#shown > 0 and 2 or 0) + #part
        if current_length + extra > max_summary_length then
            shown[#shown + 1] = "+" .. tostring(#keywords - index + 1) .. " more"
            break
        end
        shown[#shown + 1] = part
        current_length = current_length + extra
    end
    return "Keywords (" .. tostring(#keywords) .. "): " .. table.concat(shown, ", ")
end


local function should_hide_mod(mod_data, loaded_mods)
    if type(mod_data) ~= "table" then
        return true
    end

    local name = tostring(mod_data[1] or "")
    local source = mod_data.source
    local lname = name:lower()

    if lname == "" then
        return true
    end

    for _, keyword in ipairs(SimpleBeardLibFullscreenModHider.keywords or { "!", "AFUI" }) do
        local lkeyword = tostring(keyword or ""):lower()
        if lkeyword ~= "" and lname:find(lkeyword, 1, true) then
            return true
        end
    end

    if loaded_mods and loaded_mods[name] then
        return true
    end

    if tostring(source or ""):lower() == "unnamed blt mod" then
        return true
    end

    return false
end

local function install_mod_hider_hooks()
    load_mod_hider_settings()
    local state = SimpleBeardLibFullscreenModHider
    local callback_handler = MenuCallbackHandler
    if not callback_handler then
        return false
    end

    if not state.build_hook_installed and type(callback_handler.build_mods_list) == "function" then
        state.original_build_mods_list = callback_handler.build_mods_list
        callback_handler.build_mods_list = function(self, ...)
            local mods = state.original_build_mods_list(self, ...)
            if not state.enabled or type(mods) ~= "table" then
                return mods
            end

            local loaded_mods = {}
            for i = #mods, 1, -1 do
                local mod = mods[i]
                if should_hide_mod(mod, loaded_mods) then
                    table.remove(mods, i)
                else
                    loaded_mods[tostring(mod[1])] = true
                end
            end
            return mods
        end
        state.build_hook_installed = true
    end

    if not state.add_hook_installed and type(callback_handler.add_mod) == "function" then
        state.original_add_mod = callback_handler.add_mod
        callback_handler.add_mod = function(self, mod_data, ...)
            if state.enabled and should_hide_mod(mod_data) then
                return
            end
            return state.original_add_mod(self, mod_data, ...)
        end
        state.add_hook_installed = true
    end

    if state.build_hook_installed and state.add_hook_installed then
        state.hooks_installed = true
        if not state.hooks_logged and log then
            log("[SimpleBeardLibFullscreenMenu] Keyword mod hider hooks installed.")
            state.hooks_logged = true
        end
        return true
    end

    return false
end

install_mod_hider_hooks()

if not SimpleBeardLibFullscreenSpoofer.menu_hook_registered and MenuManager then
    SimpleBeardLibFullscreenSpoofer.menu_hook_registered = true
    Hooks:Add("BeardLibCreateCustomMenus", "SimpleBeardLibFullscreenMenu_Create", function()
    if not MenuUI then
        if log then
            log("[SimpleBeardLibFullscreenMenu] ERROR: MenuUI was not found. Check that BeardLib is installed and enabled.")
        end
        return
    end

    if SimpleBeardLibFullscreenMenu and SimpleBeardLibFullscreenMenu:alive() then
        return
    end

    -- Retry hooks/settings once all managers and callback handlers are ready.
    install_mod_hider_hooks()

    -- Retry restoration when BeardLib creates the custom menu, in case managers.user
    -- was not ready when the hook file first loaded.
    restore_saved_fov()

    -- Configurable level/infamy spoof settings. Values persist in the SuperBLT saves folder.
    local spoofer_state = SimpleBeardLibFullscreenSpoofer
    local level_rank_spoof_enabled = spoofer_state.enabled == true
    local level_rank_spoof_level = tonumber(spoofer_state.level) or 100
    local level_rank_spoof_rank = tonumber(spoofer_state.rank) or 0
    local level_rank_spoof_saved_enabled = spoofer_state.enabled == true

    local function clamp_spoof_integer(value, minimum, maximum, fallback)
        local number = tonumber(value)
        if not number or number ~= number or number == math.huge or number == -math.huge then
            return fallback
        end
        return math.max(minimum, math.min(maximum, math.floor(number)))
    end

    local function load_spoofer_settings()
        local all_settings, ready = load_afui_settings()
        if not ready then
            return
        end

        local data = type(all_settings.spoofer) == "table" and all_settings.spoofer or {}
        level_rank_spoof_level = clamp_spoof_integer(data.level, 0, 100, 100)
        level_rank_spoof_rank = clamp_spoof_integer(data.rank, 0, 500, 0)
        level_rank_spoof_saved_enabled = data.enabled == true
        level_rank_spoof_enabled = level_rank_spoof_saved_enabled
        spoofer_state.level = level_rank_spoof_level
        spoofer_state.rank = level_rank_spoof_rank
        spoofer_state.enabled = level_rank_spoof_saved_enabled
        spoofer_state.settings_loaded = true
    end

    local function save_spoofer_settings()
        local all_settings, ready = load_afui_settings()
        if not ready then
            return false
        end

        spoofer_state.enabled = level_rank_spoof_enabled
        spoofer_state.level = level_rank_spoof_level
        spoofer_state.rank = level_rank_spoof_rank
        spoofer_state.settings_loaded = true
        all_settings.spoofer = {
            enabled = level_rank_spoof_enabled,
            level = level_rank_spoof_level,
            rank = level_rank_spoof_rank
        }
        return save_afui_settings()
    end

    load_spoofer_settings()

    -- The NetworkPeer wrapper in this file reads the shared live state.
    local function set_level_rank_spoof_enabled(enabled)
        level_rank_spoof_enabled = enabled == true
        spoofer_state.enabled = level_rank_spoof_enabled
        spoofer_state.level = level_rank_spoof_level
        spoofer_state.rank = level_rank_spoof_rank
        if log then
            log("[SimpleBeardLibFullscreenMenu] Level/rank spoof " .. (level_rank_spoof_enabled and "enabled" or "disabled") .. ".")
        end
        return true
    end

    -- Restore the saved ON state on startup, if the user previously saved it that way.
    if level_rank_spoof_saved_enabled and not set_level_rank_spoof_enabled(true) then
        level_rank_spoof_enabled = false
    end

    -- PAYDAY 2 Color uses Color(alpha, red, green, blue).
    -- Dark, slightly translucent surfaces with high-contrast white text.
    local colors = {
        overlay = Color(0.68, 0.012, 0.016, 0.022),
        card = Color(0.76, 0.025, 0.030, 0.038),
        card_alt = Color(0.76, 0.045, 0.050, 0.060),
        text = Color(1, 0.96, 0.97, 0.99),
        secondary = Color(1, 0.76, 0.80, 0.84),
        accent = Color(1, 0.96, 0.42, 0.12),
        -- Neutral medium-grey tabs with reduced alpha for a glass-like look.
        tab = Color(0.62, 0.36, 0.36, 0.36),
        tab_highlight = Color(0.74, 0.52, 0.52, 0.52),
        tab_border = Color(0.92, 0.72, 0.74, 0.76)
    }

    SimpleBeardLibFullscreenMenu = MenuUI:new({
        name = "SimpleBeardLibFullscreenMenu",
        -- High panel layer to stay above ordinary vanilla and mod UI on shared workspaces.
        -- Avoid changing global workspace, mouse, or SuperBLT settings.
        layer = 10000,
        toggle_key = Idstring("end"),
        use_default_close_key = true,
        enabled = false,
        disable_player_controls = true,
        animate_toggle = true,
        background_blur = false,
        background_color = colors.overlay,
        show_help_time = 0.45,

        create_items = function(ui)
            local screen_w = ui:ItemsWidth()
            local screen_h = ui:ItemsHeight()

            -- Responsive two-column, two-row layout for compact independent sections.
            local side_margin = math.max(28, math.floor(screen_w * 0.032))
            local column_gap = math.max(18, math.floor(screen_w * 0.018))
            local column_w = math.floor((screen_w - side_margin * 2 - column_gap) / 2)
            local left_x = side_margin
            local right_x = side_margin + column_w + column_gap
            local top_section_y = math.max(82, math.floor(screen_h * 0.108))
            local top_card_y = top_section_y + 36
            local bottom_section_y = math.floor(screen_h * 0.505)
            local bottom_card_y = bottom_section_y + 36
            local tab_gap = math.max(12, math.floor(screen_w * 0.010))
            local tab_w = math.min(360, math.floor((screen_w - side_margin * 2 - tab_gap * 3) / 4))
            local tab_start_x = math.floor((screen_w - (tab_w * 4 + tab_gap * 3)) / 2   )
            local tab_y = 20
            -- Give all ordinary cards a little more breathing room between columns.
            -- The Equipment Spoofer keeps its original full-width card and control sizes.
            local section_width_reduction = math.min(math.max(42, math.floor(column_w * 0.075)), math.floor(column_w * 0.18))
            local compact_section_w = math.max(math.min(240, column_w), column_w - section_width_reduction)
            local compact_section_inset = math.floor((column_w - compact_section_w) / 2)
            local control_w = math.min(520, math.max(180, column_w - 38))
            local compact_control_w = math.min(520, math.max(180, compact_section_w - 38))

            local main = ui:Menu({
                name = "FullscreenMainPanel",
                text = "",
                position = "Center",
                w = screen_w,
                h = screen_h,
                auto_height = false,
                scrollbar = false,
                background_visible = false,
                background_alpha = 0,
                foreground = colors.text,
                accent_color = colors.accent,
                offset = {0, 0}
            })

            local page_home = main:Holder({
                name = "PageHome", position = {0, 0}, w = screen_w, h = screen_h,
                auto_height = false, background_visible = false
            })
            local page_functions = main:Holder({
                name = "PageFunctions", position = {0, 0}, w = screen_w, h = screen_h,
                auto_height = false, visible = false, background_visible = false
            })
            local page_state = main:Holder({
                name = "PageState", position = {0, 0}, w = screen_w, h = screen_h,
                auto_height = false, visible = false, background_visible = false
            })
            local page_info = main:Holder({
                name = "PageInfo", position = {0, 0}, w = screen_w, h = screen_h,
                auto_height = false, visible = false, background_visible = false
            })

            -- Feature sections are plain cards; no decorative sub-tab buttons or frames.
            -- Cards start near the section anchor to reclaim the space previously used by those buttons.
            local function make_section(parent, name, label, x, header_y, card_y, alternate, fixed_height, show_subtab)
                local keep_full_width = name == "FunctionsEquipmentSpoofer"
                local card_width = keep_full_width and column_w or compact_section_w
                local card_x = keep_full_width and x or (x + compact_section_inset)
                return parent:Holder({
                    name = name .. "Card",
                    position = {card_x, header_y + 6},
                    w = card_width,
                    h = fixed_height,
                    auto_height = fixed_height == nil,
                    background_visible = true,
                    background_color = alternate and colors.card_alt or colors.card,
                    full_bg_color = alternate and colors.card_alt or colors.card,
                    background_alpha = 0.72,
                    foreground = colors.text,
                    accent_color = colors.accent,
                    border_visible = false,
                    offset = {0, 0}
                })
            end

            local function add_line(parent, name, text, size, item_offset)
                return parent:Divider({
                    name = name,
                    text = text,
                    size = size or 17,
                    foreground = colors.secondary,
                    border_visible = false,
                    border_size = 0,
                    offset = item_offset or {16, 10}
                })
            end

            -- Live status indicators are kept, while prototype/test widgets are removed.
            local active_feature_status_lines = {}
            local function set_active_status_line(key, value)
                local element = active_feature_status_lines[key]
                if element and element.SetText then
                    pcall(function() element:SetText(value) end)
                end
            end

            local function refresh_active_feature_status()
                local current_fov = tonumber(get_current_fov()) or 65
                set_active_status_line("fov", "FOV: " .. string.format("%.1f", current_fov))
                set_active_status_line("spoofer", "Level / Infamy Spoofer: " .. (level_rank_spoof_enabled and "ON" or "OFF"))
                set_active_status_line("spoofer_level", "Spoof Level: " .. tostring(level_rank_spoof_level))
                set_active_status_line("spoofer_rank", "Spoof Infamy: " .. tostring(level_rank_spoof_rank))
                local hider = SimpleBeardLibFullscreenModHider or {}
                set_active_status_line("hider", "Mod List Hider: " .. (hider.enabled and "ON" or "OFF"))
                set_active_status_line("keywords", mod_hider_keywords_summary())
                local equipment = SimpleBeardLibFullscreenEquipmentSpoofer or {}
                set_active_status_line("equipment", "Equipment Spoofer: " .. (equipment.enabled and "ON" or "OFF"))
                set_active_status_line("equipment_primary", "Primary weapon: " .. tostring(equipment.primary or "current"))
                set_active_status_line("equipment_secondary", "Secondary weapon: " .. tostring(equipment.secondary or "current"))
                set_active_status_line("equipment_melee", "Melee weapon: " .. tostring(equipment.melee or "current"))
                set_active_status_line("equipment_deployable", "Deployable: " .. tostring(equipment.deployable or "current"))
                set_active_status_line("equipment_secondary_deployable", "Secondary deployable: " .. tostring(equipment.secondary_deployable or "current"))
                set_active_status_line("equipment_grenade", "Throwable: " .. tostring(equipment.grenade or "current"))
            end

            -- VISUAL: keep only the real FOV control and useful status indicators.
            local home_overview = make_section(
                page_home, "VisualFOV", "FOV",
                left_x, top_section_y, top_card_y, false, nil, true
            )
            local fov_status = add_line(
                home_overview, "VisualFOVStatus",
                "Current FOV: " .. string.format("%.1f", get_current_fov()), 14, {16, 8}
            )
            local visual_saved_status
            home_overview:Slider({
                name = "VisualFOVSlider",
                text = "FOV",
                value = get_current_fov(),
                min = 55,
                max = 160,
                step = 0.1,
                floats = 1,
                w = compact_control_w,
                foreground = colors.text,
                accent_color = colors.accent,
                offset = {16, 8},
                help = "Changes FOV and saves the selected value automatically.",
                on_callback = function(item)
                    local selected_fov = tonumber(item:Value())
                    if not selected_fov then
                        return
                    end
                    selected_fov = tonumber(string.format("%.1f", math.max(55, math.min(160, selected_fov))))
                    local applied, actual_fov = apply_fov(selected_fov)
                    if applied and fov_status and fov_status.SetText then
                        fov_status:SetText("Current FOV: " .. string.format("%.1f", actual_fov or selected_fov))
                    elseif not applied and fov_status and fov_status.SetText then
                        fov_status:SetText("FOV could not be applied - user settings unavailable")
                    end
                    if visual_saved_status and visual_saved_status.SetText then
                        pcall(function() visual_saved_status:SetText("Saved FOV: " .. string.format("%.1f", selected_fov)) end)
                    end
                    refresh_active_feature_status()
                end
            })

            local visual_active = make_section(
                page_home, "VisualActiveStatus", "ACTIVE SETTINGS",
                right_x, top_section_y, top_card_y, true, nil, true
            )
            add_line(visual_active, "VisualFOVHookStatus", "FOV control: active", 16)
            add_line(visual_active, "VisualVanillaFOVStatus", "Standard Video FOV option: hidden", 16)
            add_line(visual_active, "VisualSettingsFileStatus", "Settings file: AFUI.json", 16)

            local home_status = make_section(
                page_home, "VisualSaveStatus", "CURRENT STATUS",
                left_x, bottom_section_y, bottom_card_y, true, nil, true
            )
            visual_saved_status = add_line(
                home_status, "VisualSavedFOVStatus",
                "Saved FOV: " .. string.format("%.1f", get_current_fov()), 16
            )
            add_line(home_status, "VisualSaveFileStatus", "Automatic saving: enabled", 16)

            local home_shortcuts = make_section(
                page_home, "VisualShortcuts", "SHORTCUTS",
                right_x, bottom_section_y, bottom_card_y, false, nil, true
            )
            add_line(home_shortcuts, "HomeShortcutEnd", "End  -  open or close the menu", 17)
            add_line(home_shortcuts, "HomeShortcutEsc", "Esc  -  close the menu", 17)

            -- FUNCTIONS: only active features remain; test counter/callback panels are removed.
            local functions_spoofer = make_section(page_functions, "FunctionsSpoofer", "LEVEL / INFAMY SPOOFER", left_x, top_section_y, top_card_y, false, nil, true)
            local spoof_settings_status

            local function autosave_spoofer_settings()
                local saved = save_spoofer_settings()
                if spoof_settings_status and spoof_settings_status.SetText then
                    pcall(function()
                        spoof_settings_status:SetText(saved and "Auto-save: saved to AFUI.json." or "Auto-save failed - check the SuperBLT log.")
                    end)
                end
                return saved
            end

            functions_spoofer:Button({
                name = "LevelRankSpoofButton",
                text = "Level/Rank Spoof: " .. (level_rank_spoof_enabled and "ON" or "OFF"),
                help = "Toggles spoofing for sync_profile and lobby_info using the values below.",
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent, offset = {16, 8},
                on_callback = function(item)
                    local next_state = not level_rank_spoof_enabled
                    local success = set_level_rank_spoof_enabled(next_state)
                    if success then
                        item:SetText("Level/Rank Spoof: " .. (level_rank_spoof_enabled and "ON" or "OFF"))
                        autosave_spoofer_settings()
                        refresh_active_feature_status()
                    else
                        item:SetText("Level/Rank Spoof: unavailable")
                    end
                end
            })

            local spoof_level_slider = functions_spoofer:Slider({
                name = "SpoofLevelSlider", text = "Spoof Level (0-100)",
                value = level_rank_spoof_level, min = 0, max = 100, step = 1, floats = 0,
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent,
                offset = {16, 8},
                help = "The reputation level sent to other players. Takes effect immediately.",
                on_callback = function(item)
                    local selected_level = clamp_spoof_integer(item:Value(), 0, 100, level_rank_spoof_level)
                    level_rank_spoof_level = selected_level
                    spoofer_state.level = selected_level
                    if tonumber(item:Value()) ~= selected_level and item.SetValue then
                        pcall(function() item:SetValue(selected_level, false) end)
                    end
                    autosave_spoofer_settings()
                    refresh_active_feature_status()
                end
            })

            local spoof_rank_slider = functions_spoofer:Slider({
                name = "SpoofRankSlider", text = "Spoof Infamy (0-500)",
                value = level_rank_spoof_rank, min = 0, max = 500, step = 1, floats = 0,
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent,
                offset = {16, 8},
                help = "The spoofed infamy value sent to other players (0-500). Takes effect immediately.",
                on_callback = function(item)
                    local selected_rank = clamp_spoof_integer(item:Value(), 0, 500, level_rank_spoof_rank)
                    level_rank_spoof_rank = selected_rank
                    spoofer_state.rank = selected_rank
                    if tonumber(item:Value()) ~= selected_rank and item.SetValue then
                        pcall(function() item:SetValue(selected_rank, false) end)
                    end
                    autosave_spoofer_settings()
                    refresh_active_feature_status()
                end
            })

            spoof_settings_status = add_line(
                functions_spoofer, "SpoofSettingsStatus",
                "Auto-save: enabled (AFUI.json)", 14, {12, 4}
            )

            local functions_hider = make_section(page_functions, "FunctionsModHider", "MOD LIST HIDER", right_x, top_section_y, top_card_y, true, nil, true)
            local mod_hider_state = SimpleBeardLibFullscreenModHider
            local mod_hider_status = add_line(
                functions_hider, "ModListHiderKeywords",
                mod_hider_keywords_summary(), 13, {16, 8}
            )
            local mod_hider_action_status = add_line(
                functions_hider, "ModListHiderActionStatus",
                "Status: ready", 12, {16, 7}
            )

            local function update_mod_hider_status(message)
                if mod_hider_status and mod_hider_status.SetText then
                    pcall(function() mod_hider_status:SetText(mod_hider_keywords_summary()) end)
                end
                if message and mod_hider_action_status and mod_hider_action_status.SetText then
                    pcall(function() mod_hider_action_status:SetText(message) end)
                end
                refresh_active_feature_status()
            end

            functions_hider:Button({
                name = "ModListHiderButton",
                text = "Mod List Hider: " .. (mod_hider_state.enabled and "ON" or "OFF"),
                help = "Filters matching entries from the PAYDAY 2 / SuperBLT Mods list. It does not uninstall or disable mods. Keyword matches ignore letter case; empty names, duplicate names and unnamed BLT entries remain hidden as before.",
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent, offset = {16, 8},
                on_callback = function(item)
                    mod_hider_state.enabled = not mod_hider_state.enabled
                    item:SetText("Mod List Hider: " .. (mod_hider_state.enabled and "ON" or "OFF"))
                    local saved = save_mod_hider_settings()
                    update_mod_hider_status(saved and "Hider setting saved to AFUI.json." or "Hider changed, but saving failed; check log.")
                    if log then
                        log("[SimpleBeardLibFullscreenMenu] Mod list hider " .. (mod_hider_state.enabled and "enabled" or "disabled") .. ".")
                    end
                end
            })

            local add_keyword_input = functions_hider:TextBox({
                name = "ModListHiderAddKeywordInput",
                text = "Keyword to add",
                value = "",
                lines = 1,
                focus_mode = true,
                auto_focus = false,
                fit_text = true,
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent, offset = {16, 8},
                help = "Click and type a word or phrase, then press Add Keyword. Matching mod names are hidden."
            })

            functions_hider:Button({
                name = "AddModHiderKeywordButton", text = "Add Keyword",
                help = "Adds the word or phrase from the text box. The keyword list saves automatically to AFUI.json.",
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent, offset = {16, 8},
                on_callback = function()
                    local value = add_keyword_input and add_keyword_input:Value() or ""
                    local ok, message = add_mod_hider_keyword(value)
                    if ok and add_keyword_input and add_keyword_input.SetValue then
                        pcall(function() add_keyword_input:SetValue("", false) end)
                    end
                    update_mod_hider_status(message or (ok and "Keyword added." or "Could not add keyword."))
                end
            })

            local remove_keyword_input = functions_hider:TextBox({
                name = "ModListHiderRemoveKeywordInput",
                text = "Keyword to remove",
                value = "",
                lines = 1,
                focus_mode = true,
                auto_focus = false,
                fit_text = true,
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent, offset = {16, 8},
                help = "Type the keyword exactly as it appears in the keyword list, then press Remove Keyword. Matching ignores case."
            })

            functions_hider:Button({
                name = "RemoveModHiderKeywordButton", text = "Remove Keyword",
                help = "Removes the word or phrase from the text box. The keyword list saves automatically to AFUI.json.",
                w = compact_control_w, foreground = colors.text, accent_color = colors.accent, offset = {16, 8},
                on_callback = function()
                    local value = remove_keyword_input and remove_keyword_input:Value() or ""
                    local ok, message = remove_mod_hider_keyword(value)
                    if ok and remove_keyword_input and remove_keyword_input.SetValue then
                        pcall(function() remove_keyword_input:SetValue("", false) end)
                    end
                    update_mod_hider_status(message or (ok and "Keyword removed." or "Could not remove keyword."))
                end
            })

            -- Equipment spoofing uses only the loadout that is serialized to network peers.
            local equipment_state = SimpleBeardLibFullscreenEquipmentSpoofer
            load_equipment_spoofer_settings()
            local equipment_card_height = math.max(250, math.min(460, screen_h - bottom_section_y - 20))
            local equipment_section = make_section(
                page_functions, "FunctionsEquipmentSpoofer", "EQUIPMENT SPOOFER",
                right_x, bottom_section_y, bottom_card_y, true, equipment_card_height, true
            )
            local equipment_status = add_line(
                equipment_section, "EquipmentSpooferStatus",
                "Auto-save: enabled (AFUI.json)", 13, {12, 3}
            )

            local function equipment_label(data, id)
                local name_id = type(data) == "table" and data.name_id
                if name_id and managers and managers.localization and type(managers.localization.text) == "function" then
                    local ok, value = pcall(managers.localization.text, managers.localization, name_id)
                    if ok and type(value) == "string" and value ~= "" and value ~= name_id then
                        return value .. " [" .. tostring(id) .. "]"
                    end
                end
                return tostring(id)
            end

            local function sort_equipment_choices(choices)
                table.sort(choices, function(a, b)
                    local al = tostring(a.label):lower()
                    local bl = tostring(b.label):lower()
                    if al == bl then
                        return tostring(a.id) < tostring(b.id)
                    end
                    return al < bl
                end)
                return choices
            end

            local function get_weapon_choices(category)
                local choices = {
                    { id = "current", label = "Use current weapon" }
                }
                local selection_index = category == "primary" and 2 or 1
                local weapon_data = tweak_data and tweak_data.weapon
                if type(weapon_data) ~= "table" then
                    return choices
                end

                local ordinary = {}
                local seen = {}
                local blackmarket_weapons = Global and Global.blackmarket_manager
                    and Global.blackmarket_manager.weapons

                -- Prefer the game's own BlackMarketManager registry. Vanilla builds
                -- this registry from playable weapons and stores each weapon's actual
                -- primary/secondary selection index and factory ID here.
                if type(blackmarket_weapons) == "table" then
                    for weapon_id, bm_data in pairs(blackmarket_weapons) do
                        local data = weapon_data[weapon_id]
                        if type(weapon_id) == "string" and type(data) == "table"
                            and type(bm_data) == "table"
                            and tonumber(bm_data.selection_index) == selection_index then
                            ordinary[#ordinary + 1] = {
                                id = weapon_id,
                                label = equipment_label(data, weapon_id)
                            }
                            seen[weapon_id] = true
                        end
                    end
                end

                -- Also include registered player weapons from tweak_data. Do not call
                -- WeaponFactoryManager while constructing the menu: its upgrade lookup
                -- can be unavailable during menu initialization, causing every valid
                -- weapon to be filtered out and leaving only "Use current weapon".
                for weapon_id, data in pairs(weapon_data) do
                    if not seen[weapon_id] and type(weapon_id) == "string"
                        and type(data) == "table" and data.autohit
                        and type(data.use_data) == "table"
                        and tonumber(data.use_data.selection_index) == selection_index then
                        ordinary[#ordinary + 1] = {
                            id = weapon_id,
                            label = equipment_label(data, weapon_id)
                        }
                        seen[weapon_id] = true
                    end
                end

                sort_equipment_choices(ordinary)
                for _, choice in ipairs(ordinary) do
                    choices[#choices + 1] = choice
                end
                return choices
            end

            local function get_deployable_choices(include_none)
                local choices = { { id = "current", label = "Use current equipment" } }
                if include_none then
                    choices[#choices + 1] = { id = "none", label = "None" }
                end
                local bm_deployables = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.deployables or {}
                local equipments = tweak_data and tweak_data.equipments or {}
                for id, data in pairs(bm_deployables) do
                    local equipment = equipments[id]
                    if type(equipment) == "table" and type(equipment.quantity) == "table"
                        and type(equipment.quantity[1]) == "number" then
                        choices[#choices + 1] = { id = id, label = equipment_label(data, id) }
                    end
                end
                -- Keep fixed sentinel entries at the top; sort the rest independently.
                local sentinels = {}
                local ordinary = {}
                for _, choice in ipairs(choices) do
                    if choice.id == "current" or choice.id == "none" then
                        sentinels[#sentinels + 1] = choice
                    else
                        ordinary[#ordinary + 1] = choice
                    end
                end
                sort_equipment_choices(ordinary)
                for _, choice in ipairs(ordinary) do
                    sentinels[#sentinels + 1] = choice
                end
                return sentinels
            end

            local function get_grenade_choices()
                local choices = { { id = "current", label = "Use current throwable" } }
                local ordinary = {}
                local projectiles = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.projectiles or {}
                for id, data in pairs(projectiles) do
                    if type(data) == "table" and data.throwable then
                        ordinary[#ordinary + 1] = { id = id, label = equipment_label(data, id) }
                    end
                end
                sort_equipment_choices(ordinary)
                for _, choice in ipairs(ordinary) do
                    choices[#choices + 1] = choice
                end
                return choices
            end

            local function get_melee_choices()
                local choices = { { id = "current", label = "Use current melee weapon" } }
                local melee_weapons = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.melee_weapons or {}
                local ordinary = {}
                for id, data in pairs(melee_weapons) do
                    if type(id) == "string" and type(data) == "table" then
                        ordinary[#ordinary + 1] = { id = id, label = equipment_label(data, id) }
                    end
                end
                sort_equipment_choices(ordinary)
                for _, choice in ipairs(ordinary) do
                    choices[#choices + 1] = choice
                end
                return choices
            end

            local function choice_index(choices, wanted)
                for i, choice in ipairs(choices) do
                    if choice.id == wanted then
                        return i
                    end
                end
                return 1
            end

            local function save_equipment_from_menu(message)
                local saved = save_equipment_spoofer_settings()
                local status_text = saved and (message or "Equipment settings saved to AFUI.json.")
                    or "Save failed - check the SuperBLT log."
                if equipment_status and equipment_status.SetText then
                    pcall(function() equipment_status:SetText(status_text) end)
                end
                refresh_active_feature_status()
                refresh_equipment_spoofer_outfit()
                return saved
            end

            equipment_section:Button({
                name = "EquipmentSpooferToggle",
                text = "Equipment Spoofer: " .. (equipment_state.enabled and "ON" or "OFF"),
                w = control_w, foreground = colors.text, accent_color = colors.accent,
                offset = {12, 4},
                help = "Spoofs the selected loadout only while it is being sent to other lobby players.",
                on_callback = function(item)
                    equipment_state.enabled = not equipment_state.enabled
                    item:SetText("Equipment Spoofer: " .. (equipment_state.enabled and "ON" or "OFF"))
                    save_equipment_from_menu("Equipment spoofer " .. (equipment_state.enabled and "enabled" or "disabled") .. ".")
                end
            })

            -- Selector-only colors: white highlight, translucent dark controls/popup.
            -- The global orange accent remains in place for ordinary buttons and tabs.
            local equipment_selector_style = {
                foreground = colors.text,
                foreground_highlight = colors.text,
                accent_color = Color(1, 1, 1, 1),
                line_color = Color(1, 1, 1, 1),
                background_color = Color(0.42, 0.025, 0.030, 0.038),
                full_bg_color = Color(0.42, 0.025, 0.030, 0.038),
                background_alpha = 0.42,
                context_background_color = Color(0.56, 0.025, 0.030, 0.038),
                highlight_color = Color(0.32, 1, 1, 1)
            }

            -- Side-by-side selector columns keep the loadout in two columns:
            -- Row 1: primary + secondary, Row 2: melee + deployable,
            -- Row 3: secondary deployable + throwable.
            local equipment_column_gap = 14
            local equipment_column_width = math.floor((column_w - 38 - equipment_column_gap) / 2)
            local equipment_combo_width = math.max(120, equipment_column_width - 8)
            local equipment_column_height = math.max(150, equipment_card_height - 96)
            local equipment_left_column = equipment_section:Holder({
                name = "EquipmentSpooferLeftColumn",
                position = {12, 82},
                w = equipment_column_width,
                h = equipment_column_height,
                auto_height = false,
                background_visible = false,
                offset = {0, 0}
            })
            local equipment_right_column = equipment_section:Holder({
                name = "EquipmentSpooferRightColumn",
                position = {12 + equipment_column_width + equipment_column_gap, 82},
                w = equipment_column_width,
                h = equipment_column_height,
                auto_height = false,
                background_visible = false,
                offset = {0, 0}
            })

            local function add_equipment_combo(parent, key, name, label, choices, help_text)
                local selected = choice_index(choices, equipment_state[key])
                if not choices[selected] then
                    selected = 1
                end
                if selected == 1 and equipment_state[key] ~= choices[selected].id then
                    equipment_state[key] = choices[selected].id
                end
                local items = {}
                for i, choice in ipairs(choices) do
                    items[i] = choice.label
                end
                local params = {
                    name = name,
                    text = label,
                    items = items,
                    value = selected,
                    w = equipment_combo_width,
                    foreground = equipment_selector_style.foreground,
                    foreground_highlight = equipment_selector_style.foreground_highlight,
                    accent_color = equipment_selector_style.accent_color,
                    line_color = equipment_selector_style.line_color,
                    background_color = equipment_selector_style.background_color,
                    full_bg_color = equipment_selector_style.full_bg_color,
                    background_alpha = equipment_selector_style.background_alpha,
                    context_background_color = equipment_selector_style.context_background_color,
                    highlight_color = equipment_selector_style.highlight_color,
                    offset = {0, 4},
                    help = help_text,
                    on_callback = function(item)
                        local index = tonumber(item:Value())
                        index = index and math.floor(index) or 1
                        local choice = choices[index]
                        if not choice then
                            return
                        end
                        equipment_state[key] = choice.id
                        save_equipment_from_menu(label .. " set to " .. choice.label .. ".")
                    end
                }
                return parent:ComboBox(params)
            end

            -- Primary and secondary weapons can be selected independently.
            add_equipment_combo(equipment_left_column, "primary", "EquipmentPrimaryWeapon", "Primary weapon", get_weapon_choices("primary"), "Weapon shown to other players in the sent loadout. Use current weapon to leave it unchanged.")
            add_equipment_combo(equipment_right_column, "secondary", "EquipmentSecondaryWeapon", "Secondary weapon", get_weapon_choices("secondary"), "Secondary weapon shown in the sent loadout.")
            add_equipment_combo(equipment_left_column, "melee", "EquipmentMeleeWeapon", "Melee weapon", get_melee_choices(), "Melee weapon shown in the sent loadout. Use current melee weapon to leave it unchanged.")
            add_equipment_combo(equipment_right_column, "deployable", "EquipmentDeployable", "Deployable", get_deployable_choices(true), "Deployable sent to peers. None sends no primary deployable.")
            add_equipment_combo(equipment_left_column, "secondary_deployable", "EquipmentSecondaryDeployable", "Secondary deployable", get_deployable_choices(true), "Second deployable slot if supported by the current loadout.")
            add_equipment_combo(equipment_right_column, "grenade", "EquipmentThrowable", "Throwable / grenade", get_grenade_choices(), "Throwable shown in the sent loadout. Use current throwable to leave it unchanged.")

            -- STATE: show the real active features and controls, without prototype diagnostics.
            local state_overview = make_section(
                page_state, "StateActiveFeatures", "ACTIVE FEATURES",
                left_x, top_section_y, top_card_y, false, nil, true
            )
            active_feature_status_lines.fov = add_line(state_overview, "StateFOVStatus", "", 16)
            active_feature_status_lines.spoofer = add_line(state_overview, "StateSpooferStatus", "", 16)
            active_feature_status_lines.spoofer_level = add_line(state_overview, "StateSpoofLevelStatus", "", 15)
            active_feature_status_lines.spoofer_rank = add_line(state_overview, "StateSpoofInfamyStatus", "", 15)
            active_feature_status_lines.hider = add_line(state_overview, "StateHiderStatus", "", 16)
            active_feature_status_lines.keywords = add_line(state_overview, "StateHiderKeywordsStatus", "", 13, {16, 10})
            active_feature_status_lines.equipment = add_line(state_overview, "StateEquipmentSpooferStatus", "", 14, {16, 10})
            active_feature_status_lines.equipment_primary = add_line(state_overview, "StateEquipmentPrimaryStatus", "", 14, {16, 10})
            active_feature_status_lines.equipment_secondary = add_line(state_overview, "StateEquipmentSecondaryStatus", "", 14, {16, 10})
            active_feature_status_lines.equipment_melee = add_line(state_overview, "StateEquipmentMeleeStatus", "", 14, {16, 10})
            active_feature_status_lines.equipment_deployable = add_line(state_overview, "StateEquipmentDeployableStatus", "", 14, {16, 10})
            active_feature_status_lines.equipment_secondary_deployable = add_line(state_overview, "StateEquipmentSecondaryDeployableStatus", "", 14, {16, 10})
            active_feature_status_lines.equipment_grenade = add_line(state_overview, "StateEquipmentThrowableStatus", "", 14, {16, 10})
            add_line(state_overview, "StateSettingsFileStatus", "Settings file: AFUI.json", 16)
            refresh_active_feature_status()

            local state_input = make_section(
                page_state, "StateControls", "CONTROLS",
                right_x, top_section_y, top_card_y, true, nil, true
            )
            add_line(state_input, "StateInput1", "End  -  open or close menu", 17)
            add_line(state_input, "StateInput2", "Esc  -  close menu", 17)
            add_line(state_input, "StateInput3", "Player controls blocked while menu is open", 16)

            -- INFO: Steam profile on the right; live profile status on the left.
            local profile_y = top_section_y + 6
            local profile_card_height = math.max(300, screen_h - profile_y - 34)
            local info_about = make_section(
                page_info, "InfoAbout", "",
                right_x, top_section_y, profile_y, false, profile_card_height, false
            )

            -- Put the local player's name above a centered avatar, with more vertical breathing room.
            -- On shorter screens, shrink the avatar enough to keep the lobby row inside the card.
            local avatar_size = math.max(88, math.min(
                292,
                compact_section_w - 56,
                profile_card_height - 370
            ))
            local avatar_x = math.floor((compact_section_w - avatar_size) / 2)
            local avatar_y = 110

            info_about.panel:rect({
                name = "InfoSteamAvatarFrame",
                x = avatar_x - 6,
                y = avatar_y - 6,
                w = avatar_size + 12,
                h = avatar_size + 12,
                color = colors.tab_border,
                layer = 8
            })
            info_about.panel:rect({
                name = "InfoSteamAvatarBackground",
                x = avatar_x - 3,
                y = avatar_y - 3,
                w = avatar_size + 6,
                h = avatar_size + 6,
                color = Color(0.96, 0.035, 0.040, 0.048),
                layer = 9
            })

            local avatar_bitmap = info_about.panel:bitmap({
                name = "InfoSteamAvatar",
                texture = "guis/textures/pd2/blackmarket/icons/characters/dallas",
                x = avatar_x,
                y = avatar_y,
                w = avatar_size,
                h = avatar_size,
                layer = 10
            })
            avatar_bitmap:set_blend_mode("normal")

            -- Lobby players occupy the full width beneath the lowered local avatar.
            -- Each remote player has a framed Steam avatar; names are larger and unboxed,
            -- with one divider spanning the full sub-tab card.
            local lobby_content_x = 24
            local lobby_content_w = compact_section_w - 48
            local lobby_title_y = avatar_y + avatar_size + 32
            info_about.panel:text({
                name = "InfoLobbyPlayersLabel",
                text = "LOBBY PLAYERS",
                x = lobby_content_x,
                y = lobby_title_y,
                w = lobby_content_w,
                h = 26,
                font = tweak_data.menu.pd2_small_font,
                font_size = 16,
                color = colors.secondary,
                align = "center",
                valign = "center",
                layer = 10
            })

            local lobby_gap = 20
            local lobby_cell_y = lobby_title_y + 36
            local lobby_cell_w = math.floor((lobby_content_w - lobby_gap * 2) / 3)
            local lobby_avatar_size = math.max(22, math.min(88, lobby_cell_w - 28))
            local lobby_name_y = lobby_cell_y + lobby_avatar_size + 20
            local lobby_name_h = 64
            local lobby_fallback_avatar = "guis/textures/pd2/blackmarket/icons/characters/dallas"
            local lobby_players = {}
            local profile_lobby_status_line
            local profile_avatar_status_line
            local current_avatar_status = "Requesting from Steam..."
            local lobby_avatar_cache = {}
            local lobby_avatar_pending = {}
            local lobby_cells = {}

            local function set_element_visible(element, shown)
                if element and element.set_visible then
                    pcall(function() element:set_visible(shown) end)
                end
            end

            for i = 1, 3 do
                local cell_x = lobby_content_x + (i - 1) * (lobby_cell_w + lobby_gap)
                local player_avatar_x = cell_x + math.floor((lobby_cell_w - lobby_avatar_size) / 2)
                local player_avatar_y = lobby_cell_y

                local frame = info_about.panel:rect({
                    name = "InfoLobbyPlayerAvatarFrame" .. i,
                    x = player_avatar_x - 5,
                    y = player_avatar_y - 5,
                    w = lobby_avatar_size + 10,
                    h = lobby_avatar_size + 10,
                    color = colors.tab_border,
                    layer = 8
                })
                local background = info_about.panel:rect({
                    name = "InfoLobbyPlayerAvatarBackground" .. i,
                    x = player_avatar_x - 3,
                    y = player_avatar_y - 3,
                    w = lobby_avatar_size + 6,
                    h = lobby_avatar_size + 6,
                    color = Color(0.96, 0.035, 0.040, 0.048),
                    layer = 9
                })
                local avatar = info_about.panel:bitmap({
                    name = "InfoLobbyPlayerAvatar" .. i,
                    texture = lobby_fallback_avatar,
                    x = player_avatar_x,
                    y = player_avatar_y,
                    w = lobby_avatar_size,
                    h = lobby_avatar_size,
                    layer = 10
                })
                avatar:set_blend_mode("normal")
                local name = info_about.panel:text({
                    name = "InfoLobbyPlayerName" .. i,
                    text = "",
                    x = cell_x + 2,
                    y = lobby_name_y,
                    w = lobby_cell_w - 4,
                    h = lobby_name_h,
                    font = tweak_data.menu.pd2_small_font,
                    font_size = 20,
                    color = colors.text,
                    align = "center",
                    valign = "top",
                    wrap = true,
                    word_wrap = true,
                    layer = 10
                })

                lobby_cells[i] = {
                    frame = frame,
                    background = background,
                    avatar = avatar,
                    name = name
                }
                set_element_visible(frame, false)
                set_element_visible(background, false)
                set_element_visible(avatar, false)
                set_element_visible(name, false)
            end

            local lobby_empty_label = info_about.panel:text({
                name = "InfoLobbyPlayersEmpty",
                text = "No other players",
                x = lobby_content_x,
                y = lobby_cell_y + math.max(0, math.floor((lobby_avatar_size - 24) / 2)),
                w = lobby_content_w,
                h = 32,
                font = tweak_data.menu.pd2_small_font,
                font_size = 16,
                color = colors.secondary,
                align = "center",
                valign = "center",
                layer = 10
            })
            set_element_visible(lobby_empty_label, false)

            -- One continuous line underneath the complete player row (not individual name boxes).
            info_about.panel:rect({
                name = "InfoLobbyPlayersDivider",
                x = 20,
                y = lobby_name_y + lobby_name_h + 12,
                w = compact_section_w - 40,
                h = 2,
                color = colors.tab_border,
                layer = 9
            })

            local function refresh_lobby_players()
                local players = {}
                local session_ok, session = pcall(function()
                    if managers and managers.network and managers.network.session then
                        return managers.network:session()
                    end
                end)

                if session_ok and session then
                    local local_id
                    pcall(function()
                        local local_peer = session:local_peer()
                        if local_peer and local_peer.id then
                            local_id = local_peer:id()
                        end
                    end)

                    local peers_ok, peers = pcall(function()
                        return session:all_peers()
                    end)
                    if peers_ok and type(peers) == "table" then
                        for _, peer in pairs(peers) do
                            if peer then
                                local peer_id, peer_name, account_id, account_type
                                pcall(function()
                                    if peer.id then peer_id = peer:id() end
                                    if peer.name then peer_name = peer:name() end
                                    if peer.account_id then account_id = peer:account_id() end
                                    if peer.account_type_str then account_type = peer:account_type_str() end
                                end)

                                if peer_name and tostring(peer_name) ~= ""
                                    and (local_id == nil or peer_id ~= local_id) then
                                    players[#players + 1] = {
                                        name = tostring(peer_name),
                                        id = peer_id,
                                        account_id = account_id,
                                        account_type = account_type
                                    }
                                end
                            end
                        end
                    end
                end

                table.sort(players, function(a, b)
                    return string.lower(a.name) < string.lower(b.name)
                end)
                lobby_players = {}
                for i = 1, math.min(3, #players) do
                    lobby_players[i] = players[i]
                end

                set_element_visible(lobby_empty_label, #lobby_players == 0)
                for i = 1, #lobby_cells do
                    local cell = lobby_cells[i]
                    local player = lobby_players[i]
                    local visible = player ~= nil
                    set_element_visible(cell.frame, visible)
                    set_element_visible(cell.background, visible)
                    set_element_visible(cell.avatar, visible)
                    set_element_visible(cell.name, visible)

                    if player then
                        if cell.name and cell.name.set_text then
                            pcall(function() cell.name:set_text(player.name) end)
                        end
                        pcall(function() cell.avatar:set_image(lobby_fallback_avatar) end)

                        local account_type_ok = not player.account_type or player.account_type == "STEAM"
                        if player.account_id and account_type_ok and Steam and Steam.friend_avatar then
                            local cache_key = tostring(player.account_id)
                            local cached_texture = lobby_avatar_cache[cache_key]
                            if cached_texture then
                                pcall(function() cell.avatar:set_image(cached_texture) end)
                            elseif not lobby_avatar_pending[cache_key] then
                                lobby_avatar_pending[cache_key] = true
                                local avatar_call_ok, avatar_call_error = pcall(function()
                                    Steam:friend_avatar(2, player.account_id, function(texture)
                                        lobby_avatar_pending[cache_key] = nil
                                        if texture then
                                            lobby_avatar_cache[cache_key] = texture
                                            -- Find this player in the current row so a delayed callback
                                            -- cannot put an old player's avatar into a reused cell.
                                            for current_index, current_player in ipairs(lobby_players) do
                                                if tostring(current_player.account_id) == cache_key then
                                                    local current_cell = lobby_cells[current_index]
                                                    if current_cell and alive(current_cell.avatar) then
                                                        pcall(function() current_cell.avatar:set_image(texture) end)
                                                    end
                                                    break
                                                end
                                            end
                                        end
                                    end)
                                end)
                                if not avatar_call_ok then
                                    lobby_avatar_pending[cache_key] = nil
                                    if log then
                                        log("[SimpleBeardLibFullscreenMenu] Lobby avatar request failed for " .. tostring(player.name) .. ": " .. tostring(avatar_call_error))
                                    end
                                end
                            end
                        end
                    else
                        if cell.name and cell.name.set_text then
                            pcall(function() cell.name:set_text("") end)
                        end
                    end
                end

                if profile_lobby_status_line and profile_lobby_status_line.SetText then
                    pcall(function() profile_lobby_status_line:SetText("Other lobby players: " .. tostring(#lobby_players)) end)
                end
                if log then
                    log("[SimpleBeardLibFullscreenMenu] Lobby player list refreshed; remote players: " .. tostring(#lobby_players))
                end
            end

            -- Populate once during creation; selecting Info refreshes the list again.
            refresh_lobby_players()

            local steam_nickname
            local name_ok, account_name = pcall(function()
                if managers and managers.network and managers.network.account
                    and managers.network.account.username then
                    return managers.network.account:username()
                end
            end)
            if name_ok and account_name and tostring(account_name) ~= "" then
                steam_nickname = tostring(account_name)
            end

            -- Optional fallback if this game build exposes Steam:username().
            if not steam_nickname and Steam and Steam.username then
                local steam_name_ok, steam_name = pcall(function()
                    return Steam:username()
                end)
                if steam_name_ok and steam_name and tostring(steam_name) ~= "" then
                    steam_nickname = tostring(steam_name)
                end
            end
            steam_nickname = steam_nickname or "Steam nickname unavailable"

            -- The local Steam nickname now sits above the local avatar, centered across the profile card.
            local nickname_x = 24
            local nickname_w = compact_section_w - 48
            info_about.panel:text({
                name = "InfoSteamNickname",
                text = steam_nickname,
                x = nickname_x,
                y = 20,
                w = nickname_w,
                h = 44,
                font = tweak_data.menu.pd2_large_font,
                font_size = 36,
                color = colors.text,
                align = "center",
                valign = "center",
                wrap = true,
                word_wrap = true,
                layer = 10
            })

            local avatar_status = info_about.panel:text({
                name = "InfoSteamAvatarStatus",
                text = current_avatar_status,
                x = nickname_x,
                y = 68,
                w = nickname_w,
                h = 22,
                font = tweak_data.menu.pd2_small_font,
                font_size = 12,
                color = colors.secondary,
                align = "center",
                valign = "center",
                wrap = true,
                word_wrap = true,
                layer = 10
            })

            local function set_avatar_status(message)
                current_avatar_status = tostring(message or "Steam avatar status unavailable")
                if avatar_status and avatar_status.set_text then
                    pcall(function()
                        avatar_status:set_text(current_avatar_status)
                    end)
                end
                if profile_avatar_status_line and profile_avatar_status_line.SetText then
                    pcall(function() profile_avatar_status_line:SetText("Steam avatar: " .. current_avatar_status) end)
                end
            end

            -- Follow Better Teammate Panel's asynchronous Steam:friend_avatar pattern.
            local avatar_api_ok, avatar_api_error = pcall(function()
                if not Steam or not Steam.userid or not Steam.friend_avatar then
                    error("Steam avatar API is unavailable")
                end

                local steam_id = Steam:userid()
                if not steam_id then
                    error("Steam:userid() returned no Steam ID")
                end

                Steam:friend_avatar(2, steam_id, function(texture)
                    if not alive(avatar_bitmap) then
                        return
                    end

                    if texture then
                        local image_ok, image_error = pcall(function()
                            avatar_bitmap:set_image(texture)
                        end)
                        if image_ok then
                            set_avatar_status("Steam avatar loaded")
                            if log then
                                log("[SimpleBeardLibFullscreenMenu] Steam avatar loaded.")
                            end
                        else
                            set_avatar_status("Could not display Steam avatar")
                            if log then
                                log("[SimpleBeardLibFullscreenMenu] Avatar texture display failed: " .. tostring(image_error))
                            end
                        end
                    else
                        set_avatar_status("Steam did not return an avatar")
                        if log then
                            log("[SimpleBeardLibFullscreenMenu] Steam avatar callback returned no texture.")
                        end
                    end
                end)
            end)

            if not avatar_api_ok then
                set_avatar_status("Steam avatar unavailable")
                if log then
                    log("[SimpleBeardLibFullscreenMenu] Steam avatar request failed: " .. tostring(avatar_api_error))
                end
            end

            -- Profile status is useful information; the old diagnostic test button is removed.
            local info_profile_status = make_section(
                page_info, "InfoProfileStatus", "PROFILE STATUS",
                left_x, top_section_y, top_card_y, true, 220, true
            )
            add_line(
                info_profile_status, "InfoSteamNicknameStatus",
                "Steam nickname: " .. (steam_nickname ~= "Steam nickname unavailable" and "available" or "unavailable"), 16
            )
            profile_avatar_status_line = add_line(
                info_profile_status, "InfoSteamAvatarStatusLine",
                "Steam avatar: " .. current_avatar_status, 15
            )
            profile_lobby_status_line = add_line(
                info_profile_status, "InfoLobbyPlayersStatusLine",
                "Other lobby players: " .. tostring(#lobby_players), 16
            )
            -- Refresh once after creating the labels in case Steam responded during initialization.
            set_avatar_status(current_avatar_status)
            if refresh_lobby_players then
                profile_lobby_status_line:SetText("Other lobby players: " .. tostring(#lobby_players))
            end

            -- Preserve the existing page content while presenting the requested names.
            local pages = {visual = page_home, functions = page_functions, state = page_state, info = page_info}
            local tab_buttons = {}
            local tab_labels = {visual = "Visual", functions = "Functions", state = "State", info = "Info"}
            local tab_order = {"visual", "functions", "state", "info"}

            local function select_tab(selected)
                for key, page in pairs(pages) do
                    page:SetVisible(key == selected)
                end
                if selected == "info" and refresh_lobby_players then
                    refresh_lobby_players()
                end
                -- Keep labels clean: no marker text is added to the selected tab.
                for key, button in pairs(tab_buttons) do
                    button:SetText(tab_labels[key])
                end
            end

            -- A bordered translucent frame groups the primary navigation tabs visually.
            -- Create it before the buttons so the buttons remain on top of the frame.
            local tabs_frame = main:Holder({
                name = "PrimaryTabsFrame",
                position = {tab_start_x - 14, tab_y - 8},
                w = tab_w * 4 + tab_gap * 3 + 28,
                h = 58,
                auto_height = false,
                background_visible = true,
                background_color = Color(0.44, 0.38, 0.38, 0.38),
                full_bg_color = Color(0.44, 0.38, 0.38, 0.38),
                background_alpha = 0.48,
                foreground = colors.text,
                border_visible = true,
                border_color = colors.tab_border,
                border_size = 1,
                offset = {0, 0}
            })

            -- Large primary navigation remains at the top of the screen.
            for index, key in ipairs(tab_order) do
                local label = tab_labels[key]
                tab_buttons[key] = main:Button({
                    name = "Tab" .. label,
                    text = label,
                    position = {tab_start_x + (index - 1) * (tab_w + tab_gap), tab_y},
                    w = tab_w,
                    size = 25,
                    text_align = "center",
                    foreground = colors.text,
                    foreground_highlight = colors.text,
                    background_color = colors.tab,
                    unhighlight_color = colors.tab,
                    highlight_color = colors.tab_highlight,
                    background_alpha = 0.64,
                    accent_color = colors.accent,
                    border_visible = true,
                    border_color = colors.tab_border,
                    border_size = 1,
                    on_callback = function()
                        select_tab(key)
                    end
                })
            end

            refresh_active_feature_status()
            select_tab("visual")
        end
    })

    if log then
        log("[SimpleBeardLibFullscreenMenu] Initialized. Press End to open the menu.")
    end
    end)
end
