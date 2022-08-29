using Unzip
using Unzip: Rows
using Documenter: Documenter
using Test: @inferred, @test, @testset, @test_throws
using OffsetArrays: OffsetVector

stable(x) = (x, x + 0.0, x, x + 0.0, x, x + 0.0)
unstable(x) =
    if x == 2
        (x, x + 0.0, x, x + 0.0)
    else
        (x, x + 0.0)
    end

unstable_missing(x) =
    if x == 2
        (x, x + 0.0, missing, missing)
    else
        (missing, missing)
    end

@testset "Rows" begin
    rows = Rows([1, 2], ['a', 'b'])
    @test_throws DimensionMismatch("[1, 2] does not have model axes (Base.OneTo(1),)") Rows(
        [1],
        [1, 2],
    )
    @test_throws MethodError similar(rows, nothing)
    @test Rows([1, 2], ['a', 'b'])[1] == (1, 'a')
    @test length(similar(rows, 0)) == 0
    @test size(similar(rows, 2, 3)) == (2, 3)
    rows = Rows([1, 2], ['a', 'b'])
end

@testset "Unzip" begin
    @test unzip([()]) == ()
    @test unzip([(1,)]) == ([1],)
    @test unzip([(1, 1)]) == ([1], [1])
    @test unzip([(1, 1, 1)]) == ([1], [1], [1])
    @test unzip([(1, 1, 1, 1)]) == ([1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1)]) == ([1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1)]) == ([1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1)]) == ([1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1)]) == ([1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1])
    @test unzip([(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1)]) ==
          ([1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1], [1])

    @test unzip([(1,), (2,), (3,), (4,)]) == ([1, 2, 3, 4],)
    @test (@inferred unzip(Iterators.map(stable, 1:4))) == (
        [1, 2, 3, 4],
        [1.0, 2.0, 3.0, 4.0],
        [1, 2, 3, 4],
        [1.0, 2.0, 3.0, 4.0],
        [1, 2, 3, 4],
        [1.0, 2.0, 3.0, 4.0],
    )
    @test isequal(
        unzip(Iterators.map(unstable, 1:3)),
        (
            [1, 2, 3],
            [1.0, 2.0, 3.0],
            Union{Missing, Int64}[missing, 2, missing],
            Union{Missing, Float64}[missing, 2.0, missing],
        ),
    )
    @test isequal(
        unzip(Iterators.map(unstable_missing, 1:3)),
        (
            [missing, 2, missing],
            [missing, 2.0, missing],
            [missing, missing, missing],
            [missing, missing, missing],
        ),
    )
    @test isequal(
        unzip(Iterators.filter(row -> true, Iterators.map(unstable, 1:3))),
        (
            [1, 2, 3],
            [1.0, 2.0, 3.0],
            Union{Missing, Int64}[missing, 2, missing],
            Union{Missing, Float64}[missing, 2.0, missing],
        ),
    )
    @test isequal(
        unzip(Iterators.filter(row -> true, Iterators.map(unstable_missing, 1:3))),
        (
            [missing, 2, missing],
            [missing, 2.0, missing],
            [missing, missing, missing],
            [missing, missing, missing],
        ),
    )
    @test_throws ArgumentError(
        "Cannot guess the fieldtypes from eltype Union{} and the iterator is empty",
    ) unzip(Iterators.filter(row -> false, Iterators.map(unstable, 1:3)))
    @test_throws ArgumentError(
        "Cannot guess the fieldtypes from eltype Tuple{Int64, Float64, Vararg{Real}} and the iterator is empty",
    ) unzip(Iterators.map(unstable, 1:0))
    @test unzip(x for x in [(1, 2), ("a", "b")]) == (Any[1, "a"], Any[2, "b"])
    @test unzip(OffsetVector([(i, i + 1) for i in 1:5], -1)) == (OffsetVector([1, 2, 3, 4, 5], -1), OffsetVector([2, 3, 4, 5, 6], -1))
end

if v"1.7" <= VERSION < v"1.8"
    Documenter.doctest(Unzip)
end
