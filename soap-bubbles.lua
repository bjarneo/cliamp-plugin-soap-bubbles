-- soap-bubbles.lua — Floating soap bubbles that pulse and shimmer with the music.
--
-- Each bubble is a hollow circle drawn with Braille dots. Bubbles drift upward,
-- gently swaying side to side. Bass energy inflates them, treble energy makes
-- them wobble and shimmer. When a bubble reaches the top it wraps around.
--
-- Install: copy to ~/.config/cliamp/plugins/soap-bubbles.lua
-- Cycle to it with the 'v' key.

local p = plugin.register({
    name        = "soap-bubbles",
    type        = "visualizer",
    version     = "1.0.0",
    description = "Floating soap bubbles that react to music",
})

-- Persistent state across frames.
local bubbles = {}
local rows = 5
local cols = 74
local num_bubbles = 14
local initialized = false

-- Pseudo-random number from a seed (deterministic per bubble).
local function hash(seed)
    local h = seed * 2654435761
    h = h % 2147483647
    return (h % 10000) / 10000
end

-- Braille dot bit values: [row][col] (0-indexed).
-- Row 0-2 use bits 0-5, row 3 uses bits 6-7.
local dot_bit = {
    [0] = { [0] = 0x01, [1] = 0x08 },
    [1] = { [0] = 0x02, [1] = 0x10 },
    [2] = { [0] = 0x04, [1] = 0x20 },
    [3] = { [0] = 0x40, [1] = 0x80 },
}

local function init_bubbles()
    bubbles = {}
    for i = 1, num_bubbles do
        local seed = i * 7919
        bubbles[i] = {
            -- Position in dot-space (cols*2 wide, rows*4 tall).
            x = hash(seed + 1) * cols * 2,
            y = hash(seed + 2) * rows * 4,
            -- Base radius (3-8 dots), larger bubbles rise slower.
            base_r = 3 + hash(seed + 3) * 5,
            -- Rise speed (dots per frame).
            speed = 0.15 + hash(seed + 4) * 0.25,
            -- Sway phase offset.
            phase = hash(seed + 5) * math.pi * 2,
            -- Which frequency band drives this bubble (1-10).
            band = (i % 10) + 1,
            -- Shimmer offset for the outline.
            shimmer = hash(seed + 6) * math.pi * 2,
        }
    end
    initialized = true
end

function p:init(r, c)
    rows = r
    cols = c
    initialized = false
end

function p:render(bands, frame, r, c)
    -- Update dimensions from render args (handles fullscreen toggle).
    if r and r > 0 then rows = r end
    if c and c > 0 then cols = c end

    if not initialized then
        init_bubbles()
    end

    local dot_rows = rows * 4
    local dot_cols = cols * 2

    -- Average energy for global effects.
    local total = 0
    for i = 1, 10 do
        total = total + bands[i]
    end
    local avg = total / 10

    -- Update bubble positions.
    for _, b in ipairs(bubbles) do
        -- Rise speed scales with energy (bubbles float faster when loud).
        local rise = b.speed * (1 + avg * 2)
        b.y = b.y - rise

        -- Wrap around when bubble exits the top.
        if b.y < -(b.base_r * 2 + 4) then
            b.y = dot_rows + b.base_r + 2
        end

        -- Gentle lateral sway.
        local sway = math.sin(frame * 0.02 + b.phase) * 2.5
        b.x = b.x + sway * 0.08
        -- Wrap horizontally.
        if b.x < -b.base_r then b.x = b.x + dot_cols end
        if b.x > dot_cols + b.base_r then b.x = b.x - dot_cols end
    end

    -- Build dot grid.
    local grid = {}
    -- Color tier grid: 0=green, 1=yellow, 2=red (used for gradient).
    local color = {}
    for i = 0, dot_rows * dot_cols - 1 do
        grid[i] = false
        color[i] = 0
    end

    for _, b in ipairs(bubbles) do
        local energy = bands[b.band]
        -- Radius pulses with the bubble's frequency band.
        local r = b.base_r * (0.7 + energy * 0.6)
        -- Wobble: slight eccentricity driven by treble.
        local treble = (bands[8] + bands[9] + bands[10]) / 3
        local wobble = 1.0 + treble * 0.15 * math.sin(frame * 0.08 + b.shimmer)

        -- Determine color tier by energy.
        local tier
        if energy > 0.6 then
            tier = 2
        elseif energy > 0.3 then
            tier = 1
        else
            tier = 0
        end

        -- Draw hollow circle outline with Braille dots.
        -- Sample points around the circumference.
        local circumference = math.max(16, math.floor(2 * math.pi * r * 1.5))
        for s = 0, circumference - 1 do
            local angle = (s / circumference) * 2 * math.pi
            -- Shimmer: slight radius variation along the circumference.
            local shimmer_r = r * (1 + 0.06 * math.sin(angle * 3 + frame * 0.12 + b.shimmer))
            local dx = math.cos(angle) * shimmer_r * wobble
            local dy = math.sin(angle) * shimmer_r
            local px = math.floor(b.x + dx + 0.5)
            local py = math.floor(b.y + dy + 0.5)

            if px >= 0 and px < dot_cols and py >= 0 and py < dot_rows then
                local idx = py * dot_cols + px
                grid[idx] = true
                if tier > color[idx] then
                    color[idx] = tier
                end
            end
        end

        -- Specular highlight: a small bright arc near the top-left of the bubble.
        if r > 3 then
            local highlight_r = r * 0.55
            local highlight_cx = b.x - r * 0.25
            local highlight_cy = b.y - r * 0.3
            for s = 0, 7 do
                local angle = (-0.4 + s * 0.1)
                local hx = math.floor(highlight_cx + math.cos(angle) * highlight_r + 0.5)
                local hy = math.floor(highlight_cy + math.sin(angle) * highlight_r + 0.5)
                if hx >= 0 and hx < dot_cols and hy >= 0 and hy < dot_rows then
                    local idx = hy * dot_cols + hx
                    grid[idx] = true
                    color[idx] = 2 -- bright highlight
                end
            end
        end
    end

    -- Render dot grid to Braille characters with color.
    local lines = {}
    -- Style escape codes for spectrum colors (matches cliamp's green/yellow/red).
    -- We use simple ANSI since Lua plugins return plain strings.
    -- The built-in specStyle uses lipgloss which isn't available here,
    -- so we just return unstyled Braille — cliamp renders it as-is.
    for row = 0, rows - 1 do
        local chars = {}
        for ch = 0, cols - 1 do
            local braille = 0x2800
            for dr = 0, 3 do
                for dc = 0, 1 do
                    local idx = (row * 4 + dr) * dot_cols + ch * 2 + dc
                    if grid[idx] then
                        braille = braille + dot_bit[dr][dc]
                    end
                end
            end
            chars[#chars + 1] = utf8.char(braille)
        end
        lines[#lines + 1] = table.concat(chars)
    end

    return table.concat(lines, "\n")
end
