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

# weekly_entries.jl

function create_weekly_entries(ENTRIES::Vector{Date}, subgroup_id::Int64,
		these_mondays::Vector{Date}, MONDAYS::Vector{Date}, dfs::Dict{Int64, DataFrame})
	subgroup = deepcopy(dfs[subgroup_id]) # créée une vraie copie, pour les tests. subgroup est modifié, il faut le redéfinir à chaque exécution.
	weekly_entries = Dict(entry => DataFrame(vaccinated=Bool[],
																					 entry=Date[],
																					 exit=Date[],
																					 death=Date[])
												for entry in ENTRIES)
	when_what_where_dict = Dict{Date, Dict{Date, Vector{Int}}}()
	for this_monday in MONDAYS
		if this_monday in these_mondays
			weekly_entry = weekly_entries[this_monday]
			# Pour les vaccinés
			vaccinated_count = process_vaccinated!(subgroup,
																						 weekly_entry,
																						 this_monday)
			# Pour les premiers non-vaccinés
			process_first_unvaccinated!(subgroup,
																	weekly_entry,
																	this_monday,
																	vaccinated_count,
																	when_what_where_dict)
		end
		# Pour les non-vaccinés de remplacement
		replace_unvaccinated!(this_monday,
													subgroup,
													weekly_entries,
													when_what_where_dict)
	end
	return weekly_entries
	# TODO return when_what_where_dict et autre chose?
end

function process_vaccinated!(
		subgroup::DataFrame,
		weekly_entry::DataFrame,
		this_monday::Date) # AbstractDict si weekly_entries est un `OrderedDict`, mais ce n'est pas le cas
	# Repérer dans `subgroup` les vaccinés de la `weekly_entry` en cours, puis les mettre dans weekly_entries[entry], puis les marquer comme non-disponibles dans `subgroup`.
	for row in eachrow(subgroup)
		if row.week_of_dose1 == this_monday
			push!(weekly_entry, (
																		vaccinated = true,
																		entry = this_monday,
																		exit = this_monday + Week(53),
																		death = row.week_of_death
																		))
			row.available = UNAVAILABLE
		end
	end
	return nrow(weekly_entry) # renvoie le nombre de vaccinés ajoutés à entry
end

function process_first_unvaccinated!(
		subgroup::DataFrame,
		weekly_entry::DataFrame,
		entry::Date,
		vaccinated_count::Int,
		when_what_where_dict::Dict{Date, Dict{Date, Vector{Int}}}
		)
	if vaccinated_count != 0
		eligible = findall(row ->
											 # sont éligibles:
											 # les vivants:
											 entry <= row.week_of_death &&
											 # non-vaccinés:
											 entry < row.week_of_dose1 &&
											 # qui ne sont pas encore dans un autre weekly_entry:
											 row.available < entry,
											 eachrow(subgroup))
		if !isempty(eligible) && length(eligible) < vaccinated_count
			@error "$this_monday: Moins de non-vaccinés que de vaccinés pour entry = $entry"
		end
		if isempty(eligible)
			@error "$this_monday: Aucun non-vacciné éligible pour entry = $entry"
		end
		# numéros de lignes, qui sont sélectionnées:
		selected = sample(eligible, min(vaccinated_count, length(eligible)), replace=false)
		for i in selected
			# Chaque ligne sélectionnée dans subgroup:
			row = subgroup[i, :]
			# un non-vaccinés sort soit à la fin de la weekly_entry, soit au moment de sa vaccination.
			exit = min(row.week_of_dose1, entry + Week(53))
			push!(weekly_entry, (
													 vaccinated = false,
													 entry = entry,
													 exit = exit,
													 death = row.week_of_death
													 ))
			# Un non-vaccinés redevient disponible soit lorsqu'il est vaccinés, soit lorsqu'il sort de la weekly_entry. Attention, il pourrait être "disponible", après sa mort, d'où l'importance de vérifier si les non-vaccinés ne sont pas mort, avant d'intégrer ou de réintégrer une weekly_entry!
			subgroup[i, :available] = exit + Week(1)
		end
	end
	# Il faut ensuite noter dans `when_what_where_dict` les non-vaccinés qui devront être remplacés, et quand.
	# Itérateur sur les non-vaccinés à remplacer (when, what, where)
	when_what_where_iter = (
													(row.exit, # Semaine de la vaccination du non-vacciné
													 entry, # Identifiant (une date) du weekly_entry
													 i) # Numéro de ligne du non-vaccinés à remplacer.
													for (i, row) in enumerate(eachrow(weekly_entry))
													# On ne retient que les individus dont la durée (exit - entry) est strictement inférieure à 53 semaines, c’est-à-dire ceux qui se vaccinent avant la fin de la période d’observation.
													if (row.exit - row.entry) < Week(53)
													)
	# Écriture directe dans when_what_where_dict
	# Ce dictionnaire imbriqué est de type Dict{Date, Dict{Date, Vector{Int}}}
	# _when: quand faire le remplacement: au moment de la vaccination d'un non-vacciné,
	# _what: dans quel weekly_entry faire le remplacement,
	# _where: dans le weekly_entry, quel est le numéro de ligne du non-vacciné à remplacer.
	for (_when, _what, _where) in when_what_where_iter
		# Dans `when_what_where_dict`: récupère (ou crée si absent) le dictionnaire interne associé à la date de vaccination du non-vacciné (_when).
		@chain begin
			# Chercher dans le dictionnaire `when_what_where_dict` la clé `_when`. Si elle existe, retourner la valeur associée (un objet de type `Dict{Date, Vector{Int}}`); si elle n'existe pas, créer une paire `_when => valeur` dont la valeur est un objet vide de type `Dict{Date, Vector{Int}}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_dict`.
			when_what_where_dict
			get!(_, _when, Dict{Date, Vector{Int}}())
			# Chercher dans le dictionnaire `inner_dict` la clé `_what`. Si elle existe, retourner la valeur associée (un objet de type Vector{Int}); si elle n'existe pas, créer une paire `clé => valeur` dont la valeur est un objet vide de type `Vector{Int}`, puis retourner cet objet vide. Dans les deux cas, appelons cet objet `inner_vector` (les lignes à changer, c'est-à-dire les non-vaccinés à remplacer, dans les `weekly_entries`).
			get!(_, _what, Int[])
			# ajouter au vecteur `inner_vector` la valeur `_where`.
			append!(_, _where)
		end
	end
