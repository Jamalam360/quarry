os.loadAPI("inventory")

rednet.open("left")

local master = 0
local trash = {};
local facingForward = true;

local originX, originY, originZ = gps.locate(5)

if fs.exists("origin.txt") then
    local file = fs.open("origin.txt", "r")
    originX = tonumber(file.readLine())
    originY = tonumber(file.readLine())
    originZ = tonumber(file.readLine())
    facingForward = file.readLine() == "true"
    file.close()
elseif not originX then
    print("Failed to triangulate position")
    return
end

local function writeInfo()
    fs.delete("origin.txt")
    local file = fs.open("origin.txt", "w")
    file.writeLine(originX)
    file.writeLine(originY)
    file.writeLine(originZ)
    file.writeLine(facingForward)
    file.close()
end

local function go_to_origin()
    local current = vector.new(gps.locate(5))
    local target = vector.new(x, y, z)
    local direction = target - current

    -- Move to the target using direction.x, direction.y, direction.z
    -- Forward is towards negative X
    if facingForward then
        if direction.x < 0 then
            for i = 1, direction.x do
                turtle.forward()
            end
        elseif direction.x > 0 then
            for i = 1, direction.x do
                turtle.back()
            end
        end

        if direction.z < 0 then
            for i = 1, direction.z do
                turtle.right()
            end
        elseif direction.z > 0 then
            for i = 1, direction.z do
                turtle.left()
            end
        end
    end

    if direction.y < 0 then
        for i = 1, direction.y do
            turtle.up()
        end
    end

    if not facingForward then
        turtle.turnLeft()
        turtle.turnLeft()
        facingForward = true
    end

    local finalX, finalY, finalZ = gps.locate(5)

    if finalX ~= originX or finalY ~= originY or finalZ ~= originZ then
        rednet.send(master, "failed_to_go_to_origin")
        print("Origin: " .. originX .. "," .. originY .. "," .. originZ)
        print("Final: " .. finalX .. "," .. finalY .. "," .. finalZ)
        return
    else
        rednet.send(master, "arrived_at_origin")
    end
end

local function go_to_origin_not_y()
    local current = vector.new(gps.locate(5))
    local target = vector.new(x, y, z)
    local direction = target - current

    -- Move to the target using direction.x, direction.y, direction.z
    -- Forward is towards negative X
    if not facingForward then
        if direction.x > 0 then
            for i = 1, direction.x do
                turtle.forward()
            end
        elseif direction.x < 0 then
            for i = 1, direction.x do
                turtle.back()
            end
        end

        if direction.z > 0 then
            for i = 1, direction.z do
                turtle.right()
            end
        elseif direction.z < 0 then
            for i = 1, direction.z do
                turtle.left()
            end
        end
    elseif facingForward then
        if direction.x < 0 then
            for i = 1, direction.x do
                turtle.forward()
            end
        elseif direction.x > 0 then
            for i = 1, direction.x do
                turtle.back()
            end
        end

        if direction.z < 0 then
            for i = 1, direction.z do
                turtle.right()
            end
        elseif direction.z > 0 then
            for i = 1, direction.z do
                turtle.left()
            end
        end
    end

    if not facingForward then
        turtle.turnLeft()
        turtle.turnLeft()
        facingForward = true
    end

    local finalX, finalY, finalZ = gps.locate(5)

    if finalX ~= originX or finalY ~= originY or finalZ ~= originZ then
        rednet.send(master, "failed_to_go_to_origin")
        return
    else
        rednet.send(master, "arrived_at_origin")
    end
end

function splitString(str, delimiter)
    local result = {}
    local i = 0
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        i = i + 1
        result[i] = match
    end
    return result
end

function get_packet_info(packet)
    local info = {}
    local packet_info = splitString(packet, " : ")
    info.type = packet_info[1]
    info.data = packet_info[2]
    return info
end

local function network_loop()
    if master == 0 then
        print("Failed to locate master.")
    end

    while true do
        local _, id, message = os.pullEvent("rednet_message")
        local packet = get_packet_info(message)

        if packet.type == "update_trash_list" then
            rednet.send(master, "request_trash_list")
        elseif packet.type == "request_trash_list_response" then
            trash = packet.data
        elseif packet.type == "master_failure" then
            go_to_origin()
            os.shutdown()
        elseif packet.type == "shutdown" then
            writeInfo()
            os.shutdown()
        end
    end
end

local function mining_loop()
    local progress = 1
    local rowsDone = 0

    while true do
        if turtle.getFuelLevel() == 0 then
            rednet.send(master, "try_refuel")

            if inventory.selectItem("minecraft:coal") then
                turtle.refuel(turtle.getItemCount())
                rednet.send(master, "refuel_success")
            elseif inventory.selectItem("minecraft:charcoal") then
                turtle.refuel(turtle.getItemCount())
                rednet.send(master, "refuel_success")
            else
                rednet.send(master, "refuel_failure")
                return
            end
        end

        if inventory.isInventoryFull() then
            inventory.stackItems()
            inventory.dropTrash(trash)

            if inventory.isInventoryFull() then
                rednet.send(master, "inventory_full")
                go_to_origin()

                -- Unload items into the chest behind the turtle
                turtle.turnLeft()
                turtle.turnLeft()
                local success, data = turtle.inspect()

                if success then
                    if data.name == "minecraft:chest" then
                        for i = 1, 16 do
                            turtle.select(i)

                            data = turtle.getItemDetail()

                            if data ~= nil and data.name ~= "minecraft:coal" then
                                turtle.drop()
                            end
                        end
                    else
                        rednet.send(master, "failed_to_unload_items")
                        return
                    end
                else
                    rednet.send(master, "failed_to_unload_items")
                    return
                end
            end
        end

        while not turtle.detectDown() do
            turtle.down()
        end

        if progress ~= 16 then
            turtle.dig()
            turtle.digDown()
            turtle.digUp()
            turtle.forward()
            progress = progress + 1
        elseif progress == 16 then
            if rowsDone ~= 16 then
                turtle.turnRight()
                turtle.dig()
                turtle.forward()
                turtle.turnRight()
                turtle.digUp()
                turtle.digDown()
                progress = 1
                facingForward = not facingForward
                rowsDone = rowsDone + 1
            elseif rowsDone == 16 then
                rednet.send(master, "begin_new_layer")
                go_to_origin_not_y()
                turtle.down()
                turtle.digDown()
                turtle.down()
                turtle.digDown()
                turtle.down()
                rowsDone = 0
                progress = 1
            end
        end
    end
end

rednet.broadcast("initial_handshake")

while true do 
    local _, _, message = os.pullEvent("rednet_message")
    local packet = get_packet_info(message)

    if packet.type == "initial_handshake_response" then
        master = tonumber(packet.data)
        break
    end
end

rednet.send(master, "request_trash_list")
_, msg = rednet.receive()
trash = splitString(msg, ",")

go_to_origin()

parallel.waitForAny(network_loop, mining_loop)

writeInfo()
