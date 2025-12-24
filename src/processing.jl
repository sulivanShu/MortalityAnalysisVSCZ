@info "mortality computing"

# Constants
# INFO: date de vaccination moyenne: dimanche 27-12-2020 à 14h :
const VERY_FIRST_WEEK_ADJUSTMENT = (10/24)/7
# INFO: date de vaccination moyenne: mercredi à minuit :
const OTHER_FIRST_WEEK_ADJUSTMENT = 4/7
# INFO: ajout des (7.24+14/24) jours manquants pour faire 365.24 jours :
const FIRST_LAST_WEEK_ADJUSTMENT = (7.24+14/24)/7
# INFO: ajout des 4.24 jours manquants pour faire 365.24 jours :
const OTHER_LAST_WEEK_ADJUSTMENT = 4.24/7

# Functions
function processing(df::DataFrame)
	vaccinated_accumulator = zeros(Int, 6)   # index 1 ↔ DCCI 0, ..., index 6 ↔ DCCI 5
	vaccinated_individuals = zeros(Int, 6)
	vaccinated_very_first_week_deaths = zeros(Int, 6)
	vaccinated_first_last_week_deaths = zeros(Int, 6)
	vaccinated_other_first_week_deaths = zeros(Int, 6)
	vaccinated_other_last_week_deaths = zeros(Int, 6)
	vaccinated_other_week_deaths = zeros(Int, 6)
	unvaccinated_total_days = 0 # INFO: en plus
	unvaccinated_accumulator = zeros(Int, 6)
	unvaccinated_individuals = 0
	unvaccinated_very_first_week_deaths = 0
	unvaccinated_first_last_week_deaths = 0
	unvaccinated_other_first_week_deaths = 0
	unvaccinated_other_last_week_deaths = 0
	unvaccinated_other_week_deaths = 0
	for r in eachrow(df)
		if r.vaccinated
			# INFO: il est garanti que les vaccinés ne comptent qu'une seule paire par ligne à la colonne :DCCI (pas un individu composite), donc pas de problème de double comptage.
			# TODO: compter les morts other: pas encore le cas.
			@assert length(r.DCCI) == 1 "Vaccinated row with multiple DCCI detected!"
			(dcci, days) = r.DCCI[1]
			vaccinated_accumulator[dcci + 1] += days
			vaccinated_individuals[dcci + 1] += 1
			if r.death == VERY_FIRST_ENTRY
				vaccinated_very_first_week_deaths[dcci + 1] += 1
			elseif r.death == r.entry # INFO: other_first_week
				vaccinated_other_first_week_deaths[dcci + 1] += 1
			elseif r.entry < r.death < r.exit
				vaccinated_other_week_deaths[dcci + 1] += 1
			elseif r.entry == VERY_FIRST_ENTRY && r.death == FIRST_LAST_WEEK
				vaccinated_first_last_week_deaths[dcci + 1] += 1
			elseif r.death == VERY_FIRST_ENTRY + Week(53)
				vaccinated_other_last_week_deaths[dcci + 1] += 1
			end
		else
			for (dcci, days) in r.DCCI
				unvaccinated_accumulator[dcci + 1] += days
				unvaccinated_total_days += days
			end
			unvaccinated_individuals += 1
			if r.death == VERY_FIRST_ENTRY
				unvaccinated_very_first_week_deaths += 1
			elseif r.death == r.entry # INFO: other_first_week
				unvaccinated_other_first_week_deaths += 1
			elseif r.entry < r.death < r.exit
				unvaccinated_other_week_deaths += 1
			elseif r.entry == VERY_FIRST_ENTRY && r.death == FIRST_LAST_WEEK
				unvaccinated_first_last_week_deaths += 1
			elseif r.death == VERY_FIRST_ENTRY + Week(53)
				unvaccinated_other_last_week_deaths += 1
			end
		end
	end
	# construction de vaccinated_df
	adjusted_vaccinated_first_last_week_deaths = vaccinated_first_last_week_deaths * FIRST_LAST_WEEK_ADJUSTMENT
	adjusted_vaccinated_other_last_week_deaths = vaccinated_other_last_week_deaths * OTHER_LAST_WEEK_ADJUSTMENT
	vaccinated_deaths =
	vaccinated_very_first_week_deaths +
	vaccinated_other_first_week_deaths +
	vaccinated_other_week_deaths +
	adjusted_vaccinated_first_last_week_deaths +
	adjusted_vaccinated_other_last_week_deaths
	vaccinated_mortality =
	vaccinated_deaths ./
	# INFO: la fonction mean accepte en entrée un vecteur de vecteurs, et renvoie alors un vecteur de moyennes calculé éléments par éléments (moyenne de tous les premiers éléments, puis de tous les deuxièmes, puis de tous les troisièmes, etc.).
	mean([
				vaccinated_individuals,
				(vaccinated_individuals - vaccinated_deaths
				 )])
	vaccinated_df = DataFrame(
														standardized = fill(false, 6),
														vaccinated = fill(true, 6),
														DCCI = 0:5,
														days = collect(vaccinated_accumulator),
														individuals = vaccinated_individuals,
														very_first_week_deaths = vaccinated_very_first_week_deaths,
														other_first_week_deaths = vaccinated_other_first_week_deaths,
														other_week_deaths = vaccinated_other_week_deaths,
														first_last_week_deaths = adjusted_vaccinated_first_last_week_deaths,
														other_last_week_deaths = adjusted_vaccinated_other_last_week_deaths,
														deaths = vaccinated_deaths,
														mortality = vaccinated_mortality,
														)
	# construction de unstandardized_vaccinated_df
	unstandardized_dcci = [collect(zip(vaccinated_df[1:6, :DCCI], vaccinated_df[1:6, :days]))]
	days = [sum(vaccinated_df[1:6, :days])]
	individuals = [sum(vaccinated_df[1:6, :individuals])]
	very_first_week_deaths = [sum(vaccinated_df[1:6, :very_first_week_deaths])]
	other_first_week_deaths = [sum(vaccinated_df[1:6, :other_first_week_deaths])]
	other_week_deaths = [sum(vaccinated_df[1:6, :other_week_deaths])]
	first_last_week_deaths = [sum(vaccinated_df[1:6, :first_last_week_deaths])]
	other_last_week_deaths = [sum(vaccinated_df[1:6, :other_last_week_deaths])]
	deaths = [sum(vaccinated_df[1:6, :deaths])]
	unstandardized_vaccinated_mortality = # INFO: Correct
	deaths ./
	mean([
				individuals,
				(individuals - deaths
				 )])
	unstandardized_vaccinated_df = DataFrame(
																					 standardized = false,
																					 vaccinated = true,
																					 DCCI = unstandardized_dcci,
																					 days = days,
																					 individuals = individuals,
																					 very_first_week_deaths = very_first_week_deaths,
																					 other_first_week_deaths = other_first_week_deaths,
																					 other_week_deaths = other_week_deaths,
																					 first_last_week_deaths = first_last_week_deaths,
																					 other_last_week_deaths = other_last_week_deaths,
																					 deaths = deaths,
																					 mortality = unstandardized_vaccinated_mortality,
																					 )
	# construction de unvaccinated_df
	adjusted_unvaccinated_very_first_week_deaths = unvaccinated_very_first_week_deaths * VERY_FIRST_WEEK_ADJUSTMENT
	adjusted_unvaccinated_other_first_week_deaths = unvaccinated_other_first_week_deaths * OTHER_FIRST_WEEK_ADJUSTMENT
	adjusted_unvaccinated_first_last_week_deaths = unvaccinated_first_last_week_deaths * FIRST_LAST_WEEK_ADJUSTMENT
	adjusted_unvaccinated_other_last_week_deaths = unvaccinated_other_last_week_deaths * OTHER_LAST_WEEK_ADJUSTMENT
	unvaccinated_deaths =
	unvaccinated_very_first_week_deaths +
	unvaccinated_other_first_week_deaths +
	unvaccinated_other_week_deaths +
	adjusted_unvaccinated_first_last_week_deaths +
	adjusted_unvaccinated_other_last_week_deaths
	dcci_mixed = [[(dcci, unvaccinated_accumulator[dcci + 1]) for dcci in 0:5]]
	unvaccinated_mortality =
	[unvaccinated_deaths] ./
	mean([
				[unvaccinated_individuals],
				([unvaccinated_individuals] - [unvaccinated_deaths]
				 )])
	unvaccinated_df = DataFrame(
															standardized = true,
															vaccinated = false,
															DCCI = dcci_mixed,
															days = unvaccinated_total_days,
															individuals = [unvaccinated_individuals],
															very_first_week_deaths = [adjusted_unvaccinated_very_first_week_deaths],
															other_first_week_deaths = [adjusted_unvaccinated_other_first_week_deaths],
															other_week_deaths = [unvaccinated_other_week_deaths],
															first_last_week_deaths = [adjusted_unvaccinated_first_last_week_deaths],
															other_last_week_deaths = [adjusted_unvaccinated_other_last_week_deaths],
															deaths = [unvaccinated_deaths],
															mortality = unvaccinated_mortality,
															)
	# construction de standardized_vaccinated_df
	vaccinated_weights = vaccinated_df[:, :days] # last.(unstandardized_vaccinated_df[1, :DCCI])
	unvaccinated_weights = last.(unvaccinated_df[1, :DCCI])
	especial_days_ratio = map(/, last.(unvaccinated_weights), last.(vaccinated_weights))
	total_before_standardization = unstandardized_vaccinated_df[1, :individuals]
	total_after_standardization = sum(vaccinated_df[1:6, :individuals] .* especial_days_ratio)
	individuals_standardized_sum =
	sum(vaccinated_df[1:6, :individuals] ./
			total_after_standardization .*
			total_before_standardization .*
			especial_days_ratio)
	very_first_week_standardized_vaccinated_deaths = [
																										sum(vaccinated_df[1:6, :very_first_week_deaths] ./
																												total_after_standardization .*
																												total_before_standardization .*
																												especial_days_ratio)
																										]
	other_first_week_standardized_vaccinated_deaths = [
																										 sum(vaccinated_df[1:6, :other_first_week_deaths] ./
																												 total_after_standardization .*
																												 total_before_standardization .*
																												 especial_days_ratio)
																										 ]
	other_week_standardized_vaccinated_deaths = [
																							 sum(vaccinated_df[1:6, :other_week_deaths] ./
																									 total_after_standardization .*
																									 total_before_standardization .*
																									 especial_days_ratio)
																							 ]
	first_last_week_standardized_vaccinated_deaths = [
																										sum(vaccinated_df[1:6, :first_last_week_deaths] ./
																												total_after_standardization .*
																												total_before_standardization .*
																												especial_days_ratio)
																										]
	other_last_week_standardized_vaccinated_deaths = [
																										sum(vaccinated_df[1:6, :other_last_week_deaths] ./
																												total_after_standardization .*
																												total_before_standardization .*
																												especial_days_ratio)
																										]
	standardized_vaccinated_deaths = [
																		sum(vaccinated_df[1:6, :deaths] ./
																				total_after_standardization .*
																				total_before_standardization .*
																				especial_days_ratio)
																		]
	standardized_vaccinated_mortality =
	standardized_vaccinated_deaths ./
	mean([
				individuals,
				(individuals - standardized_vaccinated_deaths
				 )])
	standardized_vaccinated_df = DataFrame(
																				 standardized = true,
																				 vaccinated = true,
																				 DCCI = dcci_mixed,
																				 days = unvaccinated_total_days,
																				 individuals = individuals,
																				 very_first_week_deaths = very_first_week_standardized_vaccinated_deaths,
																				 other_first_week_deaths = other_first_week_standardized_vaccinated_deaths,
																				 other_week_deaths = other_week_standardized_vaccinated_deaths,
																				 first_last_week_deaths = first_last_week_standardized_vaccinated_deaths,
																				 other_last_week_deaths = other_last_week_standardized_vaccinated_deaths,
																				 deaths = standardized_vaccinated_deaths,
																				 mortality = standardized_vaccinated_mortality,
																				 )
	# standardized_vaccinated_df
	# assemblage final
	result = vcat(
								select(vaccinated_df, :),
								select(unstandardized_vaccinated_df, :),
								select(unvaccinated_df, :),
								select(standardized_vaccinated_df, :),
								)
	result.DCCI = Vector{Union{Int, Vector{Tuple{Int, Int}}}}(result.DCCI)
	result[:, [
						 :standardized,
						 :vaccinated,
						 :DCCI,
						 :days,
						 :individuals,
						 :very_first_week_deaths,
						 :other_first_week_deaths,
						 :other_week_deaths,
						 :first_last_week_deaths,
						 :other_last_week_deaths,
						 :deaths,
						 :mortality,
						 ]]
end

# Processing
processed =
Dict(
		 ThreadsX.map(
									((k, df),) -> k => processing(df),
									collect(exact_selection)
								 )
		)

result = DataFrame(
									 key = Int[],
									 gross_vaccinated = Float64[],
									 standardized_vaccinated = Float64[],
									 standardized_unvaccinated = Float64[],
									 standardized_ratio = Float64[],
									)

for (k, df) in processed
	deaths = df[7:9, :mortality]
	push!(
				result,
				(
				 key = k,
				 gross_vaccinated = deaths[1],
				 standardized_unvaccinated = deaths[2],
				 standardized_vaccinated = deaths[3],
				 standardized_ratio = deaths[2] / deaths[3],
				)
			 )
end

sort!(result, :key)

@info "mortality computing completed"
