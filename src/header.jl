@info "Translating header"

# Constants
# INFO: MY_ENGLISH_HEADER already defined in src/constants.jl
const MY_ENGLISH_HEADER = [
													 "infection_rank",
													 "sex",
													 "_5_years_cat_of_birth",
													 "week_of_dose1",
													 "week_of_dose2",
													 "week_of_dose3",
													 "week_of_dose4",
													 "week_of_dose5",
													 "week_of_dose6",
													 "week_of_dose7",
													 "week_of_death",
													 "DCCI",
													 ]

# Processing
rename!(dfs, MY_CZECH_HEADER .=> MY_ENGLISH_HEADER)

@info "Header translation completed"
