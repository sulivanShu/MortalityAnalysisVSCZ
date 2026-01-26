@info "Weekly entries selection"

# Data
@load "data/exp_pro/approximate_first_intervals_stops.jld2" approximate_selection

# Constantes
const APPROXIMATE_FIRST_STOPS = approximate_selection::Dict{Int,Int}
const DFS = dfs::Dict{Int, DataFrame}
const MAX_FIRST_STOP = 53
const TAIL = ENTRIES[54:131]::Vector{Date}
# global GROUP_ID_VEC = @chain DFS keys collect # sort # Int[] # INFO: Production
global GROUP_ID_VEC = 11920 # first(GROUP_ID_VEC)::Int # TEST: pour les tests

# Functions
## High level functions, sorted in hierarchical order
function select_subgroups(
		group_id::Int;
		group = init_group(),
		)::Dict{Date,DataFrame}
	these_mondays = get_these_mondays(group_id)
	try
		group = create_subgroups(group_id, these_mondays)
		if all_weeks_are_selected(group_id)
			@info "group_id = $group_id\nsubgroups total selection: [1:131]"
			return group
		else
			for next = get_next_first_interval_iterator(group_id)
				try
					group = create_subgroups(group_id, try_these_mondays(next))
				catch
					@info "group_id = $group_id\nsubgroups selected from below: [1:$next, 54:131]"
					return group
					break
				end
			end
		end
	catch
		for previous = get_previous_first_interval_iterator(group_id)
			try
				group = create_subgroups(group_id, try_these_mondays(previous))
				@info "group_id = $group_id\nsubgroups selected from above: [1:$previous, 54:131]"
				return group
			catch
			end
		end
	end
	return group
end

function create_subgroups(
		group_id::Int,
		these_mondays::Vector{Date};
		group = init_group(),
		agenda = init_agenda(),
		)::Dict{Date,DataFrame}
	pool = get_pool_from(group_id)
	for this_monday in ALL_MONDAYS
		if this_monday in these_mondays
			subgroup = group[this_monday]
			vaccinated_count = process_vaccinated!(
																						 pool,
																						 subgroup,
																						 this_monday,
																						 )

			# this function edits subgroup
			# but are we sure group[this_monday] is edited in the exact same way ? 
			# because in the end what we are returning is group, so we need to ensure it changed
			process_first_unvaccinated!(
																	pool,
																	subgroup,
																	this_monday,
																	vaccinated_count,
																	agenda,
																	)
			# same coment here 
		end
		replace_unvaccinated!(
													this_monday,
													pool,
													group,
													agenda,
													)
	end
	rm_empty_df_in(group)
	return group
end

function process_vaccinated!(
		pool::DataFrame,
		subgroup::DataFrame,
		this_monday::Date,
		)::Int
	# INFO: Repérer dans `pool` les vaccinés du `subgroup`, puis les ajouter au subgroup.
	for row in eachrow(pool)
		if row.dose1_week == this_monday
			push!(
						subgroup,
						(
						 vaccinated = true,
						 entry = this_monday,
						 exit = this_monday + Week(53), # INFO: un peu plus qu'un an, 53 semaines en tout
						 death = row.death_week,
						 DCCI = [(row.DCCI, this_monday)], # INFO: un vecteur d'une seule paire
						 ),
						)
		end
	end
	# INFO:renvoie le nombre de vaccinés ajoutés au subgroup
	return nrow(subgroup)
end

