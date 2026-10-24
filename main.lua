-- Simple BeardLib Fullscreen Menu v1.9.0
-- Requires SuperBLT and BeardLib MenuUI.
-- F10: open/close. Esc: close.
-- Independent prototype; no AFUI code is used.

if not Hooks then
    return
end

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

    local click_count = 0
    local test_enabled = false
    local action_count = 0

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
        layer = 300,
        toggle_key = Idstring("f10"),
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
            local tab_gap = math.max(10, math.floor(screen_w * 0.009))
            local tab_w = math.min(390, math.floor((screen_w - side_margin * 2 - tab_gap * 3) / 4))
            local tab_start_x = math.floor((screen_w - (tab_w * 4 + tab_gap * 3)) / 3   )
            local tab_y = 20
            -- Sub-tabs use one fixed width; long labels receive a smaller font size.
            local subtab_w = math.min(170, math.max(112, column_w - 24))
            local control_w = math.min(520, math.max(180, column_w - 38))

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
            local page_tests = main:Holder({
                name = "PageTests", position = {0, 0}, w = screen_w, h = screen_h,
                auto_height = false, visible = false, background_visible = false
            })
            local page_info = main:Holder({
                name = "PageInfo", position = {0, 0}, w = screen_w, h = screen_h,
                auto_height = false, visible = false, background_visible = false
            })

            -- Each section has a smaller dark label and its own translucent card.
            -- The four sections on a page are all visible at once (2 columns x 2 rows).
            local function make_section(parent, name, label, x, header_y, card_y, alternate)
                -- Estimate a readable font size from the fixed button width and label length.
                -- The button stays the same size; only the text scales down for longer labels.
                local label_length = string.len(label)
                local label_size = math.max(12, math.min(18, math.floor((subtab_w - 24) / (label_length * 0.82))))

                parent:Button({
                    name = name .. "SubTab",
                    text = label,
                    position = {x + math.floor((column_w - subtab_w) / 2), header_y},
                    w = subtab_w,
                    size = label_size,
                    text_align = "center",
                    foreground = colors.text,
                    foreground_highlight = colors.text,
                    background_color = colors.tab,
                    unhighlight_color = colors.tab,
                    highlight_color = colors.tab_highlight,
                    background_alpha = 0.60,
                    accent_color = colors.accent,
                    border_visible = true,
                    border_color = colors.tab_border,
                    border_size = 1,
                    help = label .. " section"
                })

                return parent:Holder({
                    name = name .. "Card",
                    position = {x, card_y},
                    w = column_w,
                    auto_height = true,
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

            local function add_line(parent, name, text, size)
                parent:Divider({
                    name = name,
                    text = text,
                    size = size or 17,
                    foreground = colors.secondary,
                    border_visible = false,
                    border_size = 0,
                    offset = {12, 6}
                })
            end

            -- HOME: four independent sections.
            local home_overview = make_section(page_home, "HomeOverview", "OVERVIEW", left_x, top_section_y, top_card_y, false)
            add_line(home_overview, "HomeDescription", "Compact standalone BeardLib MenuUI interface.", 17)

            local home_actions = make_section(page_home, "HomeActions", "ACTIONS", right_x, top_section_y, top_card_y, true)
            home_actions:Button({
                name = "RunHomeAction", text = "Run UI test action", help = "Updates its own text when clicked.",
                w = control_w, foreground = colors.text, accent_color = colors.accent, offset = {12, 5},
                on_callback = function(item)
                    action_count = action_count + 1
                    item:SetText("Action completed  [" .. tostring(action_count) .. "]")
                end
            })
            home_actions:Button({
                name = "CloseMenuButton", text = "Close menu", help = "Closes the interface; F10 reopens it.",
                w = control_w, foreground = colors.text, accent_color = colors.accent, offset = {12, 5},
                on_callback = function() ui:Disable() end
            })

            local home_status = make_section(page_home, "HomeStatus", "STATUS", left_x, bottom_section_y, bottom_card_y, true)
            add_line(home_status, "HomeStatusLine1", "Menu: initialized", 17)
            add_line(home_status, "HomeStatusLine2", "Callbacks: local prototype tests", 17)

            local home_shortcuts = make_section(page_home, "HomeShortcuts", "SHORTCUTS", right_x, bottom_section_y, bottom_card_y, false)
            add_line(home_shortcuts, "HomeShortcutF10", "F10  -  open or close the menu", 17)
            add_line(home_shortcuts, "HomeShortcutEsc", "Esc  -  close the menu", 17)

            -- TESTS: four compact panels; callback tests are still functional.
            local tests_counter = make_section(page_tests, "TestsCounter", "COUNTER", left_x, top_section_y, top_card_y, false)
            tests_counter:Button({
                name = "CounterButton", text = "Counter: 0", help = "Increments a local Lua counter.",
                w = control_w, foreground = colors.text, accent_color = colors.accent, offset = {12, 5},
                on_callback = function(item)
                    click_count = click_count + 1
                    item:SetText("Counter: " .. tostring(click_count))
                end
            })

            local tests_state = make_section(page_tests, "TestsState", "STATE", right_x, top_section_y, top_card_y, true)
            tests_state:Button({
                name = "StateButton", text = "Test state: OFF", help = "Switches between OFF and ON.",
                w = control_w, foreground = colors.text, accent_color = colors.accent, offset = {12, 5},
                on_callback = function(item)
                    test_enabled = not test_enabled
                    item:SetText("Test state: " .. (test_enabled and "ON" or "OFF"))
                end
            })

            local tests_callbacks = make_section(page_tests, "TestsCallbacks", "CALLBACKS", left_x, bottom_section_y, bottom_card_y, true)
            tests_callbacks:Button({
                name = "CallbackButton", text = "Test callback", help = "Writes a message to the game log.",
                w = control_w, foreground = colors.text, accent_color = colors.accent, offset = {12, 5},
                on_callback = function(item)
                    if log then
                        log("[SimpleBeardLibFullscreenMenu] Test callback succeeded.")
                    end
                    item:SetText("Callback invoked")
                end
            })

            local tests_details = make_section(page_tests, "TestsDetails", "DETAILS", right_x, bottom_section_y, bottom_card_y, false)
            add_line(tests_details, "TestsNote1", "These buttons test UI callbacks only.", 17)
            add_line(tests_details, "TestsNote2", "They do not change gameplay.", 17)

            -- INFO: four independent informational/diagnostic panels.
            local info_about = make_section(page_info, "InfoAbout", "ABOUT", left_x, top_section_y, top_card_y, false)
            add_line(info_about, "InfoLine1", "UI backend: BeardLib MenuUI", 17)
            add_line(info_about, "InfoLine2", "Standalone prototype; AFUI code is not included.", 17)

            local info_diagnostics = make_section(page_info, "InfoDiagnostics", "DIAGNOSTICS", right_x, top_section_y, top_card_y, true)
            info_diagnostics:Button({
                name = "DiagnosticButton", text = "Write diagnostic to log", w = control_w,
                foreground = colors.text, accent_color = colors.accent, offset = {12, 5},
                on_callback = function(item)
                    if log then
                        log("[SimpleBeardLibFullscreenMenu] Diagnostic button clicked; callbacks are responding.")
                    end
                    item:SetText("Diagnostic written")
                end
            })

            local info_keyboard = make_section(page_info, "InfoKeyboard", "KEYBOARD", left_x, bottom_section_y, bottom_card_y, true)
            add_line(info_keyboard, "InfoKeyboard1", "F10  -  toggle menu", 17)
            add_line(info_keyboard, "InfoKeyboard2", "Esc  -  close menu", 17)

            local info_theme = make_section(page_info, "InfoTheme", "APPEARANCE", right_x, bottom_section_y, bottom_card_y, false)
            add_line(info_theme, "InfoTheme1", "Dark translucent panels", 17)
            add_line(info_theme, "InfoTheme2", "High-contrast white text", 17)

            local pages = {home = page_home, tests = page_tests, info = page_info}
            local tab_buttons = {}
            local tab_labels = {home = "HOME", tests = "TESTS", info = "INFO"}
            local tab_order = {"home", "tests", "info"}

            local function select_tab(selected)
                for key, page in pairs(pages) do
                    page:SetVisible(key == selected)
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
                    help = key == "home" and "Open the overview page." or (key == "tests" and "Open callback tests." or "Show prototype information."),
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

            select_tab("home")
        end
    })

    if log then
        log("[SimpleBeardLibFullscreenMenu] Initialized. Press F10 to open the menu.")
    end
end)
