@info "Loading functions"

# Downloads
function DownloadCheck(file::AbstractString, URL::AbstractString)
	if !isfile(file)
		@info "File missing, downloading..."
		Downloads.download(URL, file)
		@info "Download completed"
	else
		@info "File already present"
	end
end

# Checksum
function HashCheck(file::AbstractString, b3sum::AbstractString)
	hasher = Blake3Ctx()
	update!(hasher, read(file))
	hash = digest(hasher)
	computed = bytes2hex(hash)
	if computed != b3sum
		error("The hash of file $(file) does not match the expected value.")
	end
	hash_int = reinterpret(UInt64, hash[1:8])[1]
	return hash_int
end

# Load
function load_csv_data(file::AbstractString, select_cols)
	return CSV.File(file; select=select_cols) |> DataFrame
end

# Consistency check
function dose_rank_consistency(df::DataFrame)
	count = nrow(filter(row ->
											ismissing(row.week_of_dose1) &&
											(
											 !ismissing(row.week_of_dose2) ||
											 !ismissing(row.week_of_dose3) ||
											 !ismissing(row.week_of_dose4) ||
											 !ismissing(row.week_of_dose5) ||
											 !ismissing(row.week_of_dose6) ||
											 !ismissing(row.week_of_dose7)
											 ), df))
	count != 0
end

# Remove unused columns
function drop_unused_columns!(df::DataFrame)
	select!(df, Not([
									 :week_of_dose2,
									 :week_of_dose3,
									 :week_of_dose4,
									 :week_of_dose5,
									 :week_of_dose6,
									 :week_of_dose7
									 ]))
end

# Format
function convert_to_uint8!(df::DataFrame, col::Symbol)
	df[!, col] = convert(Vector{Union{Missing, UInt8}}, df[!, col])
	return df
end

function parse_year_column!(df::DataFrame, col::Symbol) # encoder avec UInt8 est possible mais moins lisible.
	df[!, col] = map(x -> 
									 length(String(x)) == 1 ? missing : UInt16(parse(Int, first(String(x), 4))),
									df[!, col]
									)
	return df
end

function first_monday_of_ISOyear(year::Int)
	jan4 = Date(year, 1, 4)  # Le 4 janvier est toujours dans la semaine 1 ISO
	monday = firstdayofweek(jan4)  # Premier lundi de la semaine contenant le 4 janvier
	return monday
end

function isoweek_to_date!(df::DataFrame, col::Symbol)
	df[!, col] = map(x -> 
									 ismissing(x) ? missing : begin
										 year, week = parse.(Int, split(x, "-"))
										 first_monday_of_ISOyear(year) + Week(week - 1)
									 end,
									df[!, col])
	return df
end

# Vérifie si un DataFrame doit être conservé
function is_valid_df(df::DataFrame)
	first_row = df[1, :]
	!ismissing(first_row._5_years_cat_of_birth) &&
	1920 <= first_row._5_years_cat_of_birth < 2020 &&
	!ismissing(first_row.sex)
end

# Modifie le DataFrame en place
function modify_df!(df::DataFrame)
	cutoff = Date("2020-12-21")
	filter!(row -> (ismissing(row.infection_rank) || row.infection_rank == 1) &&
					(ismissing(row.week_of_death) || row.week_of_death > cutoff), # Décédé strictement avant la semaine de vaccination.
					df)
	select!(df, Not(:infection_rank))
end

# select.jl
function select_subgroups(ENTRIES, APPROXIMATE_SELECTION, group_id; maxk=53)
	tail = ENTRIES[54:131]
	subgroups = nothing
	# ok = APPROXIMATE_SELECTION[group_id]
	these_mondays = vcat(ENTRIES[1:APPROXIMATE_SELECTION[group_id]], tail) # remplacer par un Set ?
	try
		# Random.seed!(0)
		subgroups =
		create_subgroups(ENTRIES,
													group_id,
													these_mondays,
													MONDAYS,
													dfs)
		# @info "group_id = $group_id\nWe are bellow at $(ok)!"
		if APPROXIMATE_SELECTION[group_id] < maxk
			next_approximate_selection = APPROXIMATE_SELECTION[group_id] + 1
			for k in next_approximate_selection:maxk
				these_mondays = vcat(ENTRIES[1:k], tail)
				try
					# Random.seed!(0)
					subgroups =
					create_subgroups(ENTRIES,
																group_id,
																these_mondays,
																MONDAYS,
																dfs)
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
		for k in previous_approximate_selection:-1:0
				these_mondays = vcat(ENTRIES[1:k], tail)
				try
					Random.seed!(0)
					subgroups =
					create_subgroups(ENTRIES,
																group_id,
																these_mondays,
																MONDAYS,
																dfs)
					@info "group_id = $group_id\nsubgroups selected from above: [1:$k, 54:131]"
					return subgroups
				catch
				end
		end
	end
	return subgroups
