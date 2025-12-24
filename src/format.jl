@info "Formatting data"

# Functions
function convert_to_uint8!(df::DataFrame, col::Symbol)
	df[!, col] = convert(Vector{Union{Missing, UInt8}}, df[!, col])
	return df
end

function first_monday_of_ISOyear(year::Int)
	jan4 = Date(year, 1, 4)  # Le 4 janvier est toujours dans la semaine 1 ISO
	monday = firstdayofweek(jan4)  # Premier lundi de la semaine contenant le 4 janvier
	return monday
end

function parse_year_column!(df::DataFrame, col::Symbol) # encoder avec UInt8 est possible mais moins lisible.
	df[!, col] = map(x -> 
									 length(String(x)) == 1 ? missing : UInt16(parse(Int, first(String(x), 4))),
									df[!, col]
									)
	return df
end

function isoweek_to_date!(df::DataFrame, col::Symbol)
	df[!, col] = map(x -> 
									 ismissing(x) ? missing : begin
										 year, week = parse.(Int, split(x, "-"))
										 first_monday_of_ISOyear(year) + Week(week - 1)
									 end,
									df[!, col])
	return df
end

# Processing
ThreadsX.foreach(subdf -> begin
									 convert_to_uint8!(subdf, :sex)
									 convert_to_uint8!(subdf, :infection_rank)
									 parse_year_column!(subdf, :_5_years_cat_of_birth)
									 isoweek_to_date!(subdf, :week_of_dose1)
									 isoweek_to_date!(subdf, :week_of_death)
									end, dfs)

@info "Formatting completed"
