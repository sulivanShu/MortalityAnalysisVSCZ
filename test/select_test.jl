# TEST:
# Pour un seul petit groupe, car faire les 40 groupes dure environ 10 min avec un processeur 8 threads.
# pour des sorties déterministes, ne pas oublier de mettre Random.seed!(my_seed) avant chaque exécution concernant les non-vaccinés, car il y a un tirage.
group_id_sample = 11920
this_monday = Date(2020, 12, 21)
# head = ENTRIES[1:7] 
head = ENTRIES[1:APPROXIMATE_SELECTION[group_id_sample]]
tail = ENTRIES[54:131]
these_mondays = vcat(head, tail)
pool = deepcopy(dfs[group_id_sample])::DataFrame

Random.seed!(my_seed)
exact_selection =
    ThreadsX.map([group_id_sample]) do group_id
        group_id => select_subgroups(ENTRIES, APPROXIMATE_SELECTION, group_id)
    end |> Dict

Random.seed!(my_seed)
subgroups = select_subgroups(ENTRIES, APPROXIMATE_SELECTION, group_id_sample)
subgroups[this_monday][:, :DCCI]

dfs[11920]

Random.seed!(my_seed)
head = ENTRIES[1:7] 
these_mondays = vcat(head, tail)
subgroups = create_subgroups(
    ENTRIES::Vector{Date},
    group_id_sample::Int,
    these_mondays::Vector{Date},
    MONDAYS::Vector{Date},
    dfs::Dict{Int,DataFrame},
)::Dict{Date,DataFrame}
subgroups[this_monday]

# Attention, `process_vaccinated!` est impure! elle modifie sa propre entrée: subgroup. D'où la nécessité de réinitialiser subgroups et subgroup.
Random.seed!(my_seed)
subgroups = Dict(
    entry => DataFrame(
        vaccinated = Bool[],
        entry = Date[],
        exit = Date[],
        death = Date[],
        DCCI = Vector{Tuple{Int,Date}}[],
    ) for entry in ENTRIES
)
subgroup = subgroups[this_monday]
vaccinated_count = process_vaccinated!(group::DataFrame, subgroup::DataFrame, this_monday::Date)::Int
subgroup

# Attention, `process_first_unvaccinated!` est impure! D'où la nécessité de réinitialiser group, subgroups, subgroup et when_what_where_dict.
Random.seed!(my_seed)
group = deepcopy(dfs[group_id_sample])::DataFrame
subgroups = Dict(
    entry => DataFrame(
        vaccinated = Bool[],
        entry = Date[],
        exit = Date[],
        death = Date[],
        DCCI = Vector{Tuple{Int,Date}}[],
    ) for entry in ENTRIES
)
subgroup = subgroups[this_monday]
vaccinated_count = process_vaccinated!(group::DataFrame, subgroup::DataFrame, this_monday::Date)::Int
when_what_where_dict = Dict{Date,Dict{Date,Vector{Int}}}()
process_first_unvaccinated!(
    group::DataFrame,
    subgroup::DataFrame,
    this_monday::Date,
    vaccinated_count::Int,
    when_what_where_dict::Dict{Date,Dict{Date,Vector{Int}}},
)::Nothing
subgroup

this_monday
group

group = deepcopy(dfs[group_id_sample])::DataFrame
eligible = findall(
    row ->
    # sont éligibles:
    # les vivants:
        this_monday <= row.week_of_death && # INFO: peuvent mourir la semaine courante de this_monday.
        # non-vaccinés:
        this_monday < row.week_of_dose1 && # INFO: doivent être non-vaccinés la semaine courante
        # qui ne sont pas encore dans un autre subgroup:
        row.available <= this_monday, # INFO: était auparavant `<`. Pourtant, plus bas: `group[i, :available] = exit + Week(1)`, ce qui signifie ces non-vaccinés sont disponibles un peu plus tôt, à partir de la semaine 54 et non 55. Mais est-ce que cela pose problème pour la toute première semaine, où la vaccination commence le dimanche 27 décembre 2020? En principe, non, car cela fait un décalage de 6 + 1.24 jours seulement. Il faut peut-être éclaircir le code au sujet des décalages des jours, car une année fait 52 semaines + 1.24 jours, et les vaccinations sont réputées commencer en milieu de semaines ou en fin en ce qui concerne la toute première semaine.
    eachrow(group),
)

nrow(group)
length(eligible)

Random.seed!(my_seed)
selected = sample(eligible, vaccinated_count, replace = false)

when_what_where_iter = (
    (
        row.exit, # Semaine de la vaccination du non-vacciné: quand il faut s'occuper du remplacement
        this_monday, # Identifiant (une date) du subgroup: dans quel subgroup a lieu le remplacement
        i, # à quelle ligne
    )
    for (i, row) in enumerate(eachrow(subgroup))
    # INFO: On ne retient que les individus dont la durée (exit - entry) est strictement inférieure à 53 semaines, c’est-à-dire ceux qui se vaccinent avant la fin de la période d’observation.
    if (row.exit - row.entry) < Week(53)
)

enumerate(eachrow(subgroup))

collect(when_what_where_iter)

Date(2021,12,27)-Date(2020,12,21) == Week(53)

dfs[11920]
