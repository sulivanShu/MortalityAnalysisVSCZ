@info "Download data"

# Constantes
# INFO: CZECH_DATA_CSV already defined in src/constants.jl
const CZECH_DATA_CSV_URL = "https://data.mzcr.cz/data/distribuce/402/Otevrena-data-NR-26-30-COVID-19-prehled-populace-2024-01.csv"

# Functions
function DownloadCheck(file::AbstractString, URL::AbstractString)
	if !isfile(file)
		@info "File missing, downloading..."
		Downloads.download(URL, file)
		@info "Download completed"
	else
		@info "File already present"
	end
end

# Processing
DownloadCheck(CZECH_DATA_CSV, CZECH_DATA_CSV_URL)

@info "Download completed"
