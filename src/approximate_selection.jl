# Very bad algo to find last valid weekly_entries at the begin of 2021.
# Performance can be multiplied by >10 if the algorithm is less primitive.
approximate_selection = Dict{Int, Int}()
subgroup_id_vec = @chain begin
	dfs
	keys
	collect
	sort
end
Random.seed!(0)
function find_last_valid(ENTRIES, subgroup_id; maxk=53)
	tail = ENTRIES[54:131]
	# weekly_entries = nothing
	ok = 0
	for k in 1:maxk
		vec = vcat(ENTRIES[1:k], tail)
		try
			# weekly_entries =
			create_weekly_entries(ENTRIES,
														subgroup_id,
														vec,
														MONDAYS,
														dfs)
			ok = k
		catch e
			# Une erreur s'est produite : on arrête immédiatement la boucle
			@info "subgroup_id = $subgroup_id\nDernière valeur ok de k : $ok"
			break  # ou return ok pour quitter la fonction directement
		end
	end
	return ok
end
approximate_selection =
ThreadsX.map(subgroup_id_vec) do subgroup_id
	subgroup_id => find_last_valid(ENTRIES, subgroup_id)
end |> Dict
@save "data/exp_pro/approximate_selection.jld2" approximate_selection