end

function replace_unvaccinated!(
		this_monday::Date,
		subgroup::DataFrame,
		weekly_entries::Dict{Date, DataFrame},
		when_what_where_dict::Dict{Date, Dict{Date, Vector{Int}}}
		)
	# rien à faire si aucun remplacement planifié pour ce this_monday
	if !haskey(when_what_where_dict, this_monday)
		return nothing
	end
	_when = this_monday
	inner_dict = when_what_where_dict[_when]
	# TODO supprimer ces commentaires? ces trucs sont-ils vraiment utiles? il vaut mieux utiliser la macro @debug
	## affichage lisible du dictionnaire imbriqué (optionnel, utile pour debug)
	# rows = [
	# 				(outer_date = outer, inner_date = inner, values = join(v, ", "))
	# 				for (outer, inner_dict_) in when_what_where_dict
	# 				for (inner, v) in inner_dict_
	# 				]
	# df_info = DataFrame(rows)
	# df_info_for_this_monday = filter(row -> row.outer_date == _when, df_info)
	# @info "$_when: état de when_what_where_dict:" df_info_for_this_monday
	# @info "$this_monday: Remplacements à faire"
	# Les éligibles doivent être calculés dans chaque fonction `process_first_unvaccinated` et `replace_unvaccinated`.
	eligible = findall(row ->
										 # Sont éligibles, à la date de remplacement:
										 # les vivants:
										 _when <= row.week_of_death &&
										 # non-vaccinés:
										 _when < row.week_of_dose1 &&
										 # qui ne sont pas encore dans un autre weekly_entry:
										 row.available < _when,
										 eachrow(subgroup)
										 )
	for (_what, _where) in inner_dict
		if length(eligible) < length(_where)
			if isempty(eligible)
				@error "$this_monday: Replacement impossible in $(_what)! `eligible` is empty!"
			else
				@error "$this_monday: Replacement impossible in $(_what)! `eligible` is lesser than length(_where)!"
			end
		end
		if length(eligible) >= length(_where)
			selected = sample(eligible, length(_where), replace=false)
			for i in selected
				row = subgroup[i, :]
				exit = min(row.week_of_dose1, _what + Week(53))
				subgroup[i, :available] = exit + Week(1)
			end
			weekly_entry = weekly_entries[_what]
			for (k, i) in enumerate(_where)
				s = selected[k]
				weekly_entry_end = _what + Week(53)
				vaccination_date = subgroup[s, :week_of_dose1]
				exit = min(weekly_entry_end, vaccination_date)
				weekly_entry.exit[i]  = exit
				weekly_entry.death[i] = subgroup[s, :week_of_death]
				if vaccination_date <= weekly_entry_end # Même chose que dans la fonction `process_first_unvaccinated`
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

@info "Loading completed"
