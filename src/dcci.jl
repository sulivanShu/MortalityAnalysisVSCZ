@info "dcci treatment"

# Functions
function dcci_treatment!(df::DataFrame)
	newcol = Vector{Vector{Tuple{Int, Int}}}(undef, nrow(df))
	@inbounds for i in 1:nrow(df)
		old = df.DCCI[i]
		n = length(old)
		# accumulation par code : 0..5 → indices 1..6
		durations = zeros(Int, 6)
		first_is_special = (old[1][2] == VERY_FIRST_ENTRY)
		for j in 1:n
			(code, date) = old[j]
			adjustment = (j == 1 && first_is_special) ? Day(6) : Day(3)
			current_date = date + adjustment
			if j < n
				end_date = old[j + 1][2] + Day(3)
			else
				if first_is_special
					if df.entry[i] == df.death[i]
						end_date = df.entry[i] + Day(7)
					else
						end_date = min(df.exit[i], df.death[i] + Day(3))
					end
				else
					if df.entry[i] == df.death[i]
						end_date = df.entry[i] + Day(7)
					else
						end_date = min(df.exit[i] - Day(3), df.death[i] + Day(3))
					end
				end
			end
			durations[code + 1] += Dates.value(end_date - current_date)
		end
		# reconstruction
		newcol[i] = [(code - 1, durations[code])
								 for code in 1:6 if durations[code] > 0]
	end
	df.DCCI = newcol
	return df
end

# Processing
ThreadsX.foreach(values(exact_selection)) do df
	dcci_treatment!(df)
end

@info "dcci treatment completed"
