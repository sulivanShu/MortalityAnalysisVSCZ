@info "Weekly entries selection"

# Data
@load "data/exp_pro/approximate_selection.jld2" approximate_selection

# Constants
const APPROXIMATE_SELECTION = approximate_selection::Dict{Int,Int}

const GROUP_ID_VEC = @chain begin
    dfs
    keys
    collect
end

# Functions

# INFO: Attention! Le type des entrées et des sorties de chaque fonction est indiqué lors de leur définition et assez souvent lors de leur appel. Cela permet de renseigner et de vérifier immédiatement les types, mais si des types doivent être changés, l'indication de type doit être changé partout.

# INFO:
# La fonction `select_subgroups` sélectionne toutes les semaines de la semaine 54 à la semaine 131, puis tente de sélectionner autant de semaines que possible depuis la semaine 1. Il teste différent nombres de semaines à partir d'un nombre de semaines probablement correct (APPROXIMATE_SELECTION): si le test réussit, il teste une semaine de plus jusqu'à échouer, et retient le dernier nombre de semaines qui a réussi; si le teste échoue, il teste une semaine de moins jusqu'à réussir, et retient le premier nombre de semaines qui réussit. create_subgroups déclenche une erreur s'il n'y a pas assez d'individus dans un sous-groupe, ce qui arrive nécessairement lorsqu'il y a trop de sous-groupes.
function select_subgroups(
    ENTRIES::Vector{Date},
    APPROXIMATE_SELECTION::Dict{Int64,Int64},
    group_id::Int;
    maxk = 53,
)::Dict{Date,DataFrame}
    # INFO: initialisation de la sortie
    subgroups = Dict{Date,DataFrame}()
    head = ENTRIES[1:APPROXIMATE_SELECTION[group_id]]
    tail = ENTRIES[54:131]
    these_mondays = vcat(head, tail)
    try
        subgroups = create_subgroups(ENTRIES, group_id, these_mondays, MONDAYS, dfs)
        # @info "group_id = $group_id\nWe are bellow at $(ok)!"
        if APPROXIMATE_SELECTION[group_id] < maxk
            next_approximate_selection = APPROXIMATE_SELECTION[group_id] + 1
            for k = next_approximate_selection:maxk
                these_mondays = vcat(ENTRIES[1:k], tail)
                try
                    subgroups =
                        create_subgroups(ENTRIES, group_id, these_mondays, MONDAYS, dfs)
                catch
                    @info "group_id = $group_id\nsubgroups selected from below: [1:$k, 54:131]"
                    break
                end
            end
        else # APPROXIMATE_SELECTION[group_id] == maxk
            @info "group_id = $group_id\nsubgroups total selection: [1:131]"
            return subgroups
        end
    catch
        # @info "group_id = $group_id\nWe are above at $(ok)!"
        previous_approximate_selection = APPROXIMATE_SELECTION[group_id] - 1
        for k = previous_approximate_selection:-1:0
            these_mondays = vcat(ENTRIES[1:k], tail)
            try
                subgroups = create_subgroups(ENTRIES, group_id, these_mondays, MONDAYS, dfs)
                @info "group_id = $group_id\nsubgroups selected from above: [1:$k, 54:131]"
                return subgroups
            catch
            end
        end
    end
    return subgroups
end