end

function create_subgroups(ENTRIES::Vector{Date},
		group_id::Int,
		these_mondays::Vector{Date},
		MONDAYS::Vector{Date},
		dfs::Dict{Int, DataFrame})
	# TEST: créée une vraie copie, pour les tests. group est modifié, il faut le redéfinir à chaque exécution.
	group = deepcopy(dfs[group_id])
	# TODO: pas une vraie copie.
	# group = dfs[group_id]
	subgroups = Dict(entry => DataFrame(
																			vaccinated = Bool[],
																			entry = Date[],
																			exit = Date[],
																			death = Date[],
																			DCCI = Vector{Tuple{Int, Date}}[],
																			)
									 for entry in ENTRIES)
	when_what_where_dict = Dict{Date, Dict{Date, Vector{Int}}}()
	for this_monday in MONDAYS
		if this_monday in these_mondays
			subgroup = subgroups[this_monday]
			# Pour les vaccinés
			vaccinated_count = process_vaccinated!(group,
																						 subgroup,
																						 this_monday)
			# Pour les premiers non-vaccinés
			process_first_unvaccinated!(group,
																	subgroup,
																	this_monday,
																	vaccinated_count,
																	when_what_where_dict)
		end
		# Pour les non-vaccinés de remplacement
		replace_unvaccinated!(this_monday,
													group,
													subgroups,
													when_what_where_dict)
	end
	filter!(kv -> nrow(kv[2]) > 0, subgroups)
	# return subgroups, when_what_where_dict # TEST: on peut ne pas renvoyer when_what_where_dict
	return subgroups
end

