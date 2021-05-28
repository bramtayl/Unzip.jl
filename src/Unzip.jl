module Unzip

import Base:
    axes,
    _collect,
    empty,
    getindex,
    push!,
    push_widen,
    setindex!,
    setindex_widen_up_to,
    similar,
    size
using Base:
    EltypeUnknown,
    HasEltype,
    HasLength,
    isvatuple,
    IteratorEltype,
    IteratorSize,
    @propagate_inbounds,
    @pure,
    SizeUnknown,
    tail

@inline function all_unrolled(call)
    true
end
@inline function all_unrolled(call, item, rest...)
    if call(item)
        all_unrolled(call, rest...)
    else
        false
    end
end

@inline same_axes() = true
function same_axes(call, first_column, rest...)
    all_unrolled(let first_axes = axes(first_column)
        column -> axes(column) == first_axes
    end, rest...)
end

struct Rows{Row, Dimensions, Columns} <: AbstractArray{Row, Dimensions}
    columns::Columns
end

@propagate_inbounds function Rows{Row, Dimension}(
    columns::Columns,
) where {Row, Dimension, Columns}
    @boundscheck if !same_axes(columns...)
        throw(DimensionMismatch("All arguments to `Rows` must have the same axes"))
    end
    Rows{Row, Dimension, Columns}(columns)
end

model_column(columns) = first(columns)
model_column(::Tuple{}) = 1:0
model_column(rows::Rows) = model_column(rows.columns)

@propagate_inbounds function Rows(columns)
    Rows{Tuple{map(eltype, columns)...}, ndims(model_column(columns))}(columns)
end

axes(rows::Rows, dimensions...) = axes(model_column(rows), dimensions...)
size(rows::Rows, dimensions...) = size(model_column(rows), dimensions...)

@propagate_inbounds function getindex(rows::Rows, an_index...)
    map(let an_index = an_index
        @propagate_inbounds function (column)
            column[an_index...]
        end
    end, rows.columns)
end

@propagate_inbounds function setindex!(rows::Rows, row, an_index...)
    map(let an_index = an_index
        @propagate_inbounds function (column, value)
            column[an_index...] = value
        end
    end, rows.columns, row)
    nothing
end

function push!(rows::Rows, row)
    map(push!, rows.columns, row)
    nothing
end

# can we do any better?
@pure function can_guess_column_types(_)
    false
end
@pure function can_guess_column_types(row_type::DataType)
    !(row_type.abstract || (row_type.name == Tuple.name && isvatuple(row_type)))
end
@pure function val_fieldtypes(row_type)
    if can_guess_column_types(row_type)
        map(Val, (row_type.types...,))
    else
        ()
    end
end

function similar(rows::Rows, ::Type{ARow}, dimensions::Dims) where {ARow}
    @inbounds Rows(map(
        let model = model_column(rows), dimensions = dimensions
            function (::Val{Value},) where {Value}
                similar(model, Value, dimensions)
            end
        end,
        val_fieldtypes(ARow),
    ))
end

function empty(column::Rows{OldRow}, ::Type{NewRow} = OldRow) where {OldRow, NewRow}
    similar(column, NewRow)
end

function widen_column(
    ::HasLength,
    new_length,
    an_index,
    column::Array{Element},
    item::Item,
) where {Element, Item <: Element}
    @inbounds column[an_index] = item
    column
end
function widen_column(::HasLength, new_length, an_index, column::Array, item)
    setindex_widen_up_to(column, item, an_index)
end

function widen_column(
    ::SizeUnknown,
    new_length,
    an_index,
    column::Array{Element},
    item::Item,
) where {Element, Item <: Element}
    push!(column, item)
    column
end
function widen_column(::SizeUnknown, new_length, an_index, column::Array, item)
    push_widen(column, item)
end

function widen_column(
    iterator_size,
    new_length,
    an_index,
    ::Missing,
    item::Item,
) where {Item}
    new_column = Array{Union{Missing, Item}}(missing, new_length)
    @inbounds new_column[an_index] = item
    new_column
end
function widen_column(iterator_size, new_length, an_index, ::Missing, ::Missing)
    Array{Missing}(missing, new_length)
end

get_new_length(::SizeUnknown, rows, an_index) = an_index
get_new_length(::HasLength, rows, an_index) = length(rows)

zip_missing(::Tuple{}, ::Tuple{}) = ()
zip_missing(::Tuple{}, longer) = map(second_one -> (missing, second_one), longer)
zip_missing(longer, ::Tuple{}) = map(first_one -> (first_one, missing), longer)
function zip_missing(tuple1, tuple2)
    (first(tuple1), first(tuple2)), zip_missing(tail(tuple1), tail(tuple2))...
end

function widen_columns(iterator_size, rows, row, an_index = length(rows) + 1)
    columns = rows.columns
    @inbounds Rows(map(
        let iterator_size = iterator_size,
            new_length = get_new_length(iterator_size, rows, an_index),
            an_index = an_index

            function (column_item,)
                widen_column(iterator_size, new_length, an_index, column_item...)
            end
        end,
        zip_missing(rows.columns, row),
    ))
end

push_widen(rows::Rows, row) = widen_columns(SizeUnknown(), rows, row)

function setindex_widen_up_to(rows::Rows, row, an_index)
    widen_columns(HasLength(), rows, row, an_index)
end

"""
    unzip(rows)

Collect into columns.

```jldoctest
julia> using Unzip


julia> using Base: Generator


julia> using Test: @inferred


julia> stable(x) = (x, x + 0.0, x, x + 0.0, x, x + 0.0);


julia> @inferred unzip(Generator(stable, 1:4))
([1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0], [1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0], [1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0])

julia> unstable(x) =
           if x == 2
               (x, x + 0.0, x, x + 0.0)
           else
               (x, x + 0.0)
           end;


julia> unzip(Generator(unstable, 1:3))
([1, 2, 3], [1.0, 2.0, 3.0], Union{Missing, Int64}[missing, 2, missing], Union{Missing, Float64}[missing, 2.0, missing])

julia> unzip(Iterators.filter(row -> true, Generator(unstable, 1:3)))
([1, 2, 3], [1.0, 2.0, 3.0], Union{Missing, Int64}[missing, 2, missing], Union{Missing, Float64}[missing, 2.0, missing])

julia> unzip(Iterators.filter(row -> false, Generator(unstable, 1:4)))
()

julia> unzip(x for x in [(1, 2), ("a", "b")]) 
(Any[1, "a"], Any[2, "b"])

julia> unzip([(a=1, b=2), (a="a", b="b")])
(Any[1, "a"], Any[2, "b"])
```
"""
function unzip(rows)
    iterator_eltype = IteratorEltype(rows)
    _collect(
        (@inbounds Rows(())), 
        rows, 
        # if we can't guess the column types, ignore the eltype
        if iterator_eltype isa HasEltype && !can_guess_column_types(eltype(rows))
            EltypeUnknown()
        else
            iterator_eltype
        end, 
        IteratorSize(rows)
    ).columns
end

export unzip

end