function create_subgroups(
    ENTRIES::Vector{Date},
    group_id::Int,
    these_mondays::Vector{Date},
    MONDAYS::Vector{Date},
    dfs::Dict{Int,DataFrame},
)::Dict{Date,DataFrame}
    # TEST: créée une vraie copie, pour les tests.
    group = deepcopy(dfs[group_id])::DataFrame
    # pas une vraie copie = moins de mémoire, mais le dfs original 
    # est détruit en cours de route. Mais la consommation mémoire n'est 
    # pas la préoccupation majeure pour ce type de programme.
    # group = dfs[group_id]
    # INFO: initialisation de la sortie
    subgroups = Dict(
        entry => DataFrame(
            vaccinated = Bool[],
            entry = Date[],
            exit = Date[],
            death = Date[],
            DCCI = Vector{Tuple{Int,Date}}[],
        ) for entry in ENTRIES
    )
    # INFO: when_what_where_dict est un agenda qui indique à quelle date il faudra remplacer un non-vacciné A par un autre B, parce que le non-vacciné A se vaccine. Cet agenda indique également dans quels subroups sont les non-vaccinés à remplacer, et à quelles lignes. L'agenda est mis à jour à chaque ajout de non-vaccinés, c'est-à-dire à chaque itération de la boucle `in MONDAYS`.
    when_what_where_dict = Dict{Date,Dict{Date,Vector{Int}}}()
    for this_monday in MONDAYS
        # INFO: traitement des vaccinés (qui ne sont jamais remplacés car ils ne se dévaccinent pas) et des premiers non-vaccinés (qui peuvent être remplacés parce qu'ils peuvent se vacciner). Écriture de l'agenda when_what_where_dict pour y ajouter les non-vaccinés qui devront être remplacés, à quelles dates, dans quels sugroups et à quelles lignes.
        if this_monday in these_mondays
            subgroup = subgroups[this_monday]
            # INFO: pour les vaccinés
            # Renvoie aussi le nombre de vaccinés dans chaque subgroup, car le nombre de vaccinés et de non-vaccinés doit être égal dans chaque subgroups
            vaccinated_count = process_vaccinated!(
                group::DataFrame,
                subgroup::DataFrame,
                this_monday::Date,
            )::Int
            # Pour les premiers non-vaccinés
            process_first_unvaccinated!(
                group::DataFrame,
                subgroup::DataFrame,
                this_monday::Date,
                vaccinated_count::Int,
                when_what_where_dict::Dict{Date,Dict{Date,Vector{Int}}},
            )::Nothing
        end
        # Pour les non-vaccinés de remplacement
        # INFO: replace_unvaccinated!
        # À chaque `this_monday`, on ouvre l'agenda et on regarde ce qu'il y a à faire: quels non-vaccinés doivent être remplacés parce qu'ils se vaccinent. Les non-vaccinés sont remplacés exactement à leur date de vaccination et non avant, afin d'éviter les paradoxes où un évènement passé (le remplacement) est déterminé par un évènement futur (la vaccination). La fonction `replace_unvaccinated!` écrit aussi dans l'agenda lorsque des non-vaccinés de remplacement se vaccinent avant la fin de la période d'observation, afin de pouvoir les remplacer eux aussi lors d'itérations ultérieures de la boucle `in MONDAYS`.
        replace_unvaccinated!(
            this_monday::Date,
            group::DataFrame,
            subgroups::Dict{Date,DataFrame},
            when_what_where_dict::Dict{Date,Dict{Date,Vector{Int}}},
        )::Nothing
    end
    filter!(kv -> nrow(kv[2]) > 0, subgroups)
    # TEST: renvoyer when_what_where_dict avec subgroups
    # return subgroups, when_what_where_dict
    return subgroups
end

function process_vaccinated!(group::DataFrame, subgroup::DataFrame, this_monday::Date)::Int
    # INFO: Repérer dans `group` les vaccinés du `subgroup` en cours, puis les mettre dans subgroups[entry], puis les marquer comme non-disponibles dans `group`.
    for row in eachrow(group)
        if row.week_of_dose1 == this_monday
            vaccinated = true
            entry = this_monday
            exit = this_monday + Week(53) # INFO: 53 semaines en tout
            death = row.week_of_death
            DCCI = [(row.DCCI, this_monday)] # TEST: remplacement par la valeur de DCCI
            push!(
                subgroup,
                (
                    vaccinated = vaccinated,
                    entry = entry,
                    exit = exit,
                    death = death,
                    DCCI = DCCI,
                ),
            )
            row.available = UNAVAILABLE
        end
    end
    # INFO:renvoie le nombre de vaccinés ajoutés à entry
    return nrow(subgroup)
end

function process_first_unvaccinated!(
    group::DataFrame,
    subgroup::DataFrame,
    this_monday::Date,
    vaccinated_count::Int,
    when_what_where_dict::Dict{Date,Dict{Date,Vector{Int}}},
)::Nothing
    if vaccinated_count != 0
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
        if length(eligible) < vaccinated_count
            error(
                "$this_monday: Moins de non-vaccinés que de vaccinés pour entry = $this_monday",
            )
						# INFO: cette erreur permet à la fonction `select_subgroups` de sélectionner le bon nombre de subgroups.
        end
        # numéros de lignes, qui sont sélectionnées:
				# INFO: sélectionner, parmi les éligibles, le même nombre de non-vaccinés que de vaccinés.
        selected =
            sample(eligible, vaccinated_count, replace = false)
        for i in selected
            # INFO: Chaque ligne sélectionnée dans group:
            row = group[i, :]
            # INFO: un non-vaccinés sort soit à la fin de la subgroup, soit au moment de sa vaccination.
            vaccinated = false
            entry = this_monday
            exit = min(row.week_of_dose1, this_monday + Week(53))
            death = row.week_of_death
            DCCI = [(row.DCCI, this_monday)] # INFO: l'indice de comorbidités
            push!(
                subgroup,
                (
                    vaccinated = vaccinated, # vaccinated = false
                    entry = entry,
                    exit = exit,
                    death = death,
                    DCCI = DCCI,
                ),
            )
            # INFO: Un non-vacciné redevient disponible soit lorsqu'il est vacciné, soit lorsqu'il sort du subgroup. Attention, il pourrait être "disponible", après sa mort, d'où l'importance de vérifier si les non-vaccinés ne sont pas mort, avant d'intégrer ou de réintégrer une subgroup!
            group[i, :available] = exit + Week(1)
        end
    end
    # INFO: Il faut ensuite noter dans l'agenda `when_what_where_dict` les non-vaccinés qui devront être remplacés, et quand.
    # Itérateur sur les non-vaccinés à remplacer (when, what, where)
    when_what_where_iter = (
        (
            row.exit, # Semaine de la vaccination du non-vacciné
            this_monday, # Identifiant (une date) du subgroup
            i,
        ) # Numéro de ligne du non-vaccinés à remplacer.
        for (i, row) in enumerate(eachrow(subgroup))
        # INFO: On ne retient que les individus dont la durée (exit - entry) est strictement inférieure à 53 semaines, c’est-à-dire ceux qui se vaccinent avant la fin de la période d’observation.
        if (row.exit - row.entry) < Week(53)
    )
    # INFO: Écriture directe dans when_what_where_dict
    # Ce dictionnaire imbriqué est de type Dict{Date, Dict{Date, Vector{Int}}}
    # _when: quand faire le remplacement: au moment de la vaccination d'un non-vacciné,
    # _what: dans quel subgroup faire le remplacement,
    # _where: dans le subgroup, quel est le numéro de ligne du non-vacciné à remplacer.
    for (_when, _what, _where) in when_what_where_iter
        # INFO: Dans `when_what_where_dict`: récupère (ou crée si absent) le dictionnaire interne associé à la date de vaccination du non-vacciné (_when).
        @chain begin
            # INFO: Chercher dans le dictionnaire `when_what_where_dict` la clé `_when`. Si elle existe, retourner la valeur associée (un objet de type `Dict{Date, Vector{Int}}`); si elle n'existe pas, créer une paire `_when => valeur` dont la valeur est un objet vide de type `Dict{Date, Vector{Int}}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_dict`.
            when_what_where_dict
            get!(_, _when, Dict{Date,Vector{Int}}())
            # INFO: Chercher dans le dictionnaire `inner_dict` la clé `_what`. Si elle existe, retourner la valeur associée (un objet de type Vector{Int}); si elle n'existe pas, créer une paire `clé => valeur` dont la valeur est un objet vide de type `Vector{Int}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_vector` (les lignes à changer, c'est-à-dire les non-vaccinés à remplacer, dans les `subgroups`).
            get!(_, _what, Int[])
            # ajouter au vecteur `inner_vector` la valeur `_where`.
            append!(_, _where)
        end
    end
		return nothing
