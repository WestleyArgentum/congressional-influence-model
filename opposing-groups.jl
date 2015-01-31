
using JSON
using DataFrames

function filter_overlapping_votes(bills)
    overlap = Any[]
    for (k,v) in bills
        for (k2,v2) in bills
            if k != k2 && v["num"] == v2["num"] && v["prefix"] == v2["prefix"]
                if !([k, k2] in overlap) && !([k2, k] in overlap)
                    push!(overlap, [k, k2])
                end
            end
        end
    end

    for (id1, id2) in overlap
        (haskey(bills, id1) && haskey(bills, id2)) || continue

        passed1 = get(bills[id1], "dateVote", -1)
        passed2 = get(bills[id2], "dateVote", -2)
        if passed1 == passed2
            delete!(bills, id1)
        end
    end

    bills
end

function filter_has_votes(bills)
    bills_with_votes = filter((k,b)->get(b, "action", "") == "passage", bills)
end

function load_contributions(bill, contribs_path)
    session = bill["session"]
    prefix = bill["prefix"]
    num = bill["num"]
    aid = bill["actionId"]

    contrib_path = joinpath(contribs_path, "$session-$prefix-$num-$aid-contributions.csv")
    !isfile(contrib_path) && error("Cannot find contrib data (looking for $contrib_path).\nMaybe you need to download the data using https://github.com/WestleyArgentum/maplight-scraper")

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

function compute_opposing_groups(bills)
    opposing_groups = Dict()

    for (aid, bill) in bills
        println( ">> $(bill["session"])-$(bill["prefix"])-$(bill["num"])-$(bill["actionId"])")

        positions = bill["positions"]
        supporters = positions["support"]
        opposers = positions["oppose"]

        contributions = load_contributions(bill, "./data/113th-contributions")

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

    opposing_groups
end

function show_opposing_groups(opposing_groups::Dict, industries)
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
end

function generate_vote_favors_table(opposing_groups::Dict, industries)
    biggest_adversaries = collect(opposing_groups)
    sort!(biggest_adversaries, lt = (lhs, rhs)->lhs[2]["total"] > rhs[2]["total"])

    raw_votes = [ collect(adversaries[2]["vote_favors"]) for adversaries in biggest_adversaries ]

    group1_column = String[]
    group2_column = String[]
    votes1_column = Int[]
    votes2_column = Int[]
    totals_column = Int[]

    for votes in raw_votes
        group1 = industries[votes[1][1]]["Catname"]
        group2 = industries[votes[2][1]]["Catname"]
        votes1 = length(votes[1][2])
        votes2 = length(votes[2][2])

        if votes1 >= votes2
            push!(group1_column, group1)
            push!(votes1_column, votes1)
            push!(group2_column, group2)
            push!(votes2_column, votes2)
        else
            push!(group2_column, group1)
            push!(votes2_column, votes1)
            push!(group1_column, group2)
            push!(votes1_column, votes2)
        end

        push!(totals_column, votes1 + votes2)
    end

    DataFrame(group1 = group1_column, votes1 = votes1_column, group2 = group2_column, votes2 = votes2_column, totals = totals_column)
end

bills = JSON.parse(readall("./data/113th-bills.json"))
industries = JSON.parse(readall("./data/crp-categories.json"))

bills = filter_has_votes(bills)
bills = filter_overlapping_votes(bills)

opposing_groups = compute_opposing_groups(bills)

println("\n-------\n")

show_opposing_groups(opposing_groups, industries)
