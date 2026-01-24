if nthreads() == 1
    @warn "This script requires multiple threads."
		@warn "Stop the script RIGHT NOW with Ctrl-C and rerun it with the --threads=auto` option, unless you accept the program run on a single core and be extremely slow."
end
