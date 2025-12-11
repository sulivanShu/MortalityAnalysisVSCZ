@info "Weekly entries selection (parallel)"
@load "data/exp_pro/approximate_selection.jld2" approximate_selection
const APPROXIMATE_SELECTION = approximate_selection
const SUBGROUP_ID_VEC = @chain begin
	dfs
	keys
	collect
end
const EXACT_SELECTION =
ThreadsX.map(SUBGROUP_ID_VEC) do subgroup_id
	subgroup_id => select_weekly_entries(ENTRIES, APPROXIMATE_SELECTION, subgroup_id)
end |> Dict

dfs = nothing
@info "Weekly entries selection completed (parallel)"
