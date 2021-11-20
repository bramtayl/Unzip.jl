using Unzip: Unzip, unzip
using Documenter: doctest
using Test: @test

@test unzip([(1,), (2,), (3,), (4,)]) == ([1, 2, 3, 4],)

doctest(Unzip)
