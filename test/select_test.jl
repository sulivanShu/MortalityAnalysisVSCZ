# TEST:
# Pour un seul petit groupe, car faire les 40 groupes dure environ 10 min avec un processeur 8 threads.
# pour des sorties déterministes, ne pas oublier de mettre Random.seed!(seed) avant chaque exécution concernant les non-vaccinés, car il y a un tirage.
seed = 0
group_id_sample = 11920
this_monday = Date(2020, 12, 21)
# head = ENTRIES[1:7] 
head = ENTRIES[1:APPROXIMATE_SELECTION[group_id_sample]]
tail = ENTRIES[54:131]
these_mondays = vcat(head, tail)
group = deepcopy(dfs[group_id_sample])::DataFrame

Random.seed!(seed)
exact_selection =
    ThreadsX.map([group_id_sample]) do group_id
        group_id => select_subgroups(ENTRIES, APPROXIMATE_SELECTION, group_id)
    end |> Dict

Random.seed!(seed)
subgroups = select_subgroups(ENTRIES, APPROXIMATE_SELECTION, group_id_sample)
subgroups[this_monday]


Random.seed!(seed)
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
Random.seed!(seed)
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
Random.seed!(seed)
group = deepcopy(dfs[group_id])::DataFrame
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

