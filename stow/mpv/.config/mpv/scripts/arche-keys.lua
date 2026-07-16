-- arche-keys.lua
-- A clean, curated keyboard-shortcuts cheatsheet for mpv.
--
-- Replaces mpv's raw stats.lua key-bindings dump (which lists every internal
-- binding in a monospace sprawl that overflows the screen) with a themed,
-- centered panel showing only the shortcuts worth remembering, grouped and
-- laid out in two columns. Colors come from arche-keys.conf, rendered by the
-- theme engine (values are ASS BBGGRR, matching the theme).
--
-- Toggle: bound to "?" in input.conf via `script-message arche-keys-toggle`.
-- Close: "?" again, or Esc.

local assdraw = require("mp.assdraw")
local options = require("mp.options")

-- Colors are ASS BBGGRR strings (no #). Defaults are the Ember palette; the
-- rendered arche-keys.conf overrides them with the active theme.
local o = {
    key_color    = "3e94c9",   -- keys and group headers (accent)
    text_color   = "bcc8cd",   -- descriptions (foreground)
    bg_color     = "1c1513",   -- panel background
    border_color = "3e94c9",   -- panel border (accent)
    muted_color  = "78858a",   -- footer hint
    bg_opacity   = 0.94,        -- panel opacity, 0..1
    scale        = 1.0,         -- global size multiplier
    font         = "Helvetica Neue",
}
options.read_options(o, "arche-keys")

-- Curated content. Two columns, each a list of {title, items={{key, desc}, ...}}.
local COLUMNS = {
    {
        { title = "Playback", items = {
            { "Space",       "Play or pause" },
            { "q",           "Quit, resume later" },
            { "Q",           "Quit" },
            { "< / >",       "Previous or next file" },
            { "k",           "Toggle always on top" },
        }},
        { title = "Seek", items = {
            { "\u{2190} / \u{2192}",  "Seek 5 seconds" },
            { "\u{21e7} \u{2190}/\u{2192}", "Seek 1 second" },
            { "PgUp / PgDn", "Chapter next or previous" },
            { "[ / ]",       "Playback speed down or up" },
            { "Backspace",   "Reset speed" },
        }},
        { title = "Audio", items = {
            { "a / A",       "Next or previous track" },
            { "\u{2191} / \u{2193}",  "Volume up or down" },
            { "m",           "Mute" },
            { "x / X",       "Delay by 50 ms" },
        }},
    },
    {
        { title = "Subtitles", items = {
            { "v",           "Toggle subtitles" },
            { "j / J",       "Next or previous track" },
            { "z / Z",       "Delay by 50 ms" },
            { "Ctrl f / g",  "Move up or down" },
            { "\u{21e7} f / g",   "Smaller or larger" },
            { "g",           "Reload from disk" },
        }},
        { title = "Video", items = {
            { "f",           "Fullscreen" },
            { "d",           "Toggle debanding" },
            { "D",           "Toggle deinterlace" },
            { "C",           "Cycle aspect ratio" },
            { "1 - 4",       "Contrast, brightness, gamma, saturation" },
        }},
        { title = "Tools", items = {
            { "s / S",       "Screenshot, with or without subs" },
            { "~",           "Toggle HDR profile" },
            { "c",           "Audio visualizer" },
            { "b B Ctrl b",  "GIF start, end, make" },
            { "Ctrl c",      "Copy timestamp" },
        }},
    },
}

local overlay = mp.create_osd_overlay("ass-events")
local shown = false

local function osd_size()
    local d = mp.get_property_native("osd-dimensions")
    if d and (d.w or 0) > 0 and (d.h or 0) > 0 then return d.w, d.h end
    return mp.get_property_number("osd-width", 1920), mp.get_property_number("osd-height", 1080)
end

-- opacity 0..1 -> ASS alpha byte ("00" opaque, "FF" transparent)
local function a(op)
    return string.format("%02X", math.floor((1 - math.max(0, math.min(1, op))) * 255 + 0.5))
end

local function esc(s)
    return (tostring(s):gsub("\\", "\\\\"):gsub("{", "\\{"):gsub("}", "\\}"))
end

local function render()
    local W, H = osd_size()
    local sc = math.max(0.7, math.min(2.4, (W / 1920) * o.scale))

    -- type sizes and metrics
    local title_fs, header_fs, row_fs = 30 * sc, 21 * sc, 18.5 * sc
    local row_h, header_h, group_gap = 27 * sc, 40 * sc, 20 * sc
    local key_w, key_gap, act_w = 122 * sc, 18 * sc, 292 * sc
    local col_w = key_w + key_gap + act_w
    local col_gap = 58 * sc
    local pad = 42 * sc
    local title_h = 56 * sc
    local footer_h = 34 * sc

    local function col_height(col)
        local h = 0
        for _, g in ipairs(col) do h = h + header_h + #g.items * row_h + group_gap end
        return h - group_gap
    end
    local content_h = math.max(col_height(COLUMNS[1]), col_height(COLUMNS[2]))

    local panel_w = 2 * col_w + col_gap + 2 * pad
    local panel_h = title_h + content_h + footer_h + 2 * pad
    local px0 = (W - panel_w) / 2
    local py0 = (H - panel_h) / 2

    local ass = assdraw.ass_new()

    -- soft drop shadow
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H000000&\\1a&H%s&\\blur20}", a(0.35)))
    ass:draw_start(); ass:round_rect_cw(px0, py0 + 8, px0 + panel_w, py0 + panel_h + 8, 20 * sc); ass:draw_stop()

    -- panel with border
    ass:new_event()
    ass:append(string.format(
        "{\\pos(0,0)\\an7\\shad0\\1c&H%s&\\1a&H%s&\\bord%.1f\\3c&H%s&\\3a&H%s&\\blur0.5}",
        o.bg_color, a(o.bg_opacity), 1.6 * sc, o.border_color, a(0.5)))
    ass:draw_start(); ass:round_rect_cw(px0, py0, px0 + panel_w, py0 + panel_h, 18 * sc); ass:draw_stop()

    local function tx(x, y, an, fs, color, bold, str)
        ass:new_event()
        ass:append(string.format("{\\pos(%.1f,%.1f)\\an%d\\bord0\\shad0\\fs%.1f\\1c&H%s&\\1a&H00&%s\\fn%s}",
            x, y, an, fs, color, bold and "\\b1" or "\\b0", o.font))
        ass:append(esc(str))
    end

    -- title
    tx(px0 + pad, py0 + pad, 7, title_fs, o.key_color, true, "Keyboard Shortcuts")
    -- thin divider under the title
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", o.border_color, a(0.28)))
    ass:draw_start()
    ass:round_rect_cw(px0 + pad, py0 + pad + title_h - 14 * sc, px0 + panel_w - pad, py0 + pad + title_h - 12 * sc, 1)
    ass:draw_stop()

    -- columns
    local content_top = py0 + pad + title_h
    for ci, col in ipairs(COLUMNS) do
        local col_x0 = px0 + pad + (ci - 1) * (col_w + col_gap)
        local key_right = col_x0 + key_w
        local act_x = col_x0 + key_w + key_gap
        local y = content_top
        for _, g in ipairs(col) do
            tx(col_x0, y, 7, header_fs, o.key_color, true, g.title)
            y = y + header_h
            for _, it in ipairs(g.items) do
                tx(key_right, y, 9, row_fs, o.key_color, false, it[1])
                tx(act_x, y, 7, row_fs, o.text_color, false, it[2])
                y = y + row_h
            end
            y = y + group_gap
        end
    end

    -- footer hint
    tx(px0 + panel_w / 2, py0 + panel_h - pad * 0.55, 5, 15 * sc, o.muted_color, false,
        "Press  ?  or  Esc  to close")

    overlay.res_x = W
    overlay.res_y = H
    overlay.data = ass.text
    overlay:update()
end

local function hide()
    if not shown then return end
    shown = false
    overlay:remove()
    mp.remove_key_binding("arche-keys-esc")
end

local function show()
    shown = true
    mp.add_forced_key_binding("ESC", "arche-keys-esc", hide)
    render()
end

local function toggle()
    if shown then hide() else show() end
end

mp.register_script_message("arche-keys-toggle", toggle)
mp.observe_property("osd-dimensions", "native", function()
    if shown then render() end
end)
-- Hide on file change so it never lingers onto the next video.
mp.register_event("start-file", hide)
