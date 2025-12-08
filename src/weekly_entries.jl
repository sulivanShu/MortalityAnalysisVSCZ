subgroup_id = 11920
these_mondays = vcat(entries[1:8], entries[54:131])
Random.seed!(0)
weekly_entries = create_weekly_entries(entries, subgroup_id, these_mondays, mondays, dfs)

# TODO return when_what_where_dict et autre chose?
# function find_last_valid(entries; maxk=10)
# 	tail = entries[54:131]
# 	weekly_entries = nothing
# 	for k in 1:maxk
# 		vec = vcat(entries[1:k], tail)
# 		try
# 			weekly_entries = create_weekly_entries(entries, subgroup_id, vec)
# 		catch
# 			return weekly_entries
# 		end
# 	end
# 	return weekly_entries
# end
# weekly_entries = sort(find_last_valid(entries))
sort(weekly_entries)

println(sort(weekly_entries))
