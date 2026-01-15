@info "Cleaning dataframes"

# Processing
ThreadsX.foreach(values(dfs)) do df
    # Garantir l'absence de missing
    @assert all(!ismissing, df.dose1_week)
    @assert all(!ismissing, df.death_week)
    # Purify the type
    disallowmissing!(df, [:dose1_week, :death_week])
    # Remove temporal inconsistencies
    filter!(
        r -> r.dose1_week <= r.death_week || r.dose1_week == Date("10000-01-01"),
        df,
    )
end

@info "Cleaning dataframes done"
