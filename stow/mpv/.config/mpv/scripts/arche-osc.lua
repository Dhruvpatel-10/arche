-- arche-osc.lua
-- A minimal, premium on-screen controller for mpv, built from first principles.
--
-- No external OSC framework and no icon font: every control is a vector shape
-- drawn with ASS, so the overlay is fully self-contained. Colours and a few
-- sizes come from arche-osc.conf, which the arche theme engine renders from the
-- active theme. Turn off mpv's built-in OSC (osc=no) so this is the only one.
--
-- Design: one floating, translucent bar near the bottom. It fades in on mouse
-- movement or when the pointer nears the bottom edge, and fades out after a
-- short idle (it stays while paused). Controls are the essentials only:
-- seek (click and drag), play/pause, skip 10s, volume, and fullscreen.

local assdraw = require("mp.assdraw")
local options = require("mp.options")

-- ---------------------------------------------------------------------------
-- Configuration (overridden by script-opts/arche-osc.conf, theme-rendered)
-- ---------------------------------------------------------------------------
local o = {
    accent      = "c9943e",   -- seek fill, handle, active state (RRGGBB, no #)
    fg          = "cdc8bc",    -- text and icons
    bg          = "13151c",    -- panel background
    track       = "5b6270",    -- unfilled seek track and volume track
    panel_opacity = 0.72,      -- 0..1 background opacity of the bar
    scale       = 1.0,          -- global size multiplier (bump on Retina if small)
    hide_delay  = 1.5,          -- seconds of inactivity before it fades out
    jump_seconds = 10,          -- skip-button amount
    show_while_paused = true,   -- keep the bar up while paused
}
options.read_options(o, "arche-osc")

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

-- "RRGGBB" -> "BBGGRR" for ASS \c/\1c colours.
local function bgr(hex)
    return hex:sub(5, 6) .. hex:sub(3, 4) .. hex:sub(1, 2)
end

local C = {
    accent = bgr(o.accent),
    fg     = bgr(o.fg),
    bg     = bgr(o.bg),
    track  = bgr(o.track),
}

-- Global fade level, 0 (hidden) .. 1 (fully shown).
local fade = 0

-- opacity 0..1 combined with the global fade -> ASS alpha byte ("00"=opaque).
local function alpha(op)
    local a = math.max(0, math.min(1, (op or 1) * fade))
    return string.format("%02X", math.floor((1 - a) * 255 + 0.5))
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local function fmt_time(t)
    if not t or t < 0 then return "0:00" end
    t = math.floor(t + 0.5)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function osd_size()
    local d = mp.get_property_native("osd-dimensions")
    if d and (d.w or 0) > 0 and (d.h or 0) > 0 then return d.w, d.h end
    local w = mp.get_property_number("osd-width", 0)
    local h = mp.get_property_number("osd-height", 0)
    if w > 0 and h > 0 then return w, h end
    return 1920, 1080
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
local overlay = mp.create_osd_overlay("ass-events")
local render_timer = nil
local last_active = -1e9          -- mp.get_time() of last user activity
local mouse = { x = -1, y = -1 }
local dragging = nil              -- "seek" | "volume" | nil
local drag_frac = nil             -- live seek fraction while dragging
local hit = {}                    -- hitboxes filled by layout(), read by input

-- ---------------------------------------------------------------------------
-- Vector icons (drawn centred at 0,0; caller positions with \pos)
-- Each returns an ASS drawing-command string for use between \p1 .. \p0.
-- ---------------------------------------------------------------------------
local icon = {}

function icon.play(s)
    return string.format("m %d %d l %d %d l %d %d",
        -s * 0.62, -s, s * 0.78, 0, -s * 0.62, s)
end

function icon.pause(s)
    local bw = s * 0.42
    local gap = s * 0.30
    return string.format(
        "m %d %d l %d %d l %d %d l %d %d " ..     -- left bar
        "m %d %d l %d %d l %d %d l %d %d",         -- right bar
        -gap - bw, -s, -gap, -s, -gap, s, -gap - bw, s,
        gap, -s, gap + bw, -s, gap + bw, s, gap, s)
end

-- Double chevron pointing left ("<<") or right (">>").
local function chevrons(s, dir)
    local t = s * 0.55         -- thickness
    local w = s * 0.60         -- half-width of one chevron
    local function one(cx)
        if dir < 0 then
            return string.format(
                "m %d %d l %d %d l %d %d l %d %d l %d %d l %d %d ",
                cx + w, -s, cx + w - t, -s,
                cx - w, 0, cx + w - t, s,
                cx + w, s, cx - w + t, 0)
        else
            return string.format(
                "m %d %d l %d %d l %d %d l %d %d l %d %d l %d %d ",
                cx - w, -s, cx - w + t, -s,
                cx + w, 0, cx - w + t, s,
                cx - w, s, cx + w - t, 0)
        end
    end
    return one(-s * 0.45) .. one(s * 0.70)
end

function icon.skip_back(s)  return chevrons(s, -1) end
function icon.skip_fwd(s)   return chevrons(s, 1)  end

-- Speaker body (trapezoid + box). Waves/mute mark drawn separately.
function icon.speaker(s)
    local bx = s * 0.55
    return string.format(
        "m %d %d l %d %d l %d %d l %d %d l %d %d l %d %d l %d %d l %d %d",
        -bx, -s * 0.35, -bx * 0.3, -s * 0.35,
        bx * 0.6, -s, bx * 0.6, s,
        -bx * 0.3, s * 0.35, -bx, s * 0.35,
        -bx, s * 0.35, -bx, -s * 0.35)
end

function icon.fullscreen(s)
    local a = s          -- outer
    local b = s * 0.42   -- arm length
    local t = s * 0.24   -- thickness
    -- four L-shaped corner brackets
    return
        -- top-left
        string.format("m %d %d l %d %d l %d %d l %d %d l %d %d l %d %d ",
            -a, -a, -a + b, -a, -a + b, -a + t, -a + t, -a + t, -a + t, -a + b, -a, -a + b) ..
        -- top-right
        string.format("m %d %d l %d %d l %d %d l %d %d l %d %d l %d %d ",
            a, -a, a - b, -a, a - b, -a + t, a - t, -a + t, a - t, -a + b, a, -a + b) ..
        -- bottom-left
        string.format("m %d %d l %d %d l %d %d l %d %d l %d %d l %d %d ",
            -a, a, -a + b, a, -a + b, a - t, -a + t, a - t, -a + t, a - b, -a, a - b) ..
        -- bottom-right
        string.format("m %d %d l %d %d l %d %d l %d %d l %d %d l %d %d ",
            a, a, a - b, a, a - b, a - t, a - t, a - t, a - t, a - b, a, a - b)
end

-- ---------------------------------------------------------------------------
-- Layout: compute geometry + hitboxes for the current osd size.
-- ---------------------------------------------------------------------------
local function layout()
    local W, H = osd_size()
    local s = o.scale
    local side   = math.max(40, W * 0.045) * 1.0
    local bottom = 40 * s
    local ph     = 116 * s
    local pad    = 26 * s

    local L = { W = W, H = H, s = s }
    L.px0 = side
    L.px1 = W - side
    L.py1 = H - bottom
    L.py0 = L.py1 - ph
    L.radius = 18 * s
    L.ix0 = L.px0 + pad
    L.ix1 = L.px1 - pad

    -- title row
    L.title_y = L.py0 + pad * 0.75

    -- seek row
    L.time_w = 66 * s
    L.seek_cy = L.py0 + ph * 0.50
    L.seek_x0 = L.ix0 + L.time_w
    L.seek_x1 = L.ix1 - L.time_w
    L.seek_h = 5 * s
    L.handle_r = 8.5 * s

    -- control row
    L.ctrl_cy = L.py1 - pad - 10 * s
    L.center = (L.px0 + L.px1) / 2
    L.play_s = 15 * s
    L.skip_dx = 62 * s
    L.skip_s = 12 * s
    L.vol_x = L.ix0 + 12 * s
    L.vol_s = 12 * s
    L.volbar_x0 = L.vol_x + 22 * s
    L.volbar_x1 = L.volbar_x0 + 78 * s
    L.fs_x = L.ix1 - 12 * s
    L.fs_s = 11 * s

    -- hitboxes (rectangles: x0,y0,x1,y1)
    local hr = 26 * s
    hit = {
        seek     = { L.seek_x0 - L.handle_r, L.seek_cy - hr, L.seek_x1 + L.handle_r, L.seek_cy + hr },
        play     = { L.center - hr, L.ctrl_cy - hr, L.center + hr, L.ctrl_cy + hr },
        back     = { L.center - L.skip_dx - hr, L.ctrl_cy - hr, L.center - L.skip_dx + hr, L.ctrl_cy + hr },
        fwd      = { L.center + L.skip_dx - hr, L.ctrl_cy - hr, L.center + L.skip_dx + hr, L.ctrl_cy + hr },
        vol      = { L.vol_x - 16 * s, L.ctrl_cy - hr, L.vol_x + 16 * s, L.ctrl_cy + hr },
        volbar   = { L.volbar_x0 - 6 * s, L.ctrl_cy - hr, L.volbar_x1 + 6 * s, L.ctrl_cy + hr },
        fs       = { L.fs_x - 16 * s, L.ctrl_cy - hr, L.fs_x + 16 * s, L.ctrl_cy + hr },
    }
    return L
end

local function in_box(box, x, y)
    return box and x >= box[1] and x <= box[3] and y >= box[2] and y <= box[4]
end

local function hovered(name)
    return in_box(hit[name], mouse.x, mouse.y)
end

-- ---------------------------------------------------------------------------
-- Drawing primitives
-- ---------------------------------------------------------------------------
local function text(ass, x, y, an, size, color, op, str)
    ass:new_event()
    ass:append(string.format("{\\pos(%.1f,%.1f)\\an%d\\bord0\\shad0\\fs%.1f\\1c&H%s&\\1a&H%s&\\fnHelvetica Neue}",
        x, y, an, size, color, alpha(op)))
    -- escape braces in titles
    str = tostring(str):gsub("\\", "\\\\"):gsub("{", "\\{"):gsub("}", "\\}")
    ass:append(str)
end

-- place a centred vector icon
local function draw_icon(ass, cx, cy, color, op, path)
    ass:new_event()
    ass:append(string.format("{\\pos(%.1f,%.1f)\\an5\\bord0\\shad0\\1c&H%s&\\1a&H%s&}",
        cx, cy, color, alpha(op)))
    ass:append("{\\p1}")
    ass:append(path)
    ass:append("{\\p0}")
end

-- ---------------------------------------------------------------------------
-- Render one frame
-- ---------------------------------------------------------------------------
local function truncate_title(str, max_chars)
    if #str <= max_chars then return str end
    return str:sub(1, max_chars - 1) .. "…"
end

local function render()
    local L = layout()
    local ass = assdraw.ass_new()

    -- drop shadow
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H000000&\\1a&H%s&\\blur18}", alpha(0.40)))
    ass:draw_start()
    ass:round_rect_cw(L.px0, L.py0 + 6, L.px1, L.py1 + 6, L.radius)
    ass:draw_stop()

    -- panel
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&\\blur0.6}", C.bg, alpha(o.panel_opacity)))
    ass:draw_start()
    ass:round_rect_cw(L.px0, L.py0, L.px1, L.py1, L.radius)
    ass:draw_stop()

    -- hairline top highlight for a glassy edge
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", C.fg, alpha(0.06)))
    ass:draw_start()
    ass:round_rect_cw(L.px0, L.py0, L.px1, L.py0 + 2 * L.s, L.radius)
    ass:draw_stop()

    -- title
    local title = mp.get_property("media-title") or mp.get_property("filename") or ""
    if title ~= "" then
        text(ass, L.ix0, L.title_y, 7, 20 * L.s, C.fg, 0.82,
            truncate_title(title, math.floor((L.ix1 - L.ix0) / (11 * L.s))))
    end

    -- seek data
    local dur = mp.get_property_number("duration") or 0
    local pos = mp.get_property_number("time-pos") or 0
    local frac = 0
    if dragging == "seek" and drag_frac then
        frac = drag_frac
        pos = frac * dur
    elseif dur > 0 then
        frac = clamp(pos / dur, 0, 1)
    end

    -- cache / buffered range end
    local cache_frac = 0
    local demux = mp.get_property_native("demuxer-cache-state")
    if demux and demux["cache-end"] and dur > 0 then
        cache_frac = clamp(demux["cache-end"] / dur, 0, 1)
    end

    local sy = L.seek_cy
    local sh2 = L.seek_h / 2
    -- track
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", C.track, alpha(0.55)))
    ass:draw_start(); ass:round_rect_cw(L.seek_x0, sy - sh2, L.seek_x1, sy + sh2, sh2); ass:draw_stop()
    -- cache
    if cache_frac > 0 then
        local cx = L.seek_x0 + (L.seek_x1 - L.seek_x0) * cache_frac
        ass:new_event()
        ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", C.fg, alpha(0.22)))
        ass:draw_start(); ass:round_rect_cw(L.seek_x0, sy - sh2, cx, sy + sh2, sh2); ass:draw_stop()
    end
    -- fill
    local fx = L.seek_x0 + (L.seek_x1 - L.seek_x0) * frac
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", C.accent, alpha(1.0)))
    ass:draw_start(); ass:round_rect_cw(L.seek_x0, sy - sh2, math.max(L.seek_x0, fx), sy + sh2, sh2); ass:draw_stop()
    -- handle (grows a touch on hover/drag)
    local hr = L.handle_r * ((hovered("seek") or dragging == "seek") and 1.25 or 1.0)
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", C.accent, alpha(1.0)))
    ass:draw_start(); ass:round_rect_cw(fx - hr, sy - hr, fx + hr, sy + hr, hr); ass:draw_stop()

    -- times
    text(ass, L.seek_x0 - 12 * L.s, sy, 6, 15 * L.s, C.fg, 0.85, fmt_time(pos))
    text(ass, L.seek_x1 + 12 * L.s, sy, 4, 15 * L.s, C.fg, 0.85, fmt_time(dur))

    -- controls
    local paused = mp.get_property_bool("pause")
    local cy = L.ctrl_cy
    local acc_if = function(name) return hovered(name) and C.accent or C.fg end

    draw_icon(ass, L.center - L.skip_dx, cy, acc_if("back"), 0.92, icon.skip_back(L.skip_s))
    if paused then
        draw_icon(ass, L.center, cy, acc_if("play"), 1.0, icon.play(L.play_s))
    else
        draw_icon(ass, L.center, cy, acc_if("play"), 1.0, icon.pause(L.play_s))
    end
    draw_icon(ass, L.center + L.skip_dx, cy, acc_if("fwd"), 0.92, icon.skip_fwd(L.skip_s))

    -- volume
    local muted = mp.get_property_bool("mute")
    local vol = mp.get_property_number("volume") or 100
    draw_icon(ass, L.vol_x, cy, (muted or hovered("vol")) and C.accent or C.fg, 0.92, icon.speaker(L.vol_s))
    if muted then
        -- small X to the right of the speaker
        local mx = L.vol_x + L.vol_s * 0.9
        draw_icon(ass, mx, cy, C.accent, 0.92,
            string.format("m %d %d l %d %d m %d %d l %d %d",
                -3, -3, 3, 3, 3, -3, -3, 3))
    end
    -- volume bar
    local vy = cy
    local vh = 3 * L.s
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", C.track, alpha(0.5)))
    ass:draw_start(); ass:round_rect_cw(L.volbar_x0, vy - vh, L.volbar_x1, vy + vh, vh); ass:draw_stop()
    local vfrac = clamp((muted and 0 or vol) / 100, 0, 1)
    local vfx = L.volbar_x0 + (L.volbar_x1 - L.volbar_x0) * vfrac
    ass:new_event()
    ass:append(string.format("{\\pos(0,0)\\an7\\bord0\\shad0\\1c&H%s&\\1a&H%s&}", C.fg, alpha(0.9)))
    ass:draw_start(); ass:round_rect_cw(L.volbar_x0, vy - vh, math.max(L.volbar_x0, vfx), vy + vh, vh); ass:draw_stop()

    -- fullscreen
    draw_icon(ass, L.fs_x, cy, acc_if("fs"), 0.9, icon.fullscreen(L.fs_s))

    overlay.res_x = L.W
    overlay.res_y = L.H
    overlay.data = ass.text
    overlay:update()
