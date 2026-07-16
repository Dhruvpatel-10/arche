-- arche-seekbar.lua
-- A sleek, minimal seek indicator (Netflix / YouTube style) for keyboard seeks.
--
-- mpv's built-in osd-bar is a bordered box with a block handle, which looks
-- dated. This replaces it: when you seek (arrow keys, etc.) a thin flat track
-- fades in near the bottom with an accent-filled progress line, a small round
-- scrubber knob that glides to the new position, and current/total time
-- labels. It holds briefly, then fades out. No chrome, no box.
--
-- Colors come from arche-seekbar.conf (rendered by the theme engine; values
-- are ASS BBGGRR). It shows on seek only, never during steady playback, and is
-- suppressed for the resume-seek that fires when a file loads.

local assdraw = require("mp.assdraw")
local options = require("mp.options")

local o = {
    -- colors: ASS BBGGRR (no #). Defaults are the Ember palette; the rendered
    -- arche-seekbar.conf overrides them with the active theme.
    track_color = "78858a",   -- unfilled track
    fill_color  = "3e94c9",   -- filled progress (accent)
    knob_color  = "3e94c9",   -- scrubber dot (accent)
    text_color  = "bcc8cd",   -- time labels (foreground)

    track_alpha  = 0.28,      -- base opacity of the unfilled track when shown
    side_margin  = 0.055,     -- left/right margin as a fraction of width
    bar_y        = 0.93,      -- vertical center as a fraction of height
    track_height = 0.0045,    -- track thickness as a fraction of height
    knob_scale   = 2.0,       -- knob radius = track thickness (px) * this
    font_scale   = 0.020,     -- time-label size as a fraction of height
    show_time    = true,      -- draw current/total time labels
    font         = "Helvetica Neue",

    -- motion envelope (seconds)
    fade_in  = 0.12,
    hold     = 0.9,
    fade_out = 0.40,
    ease     = 0.30,          -- knob glide per tick (0..1); higher = snappier
}
options.read_options(o, "arche-seekbar")

local overlay = mp.create_osd_overlay("ass-events")
local timer = nil
local visible = false
local show_start = 0
local last_seek = 0
local suppress_until = 0
local display_frac = 0        -- eased position the knob is drawn at
local target_frac = 0         -- true position

local function now() return mp.get_time() end

local function osd_size()
    local d = mp.get_property_native("osd-dimensions")
    if d and (d.w or 0) > 0 and (d.h or 0) > 0 then return d.w, d.h end
    return mp.get_property_number("osd-width", 1920), mp.get_property_number("osd-height", 1080)
end

-- opacity 0..1 -> ASS alpha byte ("00" opaque, "FF" transparent)
local function ah(op)
    op = math.max(0, math.min(1, op))
    return string.format("%02X", math.floor((1 - op) * 255 + 0.5))
end

local function fmt_time(t)
    if not t or t < 0 then t = 0 end
    t = math.floor(t + 0.5)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function stop()
    if timer then timer:kill(); timer = nil end
    if visible then overlay:remove() end
    visible = false
end

local function draw(env)
    local W, H = osd_size()
    local mx = W * o.side_margin
    local x0, x1 = mx, W - mx
    local by = H * o.bar_y
    local th = math.max(2.5, H * o.track_height)
    local r = th / 2
    local kr = th * o.knob_scale
    local fx = x0 + (x1 - x0) * math.max(0, math.min(1, display_frac))

    local a = assdraw.ass_new()

    -- unfilled track
    a:new_event()
    a:append(string.format("{\\pos(0,0)\\bord0\\shad1.2\\4c&H000000&\\4a&H%s&\\1c&H%s&\\1a&H%s&}",
        ah(0.5 * env), o.track_color, ah(o.track_alpha * env)))
    a:draw_start(); a:round_rect_cw(x0, by - r, x1, by + r, r); a:draw_stop()

    -- filled progress
    if fx - x0 > th then
        a:new_event()
        a:append(string.format("{\\pos(0,0)\\bord0\\shad1.2\\4c&H000000&\\4a&H%s&\\1c&H%s&\\1a&H%s&}",
            ah(0.5 * env), o.fill_color, ah(env)))
        a:draw_start(); a:round_rect_cw(x0, by - r, fx, by + r, r); a:draw_stop()
    end

    -- scrubber knob (rounded square with full radius = dot)
    a:new_event()
    a:append(string.format("{\\pos(0,0)\\bord0\\shad2\\4c&H000000&\\4a&H%s&\\1c&H%s&\\1a&H%s&}",
        ah(0.45 * env), o.knob_color, ah(env)))
    a:draw_start(); a:round_rect_cw(fx - kr, by - kr, fx + kr, by + kr, kr); a:draw_stop()

    -- time labels, just above the bar ends
    if o.show_time then
        local fs = math.max(12, H * o.font_scale)
        local ty = by - r - fs * 0.55
        local pos = mp.get_property_number("time-pos", 0)
        local dur = mp.get_property_number("duration", 0)
        local function label(x, an, str)
            a:new_event()
            a:append(string.format(
                "{\\pos(%.1f,%.1f)\\an%d\\bord0\\shad1.4\\4c&H000000&\\4a&H%s&\\fs%.1f\\1c&H%s&\\1a&H%s&\\fn%s}",
                x, ty, an, ah(0.35 * env), fs, o.text_color, ah(env), o.font))
            a:append((str:gsub("\\", "\\\\"):gsub("{", "\\{"):gsub("}", "\\}")))
        end
        label(x0, 1, fmt_time(pos))
        label(x1, 3, fmt_time(dur))
    end

    overlay.res_x = W
    overlay.res_y = H
    overlay.data = a.text
    overlay:update()
end

local function tick()
    local dur = mp.get_property_number("duration", 0)
    if not dur or dur <= 0 then stop(); return end
    target_frac = (mp.get_property_number("time-pos", 0) or 0) / dur
    -- glide the drawn position toward the true one
    display_frac = display_frac + (target_frac - display_frac) * o.ease
    if math.abs(target_frac - display_frac) < 0.0004 then display_frac = target_frac end

    -- opacity envelope: fade in, hold since last seek, fade out
    local rise = math.min(1, (now() - show_start) / o.fade_in)
    local since_seek = now() - last_seek
    local fall = 1
    if since_seek > o.hold then
        fall = math.max(0, 1 - (since_seek - o.hold) / o.fade_out)
    end
    local env = rise * fall

    if env <= 0 and fall <= 0 then stop(); return end
    draw(env)
end

local function on_seek()
    if now() < suppress_until then return end
    if not visible then
        visible = true
        show_start = now()
        local dur = mp.get_property_number("duration", 0)
        display_frac = (dur and dur > 0) and ((mp.get_property_number("time-pos", 0) or 0) / dur) or 0
    end
    last_seek = now()
    if not timer then timer = mp.add_periodic_timer(1 / 60, tick) end
    tick()
end

mp.register_event("seek", on_seek)
-- Suppress the resume-position seek that fires right after a file loads.
mp.register_event("file-loaded", function() suppress_until = now() + 1.2 end)
mp.register_event("end-file", stop)
mp.observe_property("osd-dimensions", "native", function()
    if visible then tick() end
end)
