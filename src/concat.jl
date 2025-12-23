@info "Concate dataframes in groups"

# Processing
exact_selection = Dict(
    ThreadsX.map(
        k -> begin
            k => vcat(values(exact_selection[k])...)
        end,
        keys(exact_selection)
    )
)

@info "Concatenation completed"
