
type Team
    id
    name
    industries
    game

    Team(game, id, name) = new(id, name, Any[], game)
end

add_industry(t::Team, industry) = push!(t.industries, industry)

function add_industries(t::Team, industries)
    for industry in industries
        add_industry(t, industry)
    end
end

function score(t::Team)
    game_industries = t.game.industries
    
    team_score = 0
    for i in t.industries
        team_score += game_industries[i]["score"]
    end

    team_score
end
