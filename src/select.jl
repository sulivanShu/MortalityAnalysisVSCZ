@info "Weekly entries selection (parallel)"
@load "data/exp_pro/approximate_selection.jld2" approximate_selection
const APPROXIMATE_SELECTION = approximate_selection
const GROUP_ID_VEC = @chain begin
	dfs
	keys
	collect
end
exact_selection =
ThreadsX.map(GROUP_ID_VEC) do group_id
	group_id => select_subgroups(ENTRIES, APPROXIMATE_SELECTION, group_id)
end |> Dict

# TODO: pour vider la mémoire
# dfs = nothing
@info "Weekly entries selection completed (parallel)"
