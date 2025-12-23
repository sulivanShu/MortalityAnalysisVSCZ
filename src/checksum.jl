@info "Verifying checksum"

# Constantes
# INFO: CZECH_DATA_CSV already defined in src/constants.jl
const CZECH_DATA_CSV_B3SUM = "28a58ec2c8360cdf4ae599cc59bd6e8c678aa7ccbab7debc5d3c3faf645dfcd6"

# Functions
function HashCheck(file::AbstractString, b3sum::AbstractString)
	hasher = Blake3Ctx()
	update!(hasher, read(file))
	hash = digest(hasher)
	computed = bytes2hex(hash)
	if computed != b3sum
		error("The hash of file $(file) does not match the expected value.")
	end
	hash_int = reinterpret(UInt64, hash[1:8])[1]
	return hash_int
end

# Processing
hash_int = HashCheck(CZECH_DATA_CSV, CZECH_DATA_CSV_B3SUM)

@info "Checksum verified"
