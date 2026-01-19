@info "Loading constantes"

const CZECH_DATA_CSV = "data/exp_raw/Otevrena-data-NR-26-30-COVID-19-prehled-populace-2024-01.csv"
const AVAILABLE = Date(-10000, 01, 01)
const UNAVAILABLE = Date(10000, 01, 01)
const VERY_FIRST_ENTRY = Date(2020, 12, 21)
const FIRST_LAST_WEEK = VERY_FIRST_ENTRY + Week(53)
const UNVACCINATED = Date(10000, 01, 01)
const STILL_ALIVE = Date(10000, 01, 01)
const FIRST_MONDAY = Date(2020, 12, 21)
const LAST_MONDAY = Date(2024, 06, 24)
global const ALL_MONDAYS = collect(FIRST_MONDAY:Week(1):LAST_MONDAY)
global const ENTRIES = first(ALL_MONDAYS, length(ALL_MONDAYS)-53)
const YEAR_WEEK = ["dose1_week", "death_week"]
const YEAR_YEAR = ["_5_years_cat_of_birth"]

@info "Constantes loaded"
