os.loadAPI("trash_list")
os.loadAPI("output")

local trash = trash_list.read()
local turtles = {}

if trash == trash_list.NOT_FOUND then
    handleFailure("No trash list found.")
    return
end

rednet.open("top")

if not rednet.isOpen("top") then
    handleFailure("No Rednet connection.")
    return
end

local function removeTurtle(id) 
    for i, turtle in ipairs(turtles) do
        if turtle.id == id then
            table.remove(turtles, i)
            return
        end
    end
end

local function sendToAll(msg)
    for i = 1, #turtles do
        rednet.send(turtles[i], msg)
    end
end

local function handleFailure(msg)
    output.error(msg)
    rednet.close("top")
    sendToAll("master_failure")
end

local function network_loop()
    while true do
        local _, id, message = os.pullEvent("rednet_message")

        if message == "initial_handshake" then
            rednet.send(id, os.getComputerID())
            table.insert(turtles, "initial_handshake_response : ")
            log(id .. " connected to master.")
        elseif message == "request_trash_list" then
            rednet.send(id, "request_trash_list_response : " .. trash)
            log(id .. " requested trash list.")
        elseif message == "inventory_full" then 
            log(id .. " is returning to its origin to drop off items.")
        elseif message == "failed_to_go_to_origin" then 
            log(id .. " failed to go to its origin, shutting down.")
            rednet.send(id, "shutdown")
            removeTurtle(id)
        elseif message == "arrived_at_origin" then
            log(id .. " arrived at its origin.") 
        elseif message == "failed_to_unload_items" then 
            log(id .. " failed to unload items, shutting down.")
            rednet.send(id, "shutdown")
        elseif message == "begin_new_layer" then 
            log (id .. " is beginning a new layer.")
        elseif message == "try_refuel" then
            log(id .. " is trying to refuel.")
        elseif message == "refuel_success" then
            log(id .. " successfully refueled.")
        elseif message == "refuel_failure" then
            log(id .. " failed to refuel, shutting down.")
            rednet.send(id, "shutdown")
        end
    end
end

local function input_loop()
    while true do
        local event, key = os.pullEvent("key")

        if key == keys.enter then
            local input = read()
            if input == "UPDATE_TRASH_LIST" then
                trash = trash_list.read()

                if trash == trash_list.NOT_FOUND then
                    handleFailure("No trash list found.")
                    return
                end

                sendToAll("update_trash_list")
            elseif input == "RETURN_ALL" then 
                sendToAll("return_to_origin")
            elseif input == "SHUTDOWN_ALL" then 
                sendToAll("shutdown")
            end
        end
    end
end

parallel.waitForAny(input_loop, network_loop)
