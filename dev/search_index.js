var documenterSearchIndex = {"docs":
[{"location":"#Interface","page":"Interface","title":"Interface","text":"","category":"section"},{"location":"","page":"Interface","title":"Interface","text":"Modules = [Unzip]","category":"page"},{"location":"","page":"Interface","title":"Interface","text":"Modules = [Unzip]","category":"page"},{"location":"#Unzip.unzip-Tuple{Any}","page":"Interface","title":"Unzip.unzip","text":"unzip(rows)\n\nCollect into columns.\n\njulia> using Unzip\n\n\njulia> using Base: Generator\n\n\njulia> using Test: @inferred\n\n\njulia> stable(x) = (x, x + 0.0, x, x + 0.0, x, x + 0.0);\n\n\njulia> @inferred unzip(Generator(stable, 1:4))\n([1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0], [1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0], [1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0])\n\njulia> unstable(x) =\n           if x == 2\n               (x, x + 0.0, x, x + 0.0)\n           else\n               (x, x + 0.0)\n           end;\n\n\njulia> unzip(Generator(unstable, 1:3))\n([1, 2, 3], [1.0, 2.0, 3.0], Union{Missing, Int64}[missing, 2, missing], Union{Missing, Float64}[missing, 2.0, missing])\n\njulia> unzip(Iterators.filter(row -> true, Generator(unstable, 1:3)))\n([1, 2, 3], [1.0, 2.0, 3.0], Union{Missing, Int64}[missing, 2, missing], Union{Missing, Float64}[missing, 2.0, missing])\n\njulia> unzip(Iterators.filter(row -> false, Generator(unstable, 1:4)))\n()\n\njulia> unzip(x for x in [(1, 2), (\"a\", \"b\")]) \n(Any[1, \"a\"], Any[2, \"b\"])\n\njulia> unzip([(a=1, b=2), (a=\"a\", b=\"b\")])\n(Any[1, \"a\"], Any[2, \"b\"])\n\n\n\n\n\n","category":"method"}]
}