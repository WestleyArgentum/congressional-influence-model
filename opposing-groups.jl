
using JSON

require("./src/influence-game.jl")

bills = JSON.parse(readall("./data/113th-bills.json"))
industries = JSON.parse(readall("./data/crp-categories.json"))

bills = InfluenceGame.filter_has_votes(bills)
bills = InfluenceGame.filter_overlapping_votes(bills)

opposing_groups = Dict()

for (aid, bill) in bills
    positions = bill["positions"]
    supporters = positions["support"]
    opposers = positions["oppose"]

    for s in supporters
        for o in opposers
            pair = s < o ? (s, o) : (o, s)

            get!(opposing_groups, pair, {
                "total" => 0,
                "vote_favors" => { s => String[], o => String[] },
                "money_favors" => { s => String[], o => String[] },
                "supported_by" => { s => String[], o => String[] },
            })

            stats = opposing_groups[pair]
            stats["total"] += 1
            push!(stats["supported_by"][s], aid)

            money_for = bill["money"]["totalFor"]
            money_against = bill["money"]["totalAgainst"]

            favored = money_for >= money_against ? stats["money_favors"][s] : stats["money_favors"][o]
            push!(favored, aid)

            favored = bill["passed"] ? stats["vote_favors"][s] : stats["vote_favors"][o]
            push!(favored, aid)

        end
    end
end

biggest_adversaries = collect(opposing_groups)
sort!(biggest_adversaries, lt = (lhs, rhs)->lhs[2]["total"] > rhs[2]["total"])

for adversaries in biggest_adversaries
    group1 = industries[adversaries[1][1]]["Catname"]
    group2 = industries[adversaries[1][2]]["Catname"]

    vote_favors = { id => length(votes) for (id, votes) in adversaries[2]["vote_favors"] }
    money_favors = { id => length(bills) for (id, bills) in adversaries[2]["money_favors"] }
    supported_by = { id => length(bills) for (id, bills) in adversaries[2]["supported_by"] }
    println("$group1 | $group2  -- total: $(adversaries[2]["total"]), supported_by: $supported_by, vote_favors: $vote_favors, money_favors: $money_favors")
end
