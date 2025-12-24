@info "Filtering data"

# Functions
function is_valid_df(df::DataFrame)
	first_row = df[1, :]
	!ismissing(first_row._5_years_cat_of_birth) &&
	1920 <= first_row._5_years_cat_of_birth < 2020 &&
	!ismissing(first_row.sex)
end

function modify_df!(df::DataFrame)
	cutoff = Date("2020-12-21") # TODO: remplacer par une variable
	filter!(row -> (ismissing(row.infection_rank) || row.infection_rank == 1) &&
					(ismissing(row.week_of_death) || row.week_of_death > cutoff), # Décédé strictement avant la semaine de vaccination.
					df)
	select!(df, Not(:infection_rank))
end

# Processing
filter!(is_valid_df, dfs)
ThreadsX.foreach(df -> modify_df!(df), dfs)

@info "Filtering completed"