function process_vaccinated!(
		group::DataFrame,
		subgroup::DataFrame,
		this_monday::Date)
	# INFO: Repérer dans `group` les vaccinés du `subgroup` en cours, puis les mettre dans subgroups[entry], puis les marquer comme non-disponibles dans `group`.
	for row in eachrow(group)
		if row.week_of_dose1 == this_monday
			vaccinated = true
			entry = this_monday
			exit = this_monday + Week(53) # INFO: 53 semaines en tout
			death = row.week_of_death
			DCCI = [(row.DCCI, this_monday)] # TEST: remplacement par la valeur de DCCI
			push!(subgroup, (
																		vaccinated = vaccinated,
																		entry = entry,
																		exit = exit,
																		death = death,
																		DCCI = DCCI,
																		))
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
		when_what_where_dict::Dict{Date, Dict{Date, Vector{Int}}}
		)
	if vaccinated_count != 0
		eligible = findall(row ->
											 # sont éligibles:
											 # les vivants:
											 this_monday <= row.week_of_death &&
											 # non-vaccinés:
											 this_monday < row.week_of_dose1 &&
											 # qui ne sont pas encore dans un autre subgroup:
											 row.available < this_monday,
											 eachrow(group))
		if !isempty(eligible) && length(eligible) < vaccinated_count
			error("$this_monday: Moins de non-vaccinés que de vaccinés pour entry = $this_monday")
		end
		if isempty(eligible)
			error("$this_monday: Aucun non-vacciné éligible pour entry = $this_monday")
		end
		# numéros de lignes, qui sont sélectionnées:
		selected = sample(eligible, min(vaccinated_count, length(eligible)), replace=false)
		for i in selected
			# INFO: Chaque ligne sélectionnée dans group:
			row = group[i, :]
			# INFO: un non-vaccinés sort soit à la fin de la subgroup, soit au moment de sa vaccination.
			vaccinated = false
			entry = this_monday
			exit = min(row.week_of_dose1, this_monday + Week(53))
			death = row.week_of_death
			DCCI = [(row.DCCI, this_monday)] # TEST: remplacement par la valeur de DCCI
			push!(subgroup, (
																		vaccinated = vaccinated,
																		entry = entry,
																		exit = exit,
																		death = death,
																		DCCI = DCCI,
																		))
			# INFO: Un non-vaccinés redevient disponible soit lorsqu'il est vaccinés, soit lorsqu'il sort de la subgroup. Attention, il pourrait être "disponible", après sa mort, d'où l'importance de vérifier si les non-vaccinés ne sont pas mort, avant d'intégrer ou de réintégrer une subgroup!
			group[i, :available] = exit + Week(1)
		end
	end
	# INFO: Il faut ensuite noter dans `when_what_where_dict` les non-vaccinés qui devront être remplacés, et quand.
	# Itérateur sur les non-vaccinés à remplacer (when, what, where)
	when_what_where_iter = (
													(row.exit, # Semaine de la vaccination du non-vacciné
													 this_monday, # Identifiant (une date) du subgroup
													 i) # Numéro de ligne du non-vaccinés à remplacer.
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
			get!(_, _when, Dict{Date, Vector{Int}}())
			# INFO: Chercher dans le dictionnaire `inner_dict` la clé `_what`. Si elle existe, retourner la valeur associée (un objet de type Vector{Int}); si elle n'existe pas, créer une paire `clé => valeur` dont la valeur est un objet vide de type `Vector{Int}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_vector` (les lignes à changer, c'est-à-dire les non-vaccinés à remplacer, dans les `subgroups`).
			get!(_, _what, Int[])
			# ajouter au vecteur `inner_vector` la valeur `_where`.
			append!(_, _where)
		end
	end
end

function replace_unvaccinated!(
		this_monday::Date,
		group::DataFrame,
		subgroups::Dict{Date, DataFrame},
		when_what_where_dict::Dict{Date, Dict{Date, Vector{Int}}}
		)
	# rien à faire si aucun remplacement planifié pour this_monday
	if !haskey(when_what_where_dict, this_monday)
		return nothing
	end
	_when = this_monday
	inner_dict = when_what_where_dict[_when]
	# Les éligibles doivent être calculés dans chaque fonction `process_first_unvaccinated` et `replace_unvaccinated`.
	eligible = findall(row ->
										 # Sont éligibles, à la date de remplacement:
										 # les vivants:
										 _when <= row.week_of_death &&
										 # non-vaccinés:
										 _when < row.week_of_dose1 &&
										 # qui ne sont pas encore dans un autre subgroup:
										 row.available < _when,
										 eachrow(group)
										 )
	for (_what, _where) in inner_dict
		if length(eligible) < length(_where)
			error("$this_monday: Impossible replacement in $(_what)! `eligible` is lesser than length(_where)!")
		end
		if length(eligible) >= length(_where)
			selected = sample(eligible, length(_where), replace=false)
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
				subgroup.exit[i]  = exit
				subgroup.death[i] = death
				push!(subgroup.DCCI[i], (group[s, :DCCI], this_monday))  # TEST: remplacement par la valeur de DCCI
				if vaccination_date <= subgroup_end # Même chose que dans la fonction `process_first_unvaccinated`
					@chain begin
						# dans when_what_where_dict (un dictionnaire)
						when_what_where_dict
						# récupérer la valeur de la clé `vaccination_date` (un dictionnaire)
						get!(_, vaccination_date, Dict{Date, Vector{Int}}())
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

# dcci_treatment.jl
function dcci_treatment!(df::DataFrame)
	newcol = Vector{Vector{Tuple{Int, Int}}}(undef, nrow(df))
	@inbounds for i in 1:nrow(df)
		old = df.DCCI[i]
		n = length(old)
		# accumulation par code : 0..5 → indices 1..6
		durations = zeros(Int, 6)
		first_is_special = (old[1][2] == VERY_FIRST_ENTRY)
		for j in 1:n
			(code, date) = old[j]
			adjustment = (j == 1 && first_is_special) ? Day(6) : Day(3)
			current_date = date + adjustment
			if j < n
				end_date = old[j + 1][2] + Day(3)
			else
				if first_is_special
					if df.entry[i] == df.death[i]
						end_date = df.entry[i] + Day(7)
						@info "df.entry[i] = $(df.entry[i]); end_date = $end_date"
					else
						end_date = min(df.exit[i], df.death[i] + Day(3))
					end
				else
					if df.entry[i] == df.death[i]
						end_date = df.entry[i] + Day(7)
					else
						end_date = min(df.exit[i] - Day(3), df.death[i] + Day(3))
					end
				end
			end
			durations[code + 1] += Dates.value(end_date - current_date)
		end
		# reconstruction
		newcol[i] = [(code - 1, durations[code])
								 for code in 1:6 if durations[code] > 0]
	end
	df.DCCI = newcol
	return df
end

@info "Loading completed"
