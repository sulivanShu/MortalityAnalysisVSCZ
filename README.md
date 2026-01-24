# MortalityAnalysisVSCZ

This code base is using the [Julia Language](https://julialang.org/) and
[DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/)
to make a reproducible scientific project named
> MortalityAnalysisVSCZ

It is authored by sulivanShu.

To (locally) reproduce this project, do the following:

0. Clone this depot.
1. from the depot directory, run :
 1. `julia --project=. --threads=auto scripts/main.jl` (so your seed is the `0` default value), or
 2. `julia --project=. --threads=auto scripts/main.jl --seed 1234`, where `1234` is the seed of your choice, or
 3. open a Julia console with `julia`, and run `include("scripts/main.jl")`, or
 4. open an IDE, open `scripts/main.jl`, and run the file chunk by chunk or browse other source files to run other chunks.