function process_first_unvaccinated!(
		pool::DataFrame,
		subgroup::DataFrame,
		this_monday::Date,
		vaccinated_count::Int,
		agenda::Dict{Date,Dict{Date,Vector{Int}}},
		)::Nothing
	if vaccinated_count != 0
		eligible = get_eligible(pool, this_monday)
		if length(eligible) < vaccinated_count
			error("$this_monday: fewer unvaccinated than vaccinated individuals. The select_subgroups function will reduce the number of weeks considered in this group.")
		else
			# numéros de lignes, qui sont sélectionnées:
			# INFO: sélectionner, parmi les éligibles, le même nombre de non-vaccinés que de vaccinés.
			selected = sample(eligible, vaccinated_count, replace = false)
			for i in selected
				# INFO: Chaque ligne sélectionnée dans pool:
				row = pool[i, :]
				# INFO: un non-vaccinés sort soit à la fin de la subgroup, soit au moment de sa vaccination.
				exit = min(row.dose1_week, this_monday + Week(53)) # à garder, car réutilisé ensuite!
				push!(
							subgroup,
							(
							 vaccinated = false, # vaccinated = false
							 entry = this_monday,
							 exit = exit,
							 death = row.death_week,
							 DCCI = [(row.DCCI, this_monday)],
							 ),
							)
				# INFO: Un non-vacciné redevient disponible soit lorsqu'il est vacciné, soit lorsqu'il sort du subgroup. Attention, il pourrait être "disponible", après sa mort, d'où l'importance de vérifier si les non-vaccinés ne sont pas mort, avant d'intégrer ou de réintégrer une subgroup!
				pool[i, :availability_week] = exit + Week(1) # une semaine après l'exit. Vérifier.
			end
		end
	end
	# INFO: Il faut ensuite noter dans l'agenda `agenda` les non-vaccinés qui devront être remplacés, et quand.
	# Itérateur sur les non-vaccinés à remplacer (when, what, where)
	# INFO: cet itérateur sélectionne le numéro de ligne, `this_monday` et `exit` de chaque non-vacciné à remplacer dans subroup, mais les réarange dans un autre sens: d'abord la date `exit` (car c'est à ce moment-là qu'il faudra le remplacer), puis `this_monday` (car c'est aussi l'identifiant du subgroup dans lequel le remplacement devra être fait) et le numéro de ligne (car c'est la ligne du non-vacciné à remplacer).
	when_what_where_iter = ( # TODO: Changer le nom pour filer la métaphore de l'agenda. Faire construire l'itérateur par une fonction.
													(
													 row.exit, # Semaine de vaccination du non-vacciné: quand il faut s'occuper du remplacement
													 this_monday, # Identifiant (une date) du subgroup: dans quel subgroup a lieu le remplacement
													 i, # à quelle ligne
													) for (i, row) in enumerate(eachrow(subgroup))
													# INFO: On ne retient que les individus dont la durée (exit - entry) est strictement inférieure à 53 semaines, c’est-à-dire ceux qui se vaccinent avant la fin de la période d’observation. NOTA: cela exclut automatiqument les vaccinés, car dans leur cas, strictement: `(row.exit - row.entry) == Week(53)`
													if (row.exit - row.entry) < Week(53)
													)
	# INFO: ajout de when_what_where_iter dans agenda
	# Cet agenda agenda est de type Dict{Date, Dict{Date, Vector{Int}}} où :
	# _when: (première date) quand faire le remplacement: au moment de la vaccination d'un non-vacciné,
	# _what: (deuxième date) dans quel subgroup faire le remplacement,
	# _where: (Vector{Int}) dans le subgroup, quels sont les numéros de ligne des non-vaccinés à remplacer.
	for (_when, _what, _where) in when_what_where_iter # TODO: changer les noms pour filer la métaphore de l'agenda.
		# INFO: Dans `agenda`: récupère (ou crée si absent) le dictionnaire interne associé à la date de vaccination du non-vacciné (_when).
		@chain begin # TODO: à mettre dans une fonction pour être réutilisée plus tard.
			# INFO: Chercher dans le dictionnaire `agenda` la clé `_when`. Si elle existe, retourner la valeur associée (un objet de type `Dict{Date, Vector{Int}}`); si elle n'existe pas, créer une paire `_when => valeur` dont la valeur est un objet vide de type `Dict{Date, Vector{Int}}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_dict`.
			agenda
			get!(_, _when, Dict{Date,Vector{Int}}()) # TODO: renommer l'objet vide pour être plus explicite
			# INFO: Chercher dans le dictionnaire `inner_dict` la clé `_what`. Si elle existe, retourner la valeur associée (un objet de type Vector{Int}); si elle n'existe pas, créer une paire `clé => valeur` dont la valeur est un objet vide de type `Vector{Int}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_vector` (les lignes à changer, c'est-à-dire les non-vaccinés à remplacer, dans les `group`).
			get!(_, _what, Int[])
			# ajouter au vecteur `inner_vector` la valeur `_where`.
			append!(_, _where)
			# `agenda` a été mis à jour avec les nouvelles valeurs de `when_what_where_iter`.
		end
	end
	return nothing
end

function replace_unvaccinated!(
		this_monday::Date,
		pool::DataFrame,
		group::Dict{Date,DataFrame},
		agenda::Dict{Date,Dict{Date,Vector{Int}}},
		)::Nothing
	# Return nothing if nothing to do in agenda for this_monday
	if !haskey(agenda, this_monday)
		return nothing
	else
		eligible = get_eligible(pool, this_monday)
		for (_what, _where) in agenda[this_monday]
			if length(eligible) < length(_where)
				error("$this_monday: Impossible replacement in $(_what)! `eligible` is lesser than `length(_where)`!")
			else
				selected = sample(eligible, length(_where), replace = false)
				for i in selected # INFO: `i` is each element of the `selected` vector.
					row = pool[i, :] # INFO: select all columns of line `i` of `pool`
					exit = min(row.dose1_week, _what + Week(53))
					pool[i, :availability_week] = exit + Week(1)
				end
				subgroup = group[_what]
				for (k, i) in enumerate(_where) # INFO: `i` have each `_where` value, and `k` is the range of `i` [1, 2, 3...].
					s = selected[k] # l'indice d'un individu de remplacement dans pool
					subgroup_end = _what + Week(53)
					vaccination_date = pool[s, :dose1_week] # sa date de vaccination (le cas échéant Date(1000,01,01), ce qui représente la non-vaccination)
					exit = min(subgroup_end, vaccination_date)
					death = pool[s, :death_week] # sa date de décès
					subgroup.exit[i] = exit # mettre la donnée dans subgroup
					subgroup.death[i] = death # mettre la donnée dans subgroup. Il n'est pas vraiment nécessaire de mettre à jour s'il ne s'agit pas du dernier non-vaccinés...
					push!(subgroup.DCCI[i], (pool[s, :DCCI], this_monday))
					if vaccination_date <= subgroup_end # Même chose que dans la fonction `process_first_unvaccinated`. `<=` ?
						@chain begin # TODO: remplacer par une fonction.
							# dans agenda (un dictionnaire)
							agenda
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
	end
	return nothing
