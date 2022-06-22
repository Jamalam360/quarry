local monitor = peripheral.wrap("right")

local width, height = monitor.getSize()
local y = 1

local function checkY() 
    if y > height then
        y = 1
    end
end

function log(msg)
    checkY()
    monitor.setCursorPos(1, y)
    monitor.write(msg)
    y = y + 1
end

function error(msg) 
    checkY()
    monitor.setCursorPos(1, y)
    monitor.setTextColor(colors.red)
    monitor.write(msg)
    y = y + 1
end
