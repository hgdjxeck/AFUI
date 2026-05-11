AFUI = AFUI or {}
AFUI.__index = AFUI

function AFUI:new()
    local o = setmetatable({}, self)
    o._menu = nil
    o._holder = nil
    o._current = "main"
    o._default_tab = "main"
    o._feature_state = {}
    o._feature_items = {}
    o._page_items = {}
    o._save_path = ((SavePath or ModPath or "") .. "afui_config.json")
    return o
end

function AFUI:SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return
    end

    local ok, err = pcall(fn, ...)
    if not ok then
        log("[AFUI] " .. tostring(err))
    end
end

function AFUI:LoadConfig()
    if not json then
        return
    end

    local file = io.open(self._save_path, "r")
    if not file then
        return
    end

    local content = file:read("*all")
    file:close()

    local ok, data = pcall(json.decode, content or "")
    if ok and type(data) == "table" then
        self._feature_state = data
    end
end

function AFUI:SaveConfig()
    if not json then
        return
    end

    local file = io.open(self._save_path, "w")
    if not file then
        return
    end

    file:write(json.encode(self._feature_state or {}))
    file:close()
end

function AFUI:_RegisterPageItem(page, item)
    if not page or not item then
        return item
    end

    self._page_items[page] = self._page_items[page] or {}
    table.insert(self._page_items[page], item)

    return item
end

function AFUI:_AddTabButton(id, text, is_default)
    local accent = Color(0.20, 0.48, 0.95)

    local btn = self._holder:Button({
        name = id .. "_tab",
        text = text,
        background_color = Color(0, 0, 0, 0),
        highlight_color = accent:with_alpha(0.25),
        on_callback = function()
            self:SwitchTab(id)
        end
    })

    if is_default then
        self._current = id
    end

    return btn
end

function AFUI:CreateItems(menu)
    local accent = Color(0.20, 0.48, 0.95)

    self._holder = menu:DivGroup({
        name = "AFUI_Main",
        background_visible = true,
        background_color = Color(0.8, 0.2, 0.2, 0.2),
    })

    self._page_items = {}
    self._feature_items = {}
    self._feature_state = self._feature_state or {}

    self:_AddTabButton("main", "Main", true)
    self:_AddTabButton("func", "Functions", false)
    self:_AddTabButton("misc", "Misc", false)
    self:_AddTabButton("opt", "Optimization", false)
    self:_AddTabButton("fun", "Funny", false)

    self._holder:Divider({
        name = "AFUI_Spacer",
        text = "",
    })

    self:AddFeatureToggle("main", "auto_save", "Auto save", true, function(enabled)
        self._feature_state.auto_save = enabled and true or false
        self:SaveConfig()
    end)

    self:AddFeatureToggle("main", "test_toggle_1", "Test Toggle 1", false, function(enabled)
        -- сюда потом вставишь свою функцию
    end)

    self:AddFeatureToggle("main", "test_toggle_2", "Test Toggle 2", true, function(enabled)
        -- сюда потом вставишь свою функцию
    end)

    self:AddActionButton("main", "Test Button", function()
        -- обычная кнопка без состояния
    end)

    self:AddFeatureToggle("func", "feature_a", "Feature A", false, function(enabled)
        -- сюда потом вставишь свою функцию
    end)

    self:AddFeatureToggle("func", "feature_b", "Feature B", false, function(enabled)
        -- сюда потом вставишь свою функцию
    end)

    self:AddFeatureToggle("misc", "misc_a", "Misc A", false, function(enabled)
        -- сюда потом вставишь свою функцию
    end)

    self:AddFeatureToggle("opt", "opt_a", "Optimization A", false, function(enabled)
        -- сюда потом вставишь свою функцию
    end)

    self:AddFeatureToggle("fun", "fun_a", "Funny A", false, function(enabled)
        -- сюда потом вставишь свою функцию
    end)

    self:SwitchTab(self._default_tab, true)
    self._holder:AlignItems(true, true)
end

function AFUI:SwitchTab(name, force)
    if not force and self._current == name then
        return
    end

    self._current = name

    for page, items in pairs(self._page_items or {}) do
        local visible = page == name

        for _, item in ipairs(items) do
            if item and item.SetVisible then
                item:SetVisible(visible, true)
            end
        end
    end

    if self._holder and self._holder.AlignItems then
        self._holder:AlignItems(true, true)
    end
end

function AFUI:AddFeatureToggle(page, key, text, default, on_change)
    local state = self._feature_state[key]
    if state == nil then
        state = default and true or false
    end

    self._feature_state[key] = state

    local item = self._holder:Toggle({
        name = key,
        text = text,
        value = state,
        on_callback = function(toggle_item)
            local enabled = not not toggle_item:Value()
            self._feature_state[key] = enabled
            self:SaveConfig()
            self:SafeCall(on_change, enabled, toggle_item)
        end
    })

    self:_RegisterPageItem(page, item)

    if page ~= self._current then
        item:SetVisible(false, true)
    end

    self._feature_items[key] = item
    return item
end

function AFUI:AddActionButton(page, text, callback)
    local item = self._holder:Button({
        text = text,
        on_callback = function(button_item)
            self:SafeCall(callback, button_item)
        end
    })

    self:_RegisterPageItem(page, item)

    if page ~= self._current then
        item:SetVisible(false, true)
    end

    return item
end

function AFUI:SetFeature(key, enabled, run_callback)
    self._feature_state[key] = enabled and true or false

    if self._holder and self._holder.SetChecked then
        self._holder:SetChecked(key, enabled and true or false, run_callback ~= false)
    end
end

function AFUI:GetFeature(key)
    return self._feature_state[key] == true
end

function AFUI:Init()
    if self._menu then
        return
    end

    self:LoadConfig()

    local accent = Color(0.20, 0.48, 0.95)

    self._menu = MenuUI:new({
        name = "AFUI",
        layer = 1000,
        offset = 6,
        localized = false,
        toggle_key = (self.Options and self.Options:GetValue("ToggleKey")) or "delete",
        use_default_close_key = true,
        accent_color = accent,
        create_items = callback(self, self, "CreateItems"),
        enabled = false,
        animate_toggle = true,
    })
end

function AFUI:Toggle()
    if not self._menu then
        self:Init()
    end

    if self._menu then
        self._menu:Toggle()
    end
end

function ToggleAFUI()
    if AFUI and AFUI.Toggle then
        AFUI:Toggle()
    end
end

function OpenAFUI()
    if AFUI and AFUI._menu then
        AFUI._menu:Enable()
    end
end

function CloseAFUI()
    if AFUI and AFUI._menu then
        AFUI._menu:Disable()
    end
end

AFUI = AFUI:new()
AFUI:Init()
