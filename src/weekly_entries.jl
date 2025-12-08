subgroup_id = 11920
these_mondays = vcat(ENTRIES[1:8], ENTRIES[54:131])
Random.seed!(0)
weekly_entries = create_weekly_entries(ENTRIES, subgroup_id, these_mondays, MONDAYS, dfs)

# TODO return when_what_where_dict et autre chose?
# function find_last_valid(ENTRIES; maxk=10)
# 	tail = ENTRIES[54:131]
# 	weekly_entries = nothing
# 	for k in 1:maxk
# 		vec = vcat(ENTRIES[1:k], tail)
# 		try
# 			weekly_entries = create_weekly_entries(ENTRIES, subgroup_id, vec)
# 		catch
# 			return weekly_entries
# 		end
# 	end
# 	return weekly_entries
# end
# weekly_entries = sort(find_last_valid(ENTRIES))
# sort(weekly_entries)

# println(sort(weekly_entries))
