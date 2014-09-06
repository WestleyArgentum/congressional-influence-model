
using JSON
using MapLight

using DataFrames

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

function build_industry_table(maplight_bulk_file)
    bulk_table = readtable(maplight_bulk_file)
    { r[:Catcode] => r[:Industry] for r in eachrow(bulk_table) }
end