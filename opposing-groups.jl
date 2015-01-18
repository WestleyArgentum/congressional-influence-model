
using JSON

bills = JSON.parse(readall("./data/113th-bills.json"))
industries = JSON.parse(readall("./data/crp-categories.json"))

opposing_groups = Dict()

for (aid, bill) in bills
    positions = bill["positions"]
    supporters = positions["support"]
    opposers = positions["oppose"]

    for s in supporters
        for o in opposers
            pair = s < o ? (s, o) : (o, s)
            get!(opposing_groups, pair, 0)
            opposing_groups[pair] += 1
        end
    end
end

biggest_adversaries = collect(opposing_groups)
sort!(biggest_adversaries, lt = (lhs, rhs)->lhs[2] > rhs[2])

for adversaries in biggest_adversaries
    group1 = industries[adversaries[1][1]]["Catname"]
    group2 = industries[adversaries[1][2]]["Catname"]
    println("$group1 | $group2  ($(adversaries[2]))")
end