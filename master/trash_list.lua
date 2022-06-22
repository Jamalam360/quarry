NOT_FOUND = "NOT_FOUND"
 
function read()
    local file = fs.open("trash_list.txt", "r")
    if not file then
        return NOT_FOUND
    end

    local arr = {}
    local line = file.readLine()
    
    while line do
        table.insert(arr, line)
        line = file.readLine()
    end

    file.close()
    return arr
end