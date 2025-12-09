@load "data/exp_pro/approximate_selection.jld2" approximate_selection
const APPROXIMATE_SELECTION = approximate_selection
Base.delete!(Main, :approximate_selection)
exact_selection = Dict{Int, Int}()
const SUBGROUP_ID_VEC = @chain begin
	dfs
	keys
	collect
end
Random.seed!(0)
function find_last_valid(ENTRIES, APPROXIMATE_SELECTION, subgroup_id; maxk=53)
	tail = ENTRIES[54:131]
	weekly_entries = nothing
	ok = 0
	for k in APPROXIMATE_SELECTION[subgroup_id]:maxk
		vec = vcat(ENTRIES[1:k], tail)
		try
			weekly_entries =
			@chain begin
				create_weekly_entries(ENTRIES,
															subgroup_id,
															vec,
															MONDAYS,
															dfs)
				filter(kv -> nrow(kv[2]) > 0, _)
				sort # pour la visualisation seulement
			end
			ok = k
		catch e
			# Une erreur s'est produite : on arrête immédiatement la boucle
			@info "subgroup_id = $subgroup_id\nDernière valeur ok de k : $ok"
			break  # ou return ok pour quitter la fonction directement
		end
	end
	return weekly_entries
end
exact_selection =
ThreadsX.map(SUBGROUP_ID_VEC) do subgroup_id
	subgroup_id => find_last_valid(ENTRIES, APPROXIMATE_SELECTION, subgroup_id)
end |> Dict

@chain begin
	exact_selection[11945][Date("2022-03-14")]
	# filter(kv -> nrow(kv[2]) > 0, _)
	# sort
end
