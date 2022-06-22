local files = {
    inventory = "https://raw.githubusercontent.com/Jamalam360/quarry/main/turtle/inventory.lua",
    turtle = "https://raw.githubusercontent.com/Jamalam360/quarry/main/turtle/turtle.lua",
}

for name, url in pairs(files) do
    if fs.exists(name) then
        fs.delete(name)
    end

    print("Downloading " .. name)

    local file = fs.open(name, "w")
    local response = http.get(url)
    if response then
        file.write(response.readAll())
        response.close()
        file.close()
    else
        print("Failed to download " .. name )
    end
end
