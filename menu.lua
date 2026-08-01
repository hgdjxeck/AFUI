AFUI = AFUI or {}

AFUI._menu = nil
AFUI._root = nil
AFUI._tab_panel = nil
AFUI._content = nil
AFUI._pages = {}
AFUI._current = nil
AFUI._feature_state = {}
AFUI._feature_items = {}
AFUI._save_path = ((SavePath or ModPath or "") .. "afui_config.json")

function AFUI:LoadConfig()
    self._feature_state = {}

    if not json then return end

    local file = io.open(self._save_path, "r")
    if not file then return end

    local ok, data = pcall(json.decode, file:read("*all") or "")
    file:close()

    if ok and type(data) == "table" then
        self._feature_state = data
    end
end

function AFUI:SaveConfig()
    if not json then return end

    local file = io.open(self._save_path, "w")
    if not file then return end

    file:write(json.encode(self._feature_state or {}))
    file:close()
end

function AFUI:_MaybeSave()
    if self._feature_state.auto_save then
        self:SaveConfig()
    end
end

function AFUI:_EnsurePage(tab)
    if self._pages[tab] then
        return self._pages[tab]
    end

    local page = self._content:DivGroup({
        name = tab,
        visible = false,
        auto_height = true,
        items_size = 26
    })

    self._pages[tab] = page
    return page
end

function AFUI:SwitchTab(tab, force)
    if not force and self._current == tab then return end

    self._current = tab

    for id, page in pairs(self._pages) do
        if page and page.SetVisible then
            page:SetVisible(id == tab)
        end
    end

    if self._content.AlignItems then
        self._content:AlignItems(true, true)
    end
end

function AFUI:_AddTabButton(tab, text, is_default)
    self._tab_panel:Button({
        text = text,
        w = 90,
        on_callback = function()
            self:SwitchTab(tab)
        end
    })

    self:_EnsurePage(tab)

    if is_default or not self._current then
        self._current = tab
    end
end

function AFUI:AddFeatureToggle(tab, key, text, default, callback)
    local page = self:_EnsurePage(tab)

    local state = self._feature_state[key]
    if state == nil then state = default end
    self._feature_state[key] = state

    local item = page:Toggle({
        text = text,
        value = state,
        on_callback = function(t)
            local enabled = t:Value()
            self._feature_state[key] = enabled
            self:_MaybeSave()
            self:SafeCall(callback, enabled, t)
        end
    })

    self._feature_items[key] = item
    return item
end

function AFUI:AddActionButton(tab, text, callback)
    local page = self:_EnsurePage(tab)

    return page:Button({
        text = text,
        on_callback = function(b)
            self:SafeCall(callback, b)
        end
    })
end

function AFUI:AddSlider(tab, key, text, default, min, max, step, callback)
    local page = self:_EnsurePage(tab)

    local value = self._feature_state[key]
    if value == nil then value = default end
    self._feature_state[key] = value

    return page:Slider({
        text = text,
        value = value,
        min = min,
        max = max,
        step = step or 1,
        on_callback = function(s)
            local v = s:Value()
            self._feature_state[key] = v
            self:_MaybeSave()
            self:SafeCall(callback, v, s)
        end
    })
end

function AFUI:AddTextBox(tab, key, text, default, callback)
    local page = self:_EnsurePage(tab)

    local value = self._feature_state[key]
    if value == nil then value = default or "" end
    self._feature_state[key] = value

    return page:TextBox({
        text = text,
        value = value,
        on_callback = function(t)
            local v = t:Value()
            self._feature_state[key] = v
            self:_MaybeSave()
            self:SafeCall(callback, v, t)
        end
    })
end

function AFUI:CreateItems(menu)
    self._root = menu:DivGroup({
        background_visible = true,
        background_color = Color(0.8, 0.2, 0.2, 0.2)
    })

    -- GRID TABS
    self._tab_panel = self._root:DivGroup({
        background_visible = true,
        background_color = Color(0.8, 0.15, 0.15, 0.15),
        align_method = "grid",
        grid_columns = 6
    })

    -- CONTENT
    self._content = self._root:DivGroup({
        background_visible = false,
        auto_height = true
    })

    self._pages = {}
    self._feature_state = self._feature_state or {}

    -- TABS
    self:_AddTabButton("main", "Main", true)
    self:_AddTabButton("func", "Func", false)
    self:_AddTabButton("misc", "Misc", false)
    self:_AddTabButton("opt", "Opt", false)
    self:_AddTabButton("fun", "Fun", false)

    -- MAIN
    self:AddFeatureToggle("main", "auto_save", "Auto Save", true, function(v)
        self._feature_state.auto_save = v
        self:SaveConfig()
    end)

    self:AddActionButton("main", "Save Now", function()
        self:SaveConfig()
    end)

    -- OPT
    self:AddSlider("opt", "fov", "FOV", 90, 60, 120, 1, function(v)
        -- apply fov
    end)

    self:AddFeatureToggle("opt", "hide_hud", "Hide HUD", false)

    -- MISC
    self:AddTextBox("misc", "note", "Note", "", function(v)
        log("[AFUI] " .. tostring(v))
    end)

    self:AddActionButton("misc", "Print Note", function()
        log("[AFUI] note=" .. tostring(self._feature_state.note))
    end)

    -- FUNC
    self:AddFeatureToggle("func", "a", "Feature A", false)
    self:AddFeatureToggle("func", "b", "Feature B", false)

    -- INIT FIRST TAB SAFE
    self:SwitchTab(self._current or "main", true)

    if self._content.AlignItems then
        self._content:AlignItems(true, true)
    end
end

function AFUI:Init()
    if self._menu then return end

    self:LoadConfig()

    self._menu = MenuUI:new({
        name = "AFUI",
        layer = 1000,
        accent_color = Color(0.2, 0.48, 0.95),
        create_items = callback(self, self, "CreateItems"),
        enabled = false
    })
end

function AFUI:Toggle()
    if not self._menu then
        self:Init()
    end

    local enabled = self._menu:Enabled()

    if enabled then
        self._menu:SetEnabled(false)

        if game_state_machine:current_state() then
            game_state_machine:current_state():set_controller_enabled(true)
        end
    else
        self._menu:SetEnabled(true)

        if game_state_machine:current_state() then
            game_state_machine:current_state():set_controller_enabled(false)
        end
    end
end

AFUI._toggle_key = "delete"

function AFUI:_ShouldSwallowInput()
    -- don't toggle the menu closed while the user is typing in a textbox
    return self._menu and self._menu.Typing and self._menu:Typing()
end

function AFUI:UpdateInput()
    local kb = Input and Input:keyboard()
    if not kb then return end

    if kb:pressed(Idstring(self._toggle_key)) and not self:_ShouldSwallowInput() then
        self:Toggle()
    end
end

AFUI:Init()

local function AFUI_UpdateInput(...)
    if AFUI and AFUI.UpdateInput then
        AFUI:UpdateInput()
    end
end

Hooks:Add("GameSetupUpdate", "AFUIGameSetupUpdate", AFUI_UpdateInput)
Hooks:Add("GameSetupPauseUpdate", "AFUIGameSetupPauseUpdate", AFUI_UpdateInput)
Hooks:Add("MenuUpdate", "AFUIMenuUpdate", AFUI_UpdateInput)
