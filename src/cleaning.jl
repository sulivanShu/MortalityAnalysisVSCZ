@info "Cleaning dataframes"

# Processing
ThreadsX.foreach(values(dfs)) do df
	# Garantir l'absence de missing
	@assert all(!ismissing, df.week_of_dose1)
	@assert all(!ismissing, df.week_of_death)
	# Purify the type
	disallowmissing!(df, [:week_of_dose1, :week_of_death])
	# Remove temporal inconsistencies
	filter!(r -> r.week_of_dose1 <= r.week_of_death ||
					r.week_of_dose1 == Date("10000-01-01"),
					df)
end

@info "Cleaning dataframes done"
