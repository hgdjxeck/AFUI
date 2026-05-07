Aftelife = Aftelife or {}
Aftelife.__index = Aftelife

function Aftelife:new()
    local o = setmetatable({}, self)
    o._menu = nil
    o._pages = {}
    o._current = nil
    o._feature_state = {}
    o._feature_items = {}
    return o
end

function Aftelife:SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return
    end

    local ok, err = pcall(fn, ...)
    if not ok then
        log("[Aftelife] " .. tostring(err))
    end
end

function Aftelife:Init()
    if self._menu then
        return
    end

    local accent = Color(0.20, 0.48, 0.95)

    self._menu = MenuUI:new({
        name = "Aftelife",
        layer = 1000,
        offset = 6,
        localized = false,
        enabled = false,
        animate_toggle = true,
        animate_colors = true,
        accent_color = accent,
        foreground = accent:contrast(),
        use_default_close_key = true,
        create_items = function(menu)
            self:CreateItems(menu)
        end
    })
end

function Aftelife:CreateItems(menu)
    local accent = menu.foreground

    local root = menu:Holder({
        name = "Root",
        background_color = Color(0.12, 0.12, 0.12):with_alpha(0.50),
        auto_height = false
    })

    local layout = root:Holder({
        name = "Layout",
        auto_height = false
    })

    local sidebar = layout:Holder({
        name = "Sidebar",
        w = 160,
        auto_height = false,
        background_color = Color(0.10, 0.10, 0.10):with_alpha(0.65),
        foreground = Color.white
    })

    local pages = layout:Holder({
        name = "Pages",
        auto_height = false,
        background_color = Color(0.12, 0.12, 0.12):with_alpha(0.45)
    })

    self._pages = {}
    self._feature_state = self._feature_state or {}
    self._feature_items = {}

    self:_AddTab(sidebar, pages, "main", "Funny", true, function(page)
        self:AddFeatureToggle(page, "test_toggle_1", "Test Toggle 1", false, function(enabled)
            -- сюда потом вставишь свою функцию
        end)

        self:AddFeatureToggle(page, "test_toggle_2", "Test Toggle 2", true, function(enabled)
            -- сюда потом вставишь свою функцию
        end)

        self:AddActionButton(page, "Test Button", function()
            -- обычная кнопка без состояния
        end)
    end)

    self:_AddTab(sidebar, pages, "func", "Functions", false, function(page)
        self:AddFeatureToggle(page, "feature_a", "Feature A", false, function(enabled)
            -- сюда потом вставишь свою функцию
        end)

        self:AddFeatureToggle(page, "feature_b", "Feature B", false, function(enabled)
            -- сюда потом вставишь свою функцию
        end)
    end)

    self:_AddTab(sidebar, pages, "misc", "Misc", false, function(page)
        self:AddFeatureToggle(page, "misc_a", "Misc A", false, function(enabled)
            -- сюда потом вставишь свою функцию
        end)
    end)

    self:_AddTab(sidebar, pages, "opt", "Optimization", false, function(page)
        self:AddFeatureToggle(page, "opt_a", "Optimization A", false, function(enabled)
            -- сюда потом вставишь свою функцию
        end)
    end)
end

function Aftelife:_AddTab(sidebar, pages, id, text, is_default, build_callback)
    local page = pages:Holder({
        name = id,
        visible = false,
        auto_height = false,
        background_color = Color(0, 0, 0, 0)
    })

    self._pages[id] = page

    sidebar:Button({
        name = id .. "_tab",
        text = text,
        w = 150,
        background_color = Color(0, 0, 0, 0),
        highlight_color = self._menu.foreground:with_alpha(0.25),
        text_color = Color.white,
        on_callback = function()
            self:SwitchTab(id)
        end
    })

    if build_callback then
        build_callback(page)
    end

    if is_default or not self._current then
        self._current = id
        page:SetVisible(true)
    end
end

function Aftelife:SwitchTab(name)
    if self._current == name then
        return
    end

    for k, page in pairs(self._pages) do
        page:SetVisible(k == name)
    end

    self._current = name
end

function Aftelife:AddFeatureToggle(parent, key, text, default, on_change)
    local state = default and true or false
    self._feature_state[key] = state

    local item = parent:Toggle({
        name = key,
        text = text,
        value = state,
        on_callback = function(toggle_item)
            local enabled = not not toggle_item.value
            self._feature_state[key] = enabled
            self:SafeCall(on_change, enabled, toggle_item)
        end
    })

    self._feature_items[key] = item
    return item
end

function Aftelife:AddActionButton(parent, text, callback)
    return parent:Button({
        text = text,
        on_callback = function(button_item)
            self:SafeCall(callback, button_item)
        end
    })
end

function Aftelife:SetFeature(key, enabled, run_callback)
    self._feature_state[key] = enabled and true or false

    local item = self._feature_items[key]
    if item and item.SetValue then
        item:SetValue(enabled and true or false, run_callback ~= false)
    end
end

function Aftelife:GetFeature(key)
    return self._feature_state[key] and true or false
end

function Aftelife:Toggle()
    self:Init()
    self._menu:SetEnabled(not self._menu:Enabled())
end

_G.Aftelife = _G.Aftelife or Aftelife:new()

Hooks:Add("MenuUpdate", "Aftelife_ToggleKey", function()
    if not _G.Aftelife then
        return
    end

    local keyboard = Input:keyboard()
    if keyboard and keyboard:pressed(Idstring("delete")) then
        _G.Aftelife:Toggle()
    end
end)

Hooks:Add("BeardLibCreateCustomMenus", "Aftelife_EnsureInit", function()
    if _G.Aftelife then
        _G.Aftelife:Init()
    end
end)