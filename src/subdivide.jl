@info "Splitting data in vector of DataFrames (parallel)"

# Processing
dfs = [DataFrame(g) for g in groupby(dfs, [:_5_years_cat_of_birth, :sex])]

@info "Splitting completed (parallel)"
