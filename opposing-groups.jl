
using JSON
using DataFrames

require("./src/influence-game.jl")

function load_contributions(bill, contribs_path)
    session = bill["session"]
    prefix = bill["prefix"]
    num = bill["num"]
    aid = bill["actionId"]

    contrib_path = joinpath(contribs_path, "$session-$prefix-$num-$aid-contributions.csv")
    contrib_data = Dict()

    try
        contrib_table = readtable(contrib_path)

        for contrib in eachrow(contrib_table)
            catcode = contrib[:Contributor_Interest_Group_Code]
            amount = int(replace(contrib[:Contribution_Amount], '$', ""))

            get!(contrib_data, catcode, 0)
            contrib_data[catcode] += amount
        end

    finally
        return contrib_data
    end
end

function money_info(money_data, code1, code2)
    victories = { code1 => 0, code2 => 0 }
    average = { code1 => 0, code2 => 0 }

    for (aid, data) in money_data
        money1 = data[code1]
        money2 = data[code2]

        average[code1] += money1
        average[code2] += money2

        money1 > money2 ? (victories[code1] += 1) : (victories[code2] += 1)
    end

    average[code1] /= length(money_data)
    average[code2] /= length(money_data)

    return victories, average
end

bills = JSON.parse(readall("./data/113th-bills.json"))
industries = JSON.parse(readall("./data/crp-categories.json"))

bills = InfluenceGame.filter_has_votes(bills)
bills = InfluenceGame.filter_overlapping_votes(bills)

opposing_groups = Dict()

for (aid, bill) in bills
    positions = bill["positions"]
    supporters = positions["support"]
    opposers = positions["oppose"]

    contributions = load_contributions(bill, "./data/15-1-23-contributions-113")

    for s in supporters
        for o in opposers
            pair = s < o ? (s, o) : (o, s)

            stats = get!(opposing_groups, pair, {
                "total" => 0,
                "vote_favors" => { s => String[], o => String[] },
                "money" => Dict(),
                "total_money_favors" => { s => String[], o => String[] },
                "supported_by" => { s => String[], o => String[] },
            })

            stats["total"] += 1
            push!(stats["supported_by"][s], aid)

            stats["money"][aid] = { s => get(contributions, s, 0), o => get(contributions, o, 0) }

            money_for = bill["money"]["totalFor"]
            money_against = bill["money"]["totalAgainst"]

            favored = money_for >= money_against ? stats["total_money_favors"][s] : stats["total_money_favors"][o]
            push!(favored, aid)

            favored = bill["passed"] ? stats["vote_favors"][s] : stats["vote_favors"][o]
            push!(favored, aid)

        end
    end
end

for (pair, data) in opposing_groups
    data["money_averages"] = money_info(data["money"], pair[1], pair[2])[2]
end

biggest_adversaries = collect(opposing_groups)
sort!(biggest_adversaries, lt = (lhs, rhs)->lhs[2]["total"] > rhs[2]["total"])

for adversaries in biggest_adversaries[1:20]
    id1 = adversaries[1][1]
    id2 = adversaries[1][2]
    name1 = industries[id1]["Catname"]
    name2 = industries[id2]["Catname"]

    vote_favors = { id => length(votes) for (id, votes) in adversaries[2]["vote_favors"] }
    money_averages = adversaries[2]["money_averages"]
    total_money_favors = { id => length(bills) for (id, bills) in adversaries[2]["total_money_favors"] }
    supported_by = { id => length(bills) for (id, bills) in adversaries[2]["supported_by"] }
    println("$name1 ($id1) | $name2 ($id2) >> total: $(adversaries[2]["total"]), supported_by: $supported_by, vote_favors: $vote_favors, money_averages: $money_averages")
end
