--@module = true
--@enable = true

local overlay = require('plugins.overlay')

local stocks = df.global.game.main_interface.stocks

local VALUE_WIDTH = 9
local ITEM_TEXT_SCAN_LEFT_PCT = 0.30
local ITEM_TEXT_SCAN_RIGHT_PCT = 0.66

local function get_tile_ch(x, y)
    local ok, pen = pcall(dfhack.screen.readTile, x, y)
    if not ok or not pen or not pen.ch or pen.ch < 0 or pen.ch > 255 then
        return nil
    end
    return string.char(pen.ch)
end

local function get_tile_bg(x, y)
    local ok, pen = pcall(dfhack.screen.readTile, x, y)
    if ok and pen and pen.bg then
        return pen.bg
    end
    return COLOR_BLACK
end

local function is_text_ch(ch)
    if not ch then return false end
    return ch:match('[%w%p]') and ch ~= '-' and ch ~= '_' and ch ~= '|' and ch ~= '/'
end

local function get_row_text(x1, x2, y)
    local chars = {}
    for x=x1,x2 do
        local ch = get_tile_ch(x, y)
        if ch and ch ~= ' ' then
            table.insert(chars, ch)
        end
    end
    return table.concat(chars)
end

local function normalize_item_text(text)
    if not text then return '' end
    return text:lower():gsub('[^%w]+', '')
end

local function is_item_action_row(y, action_x)
    local saw_x = false
    local saw_o = false
    for x=action_x-8,action_x+6 do
        local ch = get_tile_ch(x, y)
        saw_x = saw_x or ch == 'x' or ch == 'X'
        saw_o = saw_o or ch == 'o' or ch == 'O' or ch == '0'
    end
    return saw_x and saw_o
end

local function get_item_list_rows()
    local screen_w, screen_h = dfhack.screen.getWindowSize()
    local rows = {}
    local text_x1 = math.floor(screen_w * ITEM_TEXT_SCAN_LEFT_PCT)
    local text_x2 = math.floor(screen_w * ITEM_TEXT_SCAN_RIGHT_PCT)
    local item_pane_action_x = math.floor(screen_w * 0.735)

    for y=2,screen_h-1 do
        local text_count = 0
        for x=text_x1,text_x2 do
            if is_text_ch(get_tile_ch(x, y)) then
                text_count = text_count + 1
            end
        end

        if text_count >= 6 then
            local row_text = get_row_text(text_x1, text_x2, y)
            if not row_text:match('^%.+%p*$') then
                table.insert(rows, {
                    y=y,
                    action_x=item_pane_action_x,
                    text=row_text,
                    norm=normalize_item_text(row_text),
                    is_item=is_item_action_row(y, item_pane_action_x),
                })
            end
        end
    end
    return rows
end

local function get_item_start_for_slot(slot)
    if not stocks.current_type_a_amount or #stocks.current_type_a_amount == 0 then
        return math.max(0, slot)
    end

    local cur_slot = 0
    local item_idx = 0
    for group_idx=0,#stocks.current_type_a_amount-1 do
        if cur_slot >= slot then return item_idx end
        cur_slot = cur_slot + 1

        local amount = stocks.current_type_a_amount[group_idx]
        if stocks.current_type_a_expanded[group_idx] then
            for _=1,amount do
                if cur_slot >= slot then return item_idx end
                cur_slot = cur_slot + 1
                item_idx = item_idx + 1
            end
        else
            item_idx = item_idx + amount
        end
    end

    return item_idx
end

local function item_matches_row(item, row)
    if not item or not row or not row.norm or #row.norm < 3 then return false end
    local ok, desc = pcall(dfhack.items.getDescription, item, 0, true)
    if not ok then return false end
    local norm = normalize_item_text(desc)
    return norm:find(row.norm, 1, true) or row.norm:find(norm, 1, true)
end

local function find_visible_item(row, item_idx)
    local list = stocks.current_type_i_list
    if not list then return nil, item_idx end

    local max_idx = #list - 1
    local start_idx = math.max(0, item_idx - 4)
    local end_idx = math.min(max_idx, item_idx + 80)
    for i=start_idx,end_idx do
        local item = list[i]
        if item_matches_row(item, row) then
            return item, i + 1
        end
    end

    return list[item_idx], item_idx + 1
end

local function paint_item_value(item, row)
    if not item then return end

    local ok, value = pcall(dfhack.items.getValue, item)
    if not ok or not value or value <= 0 then return end

    local value_text = string.format('%' .. (VALUE_WIDTH - 1) .. 'd%s', value, string.char(15))
    local x = math.max(1, row.action_x - VALUE_WIDTH - 2)
    local bg = get_tile_bg(x, row.y)
    dfhack.screen.paintString({fg=COLOR_YELLOW, bg=bg}, x, row.y, value_text)
end

StockValueOverlay = defclass(StockValueOverlay, overlay.OverlayWidget)
StockValueOverlay.ATTRS{
    desc='Shows exact item values inline on the stocks page.',
    default_enabled=true,
    fullscreen=true,
    viewscreens='dwarfmode/Stocks',
    frame={w=1, h=1},
}

function StockValueOverlay:preUpdateLayout(parent_rect)
    self.frame.w = parent_rect.width
    self.frame.h = parent_rect.height
end

function StockValueOverlay:onRenderFrame()
    if not stocks.open or not stocks.current_type_i_list then return end

    local rows = get_item_list_rows()
    if #rows == 0 then return end

    local item_idx = get_item_start_for_slot(stocks.scroll_position_item // 3)
    for _,row in ipairs(rows) do
        if row.is_item then
            local item
            item, item_idx = find_visible_item(row, item_idx)
            paint_item_value(item, row)
        end
    end
end

OVERLAY_WIDGETS = {
    values=StockValueOverlay,
}