end

-- ---------------------------------------------------------------------------
-- Visibility + animation loop
-- ---------------------------------------------------------------------------
local function want_visible()
    if o.show_while_paused and mp.get_property_bool("pause") then return true end
    return (mp.get_time() - last_active) < o.hide_delay
end

local function tick()
    local target = want_visible() and 1 or 0
    -- eased fade
    fade = fade + (target - fade) * 0.28
    if math.abs(target - fade) < 0.02 then fade = target end

    if fade <= 0.001 and target == 0 then
        fade = 0
        overlay:remove()
        if render_timer then render_timer:kill(); render_timer = nil end
        return
    end
    render()
end

local function wake()
    if not render_timer then
        render_timer = mp.add_periodic_timer(1 / 60, tick)
    end
end

local function activity()
    last_active = mp.get_time()
    wake()
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------
local function seek_to_mouse(exact)
    local L = layout()
    local frac = clamp((mouse.x - L.seek_x0) / (L.seek_x1 - L.seek_x0), 0, 1)
    drag_frac = frac
    local flag = exact and "absolute-percent+exact" or "absolute-percent+keyframes"
    mp.commandv("seek", frac * 100, flag)
end

local function vol_to_mouse()
    local L = layout()
    local frac = clamp((mouse.x - L.volbar_x0) / (L.volbar_x1 - L.volbar_x0), 0, 1)
    if mp.get_property_bool("mute") and frac > 0 then mp.set_property_bool("mute", false) end
    mp.set_property_number("volume", math.floor(frac * 100 + 0.5))
