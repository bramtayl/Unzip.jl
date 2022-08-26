using Unzip
using Documenter: Documenter
using Test: @inferred, @test, @testset
using OffsetArrays: OffsetVector

stable(x) = (x, x + 0.0, x, x + 0.0, x, x + 0.0)
unstable(x) =
    if x == 2
        (x, x + 0.0, x, x + 0.0)
    else
        (x, x + 0.0)
    end

@testset begin
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
        unzip(Iterators.filter(row -> true, Iterators.map(unstable, 1:3))),
        (
            [1, 2, 3],
            [1.0, 2.0, 3.0],
            Union{Missing, Int64}[missing, 2, missing],
            Union{Missing, Float64}[missing, 2.0, missing],
        ),
    )
    @test unzip(Iterators.filter(row -> false, Iterators.map(unstable, 1:4))) == ()
    @test unzip(x for x in [(1, 2), ("a", "b")]) == (Any[1, "a"], Any[2, "b"])
    @test unzip([(a = 1, b = 2), (a = "a", b = "b")]) == (Any[1, "a"], Any[2, "b"])
    @test unzip(OffsetVector([(i, i + 1) for i in 1:5], -1)) == (OffsetVector([1, 2, 3, 4, 5], -1), OffsetVector([2, 3, 4, 5, 6], -1))
end

if v"1.7" <= VERSION < v"1.8"
    Documenter.doctest(Unzip)
end
