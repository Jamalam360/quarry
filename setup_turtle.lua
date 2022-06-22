local files = {
    inventory = "https://raw.githubusercontent.com/Jamalam360/quarry/main/turtle/inventory.lua",
    turtle = "https://raw.githubusercontent.com/Jamalam360/quarry/main/turtle/turtle.lua",
}

for name, url in pairs(files) do
    if fs.exists(name .. ".lua") then
        fs.delete(name .. ".lua")
    end

    print("Downloading " .. name .. ".lua")

    local file = fs.open(name .. ".lua", "w")
    local response = http.get(url)
    if response then
        file.write(response.readAll())
        response.close()
        file.close()
    else
        print("Failed to download " .. name .. ".lua")
    end
end