end

local function on_mouse_move(_, val)
    if val then mouse.x = val.x or -1; mouse.y = val.y or -1 end
    activity()
    if dragging == "seek" then
        seek_to_mouse(false)
    elseif dragging == "volume" then
        vol_to_mouse()
    end
end

local function on_left(t)
    activity()
    if t.event == "down" then
        if hovered("play") then
            mp.commandv("cycle", "pause")
        elseif hovered("back") then
            mp.commandv("seek", -o.jump_seconds, "relative+keyframes")
        elseif hovered("fwd") then
            mp.commandv("seek", o.jump_seconds, "relative+keyframes")
        elseif hovered("vol") then
            mp.commandv("cycle", "mute")
        elseif hovered("fs") then
            mp.commandv("cycle", "fullscreen")
        elseif hovered("seek") then
            dragging = "seek"; seek_to_mouse(false)
        elseif hovered("volbar") then
            dragging = "volume"; vol_to_mouse()
        end
    elseif t.event == "up" then
        if dragging == "seek" then seek_to_mouse(true) end
        dragging = nil
        drag_frac = nil
    end
end

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------
mp.observe_property("mouse-pos", "native", on_mouse_move)
mp.add_forced_key_binding("MBTN_LEFT", "arche-osc-left", on_left, { complex = true })

-- Redraw promptly when playback state changes while the bar is up.
for _, prop in ipairs({ "pause", "time-pos", "duration", "volume", "mute", "media-title", "fullscreen" }) do
    mp.observe_property(prop, "native", function()
        if fade > 0.001 then wake() end
    end)
end

-- Keep the bar responsive to window/size changes.
mp.observe_property("osd-dimensions", "native", function()
    if fade > 0.001 then wake() end
end)

-- Show briefly on file load so the user sees the controls.
mp.register_event("file-loaded", function() activity() end)
