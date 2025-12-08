@info "Loading constantes"
const CZECH_DATA_CSV = "data/exp_raw/Otevrena-data-NR-26-30-COVID-19-prehled-populace-2024-01.csv"
const CZECH_DATA_CSV_URL = "https://data.mzcr.cz/data/distribuce/402/Otevrena-data-NR-26-30-COVID-19-prehled-populace-2024-01.csv"
const CZECH_DATA_CSV_B3SUM = "28a58ec2c8360cdf4ae599cc59bd6e8c678aa7ccbab7debc5d3c3faf645dfcd6"
const DUMMY_HASH = "0000000000000000000000000000000000000000000000000000000000000000"
const CZECH_DATA_CSV_QUOTE = "Šanca O., Jarkovský J., Klimeš D., Zelinková H., Klika P., Benešová K., Mužík J., Komenda M., Dušek L. Očkování, pozitivity, hospitalizace pro COVID-19, úmrtí, long covid a komorbidity u osob v ČR. Národní zdravotnický informační portál [online]. Praha: Ministerstvo zdravotnictví ČR a Ústav zdravotnických informací a statistiky ČR, 2024 [cit. 2025-09-29]. Dostupné z: http://www.nzip.cz/data/2135-covid-19-prehled-populace. ISSN 2695-0340"
const MY_CZECH_HEADER = [
									 "Infekce",
									 "Pohlavi",
									 "RokNarozeni",
									 "Datum_Prvni_davka",
									 "Datum_Druha_davka",
									 "Datum_Treti_davka",
									 "Datum_Ctvrta_davka",
									 "Datum_Pata_davka",
									 "Datum_Sesta_davka",
									 "Datum_Sedma_davka",
									 "DatumUmrtiLPZ"
									 ]
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
										 "week_of_death"
										 ]
const UNVACCINATED = Date("10000-01-01")
const STILL_ALIVE = Date("10000-01-01")
const AVAILABLE = Date("-10000-01-01")
const UNAVAILABLE = Date("10000-01-01")
const FIRST_MONDAY = Date("2020-12-21")
const LAST_MONDAY = Date("2024-06-24")
const MONDAYS = collect(FIRST_MONDAY:Week(1):LAST_MONDAY)
const ENTRIES = first(MONDAYS, length(MONDAYS)-53)
const YEAR_WEEK = ["week_of_dose1", "week_of_death"]
const YEAR_YEAR = ["_5_years_cat_of_birth"]
const ENGLISH_HEADER = [
									"id", # unique row identifier, numeric
									"infection_rank", # infection order of the patient, numeric
									"sex", # sex of the patient: 1=male, 2=female, NULL=unknown
									"_5_years_cat_of_birth", # birth year category (5-year bins), string
									"week_of_death", # year and ISO week of positive test, string
									"week_of_death", # year and ISO week of test result, string
									"recovered", # year and ISO week of recovery, string
									"death", # year and ISO week of [covid?] death, string
									"symptom", # symptomatic at testing: 0=no, 1=yes, NULL=unknown
									"test_type", # test type: AG=antigen, PCR=PCR, NULL=unknown
									"week_of_dose1", # year and ISO week of first dose, string
									"week_of_dose2",
									"week_of_dose3",
									"week_of_dose4",
									"week_of_dose5",
									"week_of_dose6",
									"week_of_dose7",
									"vaccine_code_dose1", # vaccine code CO01–CO24, string
									"vaccine_code_dose2",
									"vaccine_code_dose3",
									"vaccine_code_dose4",
									"vaccine_code_dose5",
									"vaccine_code_dose6",
									"vaccine_code_dose7",
									"primary_cause_hosp_covid", # primary reason for COVID hospitalization, 0=no, 1=yes
									"bin_hospitalization", # hospitalized with COVID: 1=yes, NULL=no
									"min_hospitalization", # start week of first hospitalization, string
									"days_hospitalization", # number of days hospitalized, numeric
									"max_hospitalization", # end week of last hospitalization, string
									"bin_ICU", # ICU hospitalization: 0=no, 1=yes, NULL
									"min_ICU",
									"days_ICU",
									"max_ICU",
									"bin_standard_care", # standard bed hospitalization: 0=no, 1=yes, NULL
									"min_standard_care",
									"days_standard_care",
									"max_standard_care",
									"bin_oxygen", # oxygen treatment: 0=no, 1=yes, NULL
									"min_oxygen",
									"days_oxygen",
									"max_oxygen",
									"bin_HFNO", # high-flow nasal oxygen: 0=no, 1=yes
									"min_HFNO",
									"days_HFNO",
									"max_HFNO",
									"bin_mechanical_ventilation_ECMO", # mechanical ventilation/ECMO: 0=no, 1=yes
									"min_mechanical_ventilation_ECMO",
									"days_mechanical_ventilation_ECMO",
									"max_mechanical_ventilation_ECMO",
									"mutation", # mutation determined by PCR, string
									"week_of_death", # week of death in registry, string
									"long_covid", # week of first long COVID report, string
									"DCCI" # comorbidity index at positivity, numeric
								 ]
