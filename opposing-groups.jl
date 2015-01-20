
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
                "oppose" => { s => 0, o => 0 },
                "support" => { s => 0, o => 0 }
            })

            stats = opposing_groups[pair]
            stats["total"] += 1
            stats["support"][s] += 1
            stats["oppose"][o] += 1

            if bill["passed"]
                push!(stats["vote_favors"][s], aid)
            else
                push!(stats["vote_favors"][o], aid)
            end

        end
    end
end

biggest_adversaries = collect(opposing_groups)
sort!(biggest_adversaries, lt = (lhs, rhs)->lhs[2]["total"] > rhs[2]["total"])

for adversaries in biggest_adversaries
    group1 = industries[adversaries[1][1]]["Catname"]
    group2 = industries[adversaries[1][2]]["Catname"]
    println("$group1 | $group2  -- total: $(adversaries[2]["total"]), support: $(adversaries[2]["support"])")
end