end

function replace_unvaccinated!(
    this_monday::Date,
    group::DataFrame,
    subgroups::Dict{Date,DataFrame},
    when_what_where_dict::Dict{Date,Dict{Date,Vector{Int}}},
)::Nothing
    # rien à faire si aucun remplacement planifié pour this_monday
    if !haskey(when_what_where_dict, this_monday)
        return nothing
    end
    _when = this_monday
    inner_dict = when_what_where_dict[_when]
    # Les éligibles doivent être calculés dans chaque fonction `process_first_unvaccinated` et `replace_unvaccinated`.
    eligible = findall(
        row ->
        # Sont éligibles, à la date de remplacement:
        # les vivants:
            _when <= row.week_of_death &&
            # non-vaccinés:
            _when < row.week_of_dose1 &&
            # qui ne sont pas encore dans un autre subgroup:
            row.available <= _when, # INFO: vérifier si c'est bien <= et non <
        eachrow(group),
    )
    for (_what, _where) in inner_dict
        if length(eligible) < length(_where)
            error(
                "$this_monday: Impossible replacement in $(_what)! `eligible` is lesser than length(_where)!",
            )
        end
        if length(eligible) >= length(_where)
            selected = sample(eligible, length(_where), replace = false)
            for i in selected # INFO: `i` is each column of `selected`
                row = group[i, :] # INFO: select all columns of line `i` of `group`
                exit = min(row.week_of_dose1, _what + Week(53))
                group[i, :available] = exit + Week(1)
            end
            subgroup = subgroups[_what]
            for (k, i) in enumerate(_where) # INFO: `i` have each `_where` value, and `k` is the range of `i` [1, 2, 3...].
                s = selected[k] # un individu de remplacement
                subgroup_end = _what + Week(53)
                vaccination_date = group[s, :week_of_dose1]
                exit = min(subgroup_end, vaccination_date)
                death = group[s, :week_of_death]
                subgroup.exit[i] = exit
                subgroup.death[i] = death
                push!(subgroup.DCCI[i], (group[s, :DCCI], this_monday))  # TEST: remplacement par la valeur de DCCI
                if vaccination_date <= subgroup_end # Même chose que dans la fonction `process_first_unvaccinated`
                    @chain begin
                        # dans when_what_where_dict (un dictionnaire)
                        when_what_where_dict
                        # récupérer la valeur de la clé `vaccination_date` (un dictionnaire)
                        get!(_, vaccination_date, Dict{Date,Vector{Int}}())
                        # dans ce dictionnaire, récupérer la valeur de la clé `_what` (un vecteur)
                        get!(_, _what, Int[])
                        # dans ce vecteur, ajouter la valeur de `i`.
                        append!(_, i)
                    end
                end
            end
        end
    end
    return nothing
end

# Processing
exact_selection =
    ThreadsX.map(GROUP_ID_VEC) do group_id
        group_id => select_subgroups(ENTRIES, APPROXIMATE_SELECTION, group_id)
    end |> Dict

# TODO: pour vider la mémoire. Pas nécessaire.
# dfs = nothing

@info "Weekly entries selection completed"