const CZECH_HEADER = [
								"ID", # unique row identifier, numeric
								"Infekce", # infection order of the patient, numeric
								"Pohlavi", # sex of the patient: 1=male, 2=female, NULL=unknown
								"RokNarozeni", # birth year category (5-year bins), string
								"DatumPozitivity", # year and ISO week of positive test, string
								"DatumVysledku", # year and ISO week of test result, string
								"Vylecen", # year and ISO week of recovery, string
								"Umrti", # year and ISO week of death, string
								"Symptom", # symptomatic at testing: 0=no, 1=yes, NULL=unknown
								"TypTestu", # test type: AG=antigen, PCR=PCR, NULL=unknown
								"Datum_Prvni_davka", # year and ISO week of first dose, string
								"Datum_Druha_davka",
								"Datum_Treti_davka",
								"Datum_Ctvrta_davka",
								"Datum_Pata_davka",
								"Datum_Sesta_davka",
								"Datum_Sedma_davka",
								"OckovaciLatkaKod_Prvni_davka", # vaccine code CO01–CO24, string
								"OckovaciLatkaKod_Druha_davka",
								"OckovaciLatkaKod_Treti_davka",
								"OckovaciLatkaKod_Ctvrta_davka",
								"OckovaciLatkaKod_Pata_davka",
								"OckovaciLatkaKod_Sesta_davka",
								"OckovaciLatkaKod_Sedma_davka",
								"PrimPricinaHospCOVID", # primary reason for COVID hospitalization, 0=no, 1=yes
								"bin_Hospitalizace", # hospitalized with COVID: 1=yes, NULL=no
								"min_Hospitalizace", # start week of first hospitalization, string
								"dni_Hospitalizace", # number of days hospitalized, numeric
								"max_Hospitalizace", # end week of last hospitalization, string
								"bin_JIP", # ICU hospitalization: 0=no, 1=yes, NULL
								"min_JIP",
								"dni_JIP",
								"max_JIP",
								"bin_STAN", # standard bed hospitalization: 0=no, 1=yes, NULL
								"min_STAN",
								"dni_STAN",
								"max_STAN",
								"bin_Kyslik", # oxygen treatment: 0=no, 1=yes, NULL
								"min_Kyslik",
								"dni_Kyslik",
								"max_Kyslik",
								"bin_HFNO", # high-flow nasal oxygen: 0=no, 1=yes
								"min_HFNO",
								"dni_HFNO",
								"max_HFNO",
								"bin_UPV_ECMO", # mechanical ventilation/ECMO: 0=no, 1=yes
								"min_UPV_ECMO",
								"dni_UPV_ECMO",
								"max_UPV_ECMO",
								"Mutace", # mutation determined by PCR, string
								"DatumUmrtiLPZ", # week of death in registry, string
								"Long_COVID", # week of first long COVID report, string
								"DCCI" # comorbidity index at positivity, numeric
							 ]
@info "Constantes loaded"
