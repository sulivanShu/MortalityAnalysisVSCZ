@info "Weekly entries selection"

# Data
@load "data/exp_pro/approximate_first_intervals_stops.jld2" approximate_selection

# Constantes
const APPROXIMATE_FIRST_STOPS = approximate_selection::Dict{Int,Int}
const DFS = dfs::Dict{Int, DataFrame}
const MAX_FIRST_STOP = 53
const TAIL = ENTRIES[54:131]::Vector{Date}
# const GROUP_ID_VEC = @chain DFS keys collect # sort # Int[] # INFO: Production
const GROUP_ID_VEC = [11920] # first(GROUP_ID_VEC)::Int[] # TEST:

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
			# are you sure this else case is needed ? 
			# I feel the only way to get here would be that we got an error when callin create_sbugroups
			# since we have a catch, I guess we never arrive here ?

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
	for this_monday in these_mondays
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
	if vaccinated_count == 0
		return nothing
	else
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
		for (page_id, task_id, step) in get_agenda_iterator(subgroup, this_monday)
			write_agenda!(agenda, page_id, task_id, step)
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
		for (task_id, task) in agenda[this_monday]
			if length(eligible) < length(task)
				error("$this_monday: Impossible replacement in $(task_id)! `eligible` is lesser than `length(task)`!")
			else
				selected = sample(eligible, length(task), replace = false)
				for i in selected # INFO: `i` is each element of the `selected` vector.
					row = pool[i, :] # INFO: select all columns of line `i` of `pool`
					exit = min(row.dose1_week, task_id + Week(53))
					pool[i, :availability_week] = exit + Week(1)
				end
				subgroup = group[task_id]
				for (k, step) in enumerate(task) # INFO: `step` have each `task` value, and `k` is the range of `step` [1, 2, 3...].
					s = selected[k] # l'indice d'un individu de remplacement dans pool
					subgroup_end = task_id + Week(53)
					page_id = pool[s, :dose1_week] # sa date de vaccination (le cas échéant Date(10000,01,01), ce qui représente la non-vaccination)
					exit = min(subgroup_end, page_id)
					death = pool[s, :death_week] # sa date de décès
					subgroup.exit[step] = exit # mettre la donnée dans subgroup
					subgroup.death[step] = death # mettre la donnée dans subgroup. Il n'est pas vraiment nécessaire de mettre à jour s'il ne s'agit pas du dernier non-vaccinés...
					push!(subgroup.DCCI[step], (pool[s, :DCCI], this_monday))
					if page_id <= subgroup_end # Même chose que dans la fonction `process_first_unvaccinated`. `<=` ?
						write_agenda!(agenda, page_id, task_id, step)
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

function get_agenda_iterator(subgroup::DataFrame, this_monday::Date)
	# INFO: Il faut ensuite noter dans l'agenda les non-vaccinés qui devront être remplacés, quand et dans quel subgroup.
	# Itérateur sur les non-vaccinés à remplacer (page_id, task_id, step)
	# INFO: cet itérateur sélectionne le numéro de ligne, `this_monday` et `exit` de chaque non-vacciné à remplacer dans subroup, mais les réarange dans un autre sens: d'abord la date `exit` (car c'est à ce moment-là qu'il faudra le remplacer), puis `this_monday` (car c'est aussi l'identifiant du subgroup dans lequel le remplacement devra être fait) et le numéro de ligne (car c'est la ligne du non-vacciné à remplacer).
    (
        (row.exit, this_monday, step)
        for (step, row) in enumerate(eachrow(subgroup))
        if (row.exit - row.entry) < Week(53)
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

function init_agenda()::Dict{Date,Dict{Date,Vector{Int}}}
	# INFO:
	# step = 0::Int
	# task = [step]::Vector{Int}
	# task_id = Date(0, 0, 0)
	# page = Dict(task_id => task)
	# page_id = Date(0, 0, 0)
	# agenda = Dict(page_id => page)
	# agenda = Dict(page_id => Dict(task_id => [step]))
	agenda = Dict{Date,Dict{Date,Vector{Int}}}()
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

function write_agenda!(
		agenda,
		page_id,
		task_id,
		step,
		)::Nothing
	# empty_agenda = Dict{Date,Dict{Date,Vector{Int}}}()
	empty_page = Dict{Date,Vector{Int}}()
	empty_task = Int[]
	@chain begin
		agenda
		get!(_, page_id, empty_page)
		get!(_, task_id, empty_task)
		append!(_, step)
	end
	return nothing
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
