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
    -- Get the current position
    local x, y, z = gps.locate(5)

    -- Find the vector between the current position and the origin
    local dx = originX - x
    local dy = originY - y
    local dz = originZ - z

    -- If the vector is zero, we're done
    if dx == 0 and dy == 0 and dz == 0 then
        rednet.send(master, "arrived_at_origin")
        return true
    end

    -- Move in the direction of the vector
    -- Forwards is towards negative x, backwards is towards positive x
    while dX ~= 0 do
        if facingForward and dX > 0 then
            turtle.forward()
            dX = dX - 1
        elseif facingForward and dX < 0 then
            turtle.back()
            dX = dX + 1
        elseif not facingForward and dX > 0 then
            turtle.back()
            dX = dX - 1
        elseif not facingForward and dX < 0 then
            turtle.forward()
            dX = dX + 1
        end
    end

    -- When facing forwards, left is towards positive Z, right is towards negative Z
    -- When facing backwards, left is towards negative Z, right is towards positive Z
    while dZ ~= 0 do
        if facingForward and dZ > 0 then
            turtle.left()
            dZ = dZ - 1
        elseif facingForward and dZ < 0 then
            turtle.right()
            dZ = dZ + 1
        elseif not facingForward and dZ > 0 then
            turtle.right()
            dZ = dZ - 1
        elseif not facingForward and dZ < 0 then
            turtle.left()
            dZ = dZ + 1
        end
    end

    while dY ~= 0 do
        if dY > 0 then
            turtle.up()
            dY = dY - 1
        else
            turtle.down()
            dY = dY + 1
        end
    end

    local finalX, finalY, finalZ = gps.locate(5)

    if finalX ~= originX or finalY ~= originY or finalZ ~= originZ then
        rednet.send(master, "failed_to_go_to_origin")
    else
        rednet.send(master, "arrived_at_origin")
    end
end

local function go_to_origin_ignoring_y()
    -- Get the current position
    local x, _, z = gps.locate(5)

    -- Find the vector between the current position and the origin
    local dx = originX - x
    local dz = originZ - z

    -- If the vector is zero, we're done
    if dx == 0 and dz == 0 then
        rednet.send(master, "arrived_at_origin")
        return true
    end

    -- Move in the direction of the vector
    -- Forwards is towards negative x, backwards is towards positive x
    while dX ~= 0 do
        if facingForward and dX > 0 then
            turtle.forward()
            dX = dX - 1
        elseif facingForward and dX < 0 then
            turtle.back()
            dX = dX + 1
        elseif not facingForward and dX > 0 then
            turtle.back()
            dX = dX - 1
        elseif not facingForward and dX < 0 then
            turtle.forward()
            dX = dX + 1
        end
    end

    -- When facing forwards, left is towards positive Z, right is towards negative Z
    -- When facing backwards, left is towards negative Z, right is towards positive Z
    while dZ ~= 0 do
        if facingForward and dZ > 0 then
            turtle.left()
            dZ = dZ - 1
        elseif facingForward and dZ < 0 then
            turtle.right()
            dZ = dZ + 1
        elseif not facingForward and dZ > 0 then
            turtle.right()
            dZ = dZ - 1
        elseif not facingForward and dZ < 0 then
            turtle.left()
            dZ = dZ + 1
        end
    end

    local finalX, _, finalZ = gps.locate(5)

    if finalX ~= originX or finalZ ~= originZ then
        rednet.send(master, "failed_to_go_to_origin")
    else
        rednet.send(master, "arrived_at_origin")
    end
end

function splitString(str, delimiter)
    local result = {}
    local i = 0
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
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
            return
        elseif packet.type == "shutdown" then
            print("Shutting down.")
            writeInfo()
            return
        elseif packet.type == "return_to_origin" then
            print("Returning to origin.")
            go_to_origin()
        end
    end
end

local function mining_loop()
    local progress = 1
    local rowsDone = 0

    while not turtle.detectDown() do
        turtle.down()
    end

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

        if progress ~= 16 then
            turtle.dig()
            turtle.digDown()
            turtle.digUp()
            turtle.forward()
            progress = progress + 1
        elseif progress == 16 then
            if rowsDone ~= 16 then
                if facingForward then
                    turtle.turnRight()
                    turtle.dig()
                    turtle.forward()
                    turtle.digUp()
                    turtle.digDown()
                    turtle.turnRight()
                    turtle.digUp()
                    turtle.digDown()
                else
                    turtle.turnLeft()
                    turtle.dig()
                    turtle.forward()
                    turtle.digUp()
                    turtle.digDown()
                    turtle.turnLeft()
                    turtle.digUp()
                    turtle.digDown()
                end

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
