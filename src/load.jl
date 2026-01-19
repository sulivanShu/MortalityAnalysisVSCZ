@info "Loading data"

# Constants
# INFO: CZECH_DATA_CSV already defined in src/constantes.jl
const MY_CZECH_HEADER = [
    "Infekce",
    "Pohlavi",
    "RokNarozeni",
    "Datum_Prvni_davka",
    "DatumUmrtiLPZ",
    "DCCI",
]

# Functions
function load_csv_data(file::AbstractString, select_cols)
    return CSV.File(file; select = select_cols) |> DataFrame
end

# Processing
dfs = load_csv_data(CZECH_DATA_CSV, MY_CZECH_HEADER)

@info "Data loaded"
