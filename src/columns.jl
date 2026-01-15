@info "Drop unused columns"

# Functions
function drop_unused_columns!(df::DataFrame)
    select!(
        df,
        Not([
            :dose2_week,
            :dose3_week,
            :dose4_week,
            :dose5_week,
            :dose6_week,
            :dose7_week,
        ]),
    )
end

# Processing
ThreadsX.foreach(drop_unused_columns!, dfs)

@info "Unused columns droped"
