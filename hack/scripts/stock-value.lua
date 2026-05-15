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

local function is_screen_item_row(row_text)
    local first_alpha = row_text:match('[A-Za-z]')
    if not first_alpha then return false end
    return first_alpha:match('%l') ~= nil
end

local function get_item_list_rows()
    local screen_w, screen_h = dfhack.screen.getWindowSize()
    local rows = {}
    local text_x1 = math.floor(screen_w * ITEM_TEXT_SCAN_LEFT_PCT)
    local text_x2 = math.floor(screen_w * ITEM_TEXT_SCAN_RIGHT_PCT)
    local item_pane_action_x = math.floor(screen_w * 0.735)

    for y=2,screen_h-3 do
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
                    is_item=is_screen_item_row(row_text),
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
            paint_item_value(stocks.current_type_i_list[item_idx], row)
            item_idx = item_idx + 1
        end
    end
end

OVERLAY_WIDGETS = {
    values=StockValueOverlay,
}
