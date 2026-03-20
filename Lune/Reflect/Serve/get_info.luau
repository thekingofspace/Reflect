local fs = require("@lune/fs")
local serde = require("@lune/serde")
local types = require("../types")
if not fs.isFile("./Reflect.init.json") then
    return {}
end
return serde.decode("json", fs.readFile("./Reflect.init.json"))::types.project_info
