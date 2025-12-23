@info "Drop unused columns"

# Functions
function drop_unused_columns!(df::DataFrame)
	select!(df, Not([
									 :week_of_dose2,
									 :week_of_dose3,
									 :week_of_dose4,
									 :week_of_dose5,
									 :week_of_dose6,
									 :week_of_dose7,
									 ]))
end

# Processing
ThreadsX.foreach(drop_unused_columns!, dfs)

@info "Unused columns droped"
