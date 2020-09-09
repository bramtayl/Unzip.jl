using Unzip
using Documenter: deploydocs, makedocs

makedocs(sitename = "Unzip.jl", modules = [Unzip], doctest = false)
deploydocs(repo = "github.com/bramtayl/Unzip.jl.git")
