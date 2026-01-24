settings = ArgParseSettings()
@add_arg_table settings begin
    "--seed"
        help = "choose a random integer"
				arg_type = Union{Int, Nothing}
        default = 0
end
parsed_args = parse_args(settings)
my_seed = parsed_args["seed"]
Random.seed!(my_seed)
@info "Your seed is: $my_seed."
