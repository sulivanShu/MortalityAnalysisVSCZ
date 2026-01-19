@info "Translating header"

# Constants
# INFO: MY_ENGLISH_HEADER already defined in src/constants.jl
const MY_ENGLISH_HEADER = [
    "infection_rank",
    "sex",
    "_5_years_cat_of_birth",
    "dose1_week",
    "death_week",
    "DCCI",
]

# Processing
rename!(dfs, MY_CZECH_HEADER .=> MY_ENGLISH_HEADER)

@info "Header translation completed"
