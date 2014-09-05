
using JSON
using MapLight

function join_bill_data(position_file, description_folder)
    bills = Dict()

    descriptions = readdir(description_folder)
    for desc in descriptions
        data = JSON.parse(readall(joinpath(description_folder, desc)))
        bills[data["actionId"]] = data
    end

    positions = JSON.parse(readall(position_file))
    for (aid, data) in positions
        bills[aid]["positions"] = data
    end

    bills
end