end

## Low level functions sorted in alphabetical order
function all_weeks_are_selected(
		group_id::Int
		)::Bool
	APPROXIMATE_FIRST_STOPS[group_id] == MAX_FIRST_STOP
end

function get_eligible(
		pool::DataFrame,
		this_monday::Date,
		)::Vector{Int}
	findall( 
					row ->
					# sont éligibles:
					## les vivants:
					this_monday <= row.death_week && # INFO: peuvent mourir la semaine courante de this_monday.
					## non-vaccinés:
					this_monday < row.dose1_week && # INFO: doivent être non-vaccinés la semaine courante					
					## qui ne sont pas encore dans un autre subgroup:
					row.availability_week <= this_monday, # INFO: était auparavant `<`. Pourtant, plus bas: `pool[i, :availability_week] = exit + Week(1)`, ce qui signifie ces non-vaccinés sont disponibles un peu plus tôt, à partir de la semaine 54 et non 55. Mais est-ce que cela pose problème pour la toute première semaine, où la vaccination commence le dimanche 27 décembre 2020? En principe, non, car cela fait un décalage de 6 + 1.24 jours seulement. Il faut peut-être éclaircir le code au sujet des décalages des jours, car une année fait 52 semaines + 1.24 jours, et les vaccinations sont réputées commencer en milieu de semaines ou en fin en ce qui concerne la toute première semaine.
					eachrow(pool),
					)
end

function get_next_first_interval_iterator(
		group_id::Int
		)::UnitRange{Int}
	(APPROXIMATE_FIRST_STOPS[group_id] + 1):MAX_FIRST_STOP
end

function get_pool_from(
		group_id::Int
		)::DataFrame
	deepcopy(DFS[group_id]) # INFO: deepcopy pour ne pas détruire dfs en cours de route, et pouvoir lancer le module plusieurs fois sans avoir à recréer dfs. de toute façon on utilise la constante DFS.
end

function get_previous_first_interval_iterator(
		group_id::Int
		)::StepRange{Int,Int}
	(APPROXIMATE_FIRST_STOPS[group_id] - 1):-1:0
end

function get_these_mondays(
		group_id::Int
		)::Vector{Date}
	head = ENTRIES[1:APPROXIMATE_FIRST_STOPS[group_id]]
	these_mondays = vcat(head, TAIL)
end

function get_these_mondays(
		group_id::Int
		)::Vector{Date}
	head = ENTRIES[1:APPROXIMATE_FIRST_STOPS[group_id]]
	these_mondays = vcat(head, TAIL)
end

function init_agenda()::Dict{Date,Dict{Date,Vector{Int}}}
	agenda = Dict{Date,Dict{Date,Vector{Int}}}()
	# INFO:
	# la première date représente chaque page de l'agenda,
	# la deuxième date, l'identifiant de chaque subgroup sur lequel agir,
	# le vecteur de Int, les lignes de chaque subgroup sur lesquels agir.
end

function init_group()::Dict{Date,DataFrame}
	group = Dict(
							 entry => DataFrame(
																	vaccinated = Bool[],
																	entry = Date[],
																	exit = Date[],
																	death = Date[],
																	DCCI = Vector{Tuple{Int,Date}}[],
																	) for entry in ENTRIES
							 )
end

function rm_empty_df_in(group::Dict{Date,DataFrame})::Dict{Date,DataFrame}
	filter!(kv -> nrow(kv[2]) > 0, group)
end

function try_these_mondays(
		next_or_previous::Int
		)::Vector{Date}
	these_mondays = vcat(ENTRIES[1:next], TAIL)
end

# Processing
exact_selection =
@time ThreadsX.map(GROUP_ID_VEC) do group_id
	group_id => select_subgroups(group_id)
end |> Dict
exact_selection[11920][Date("2020-12-21")][:,:DCCI] # TEST:
# exact_selection[11920][Date("2020-12-21")] # TEST:
# exact_selection[22005][Date("2022-01-17")] # TEST:

# # INFO: pour vider la mémoire. Pas nécessaire.
# # dfs = nothing
#
# @info "Weekly entries selection completed"
