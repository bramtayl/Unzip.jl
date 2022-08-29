module Unzip

using Base:
    _collect,
    collect_to_with_first!,
    @default_eltype,
    grow_to!,
    EltypeUnknown,
    HasEltype,
    HasLength,
    HasShape,
    IteratorEltype,
    IteratorSize,
    isabstracttype,
    isvatuple,
    OneTo,
    push_widen,
    @propagate_inbounds,
    @pure,
    setindex_widen_up_to,
    _similar_for,
    _similar_shape,
    SizeUnknown,
    tail,
    vect

include("get_val_fieldtypes.jl")

struct Rows{Row, Dimensions, ModelColumn, Columns} <: AbstractArray{Row, Dimensions}
    model_column::ModelColumn
    columns::Columns
end

function check_axes(column, model_axes)
    column_axes = axes(column)
    if column_axes != model_axes
        throw(DimensionMismatch("$column does not have model axes $model_axes"))
    end
    nothing
end

@inline @propagate_inbounds function Rows(
    first_column,
    other_columns...;
    model_column = similar(first_column, Nothing),
)
    model_axes = axes(model_column)
    columns = (first_column, other_columns...)
    @boundscheck map(let model_axes = model_axes
        column -> check_axes(column, model_axes)
    end, columns)
    Rows{
        Tuple{map(eltype, columns)...},
        length(model_axes),
        typeof(model_column),
        typeof(columns),
    }(
        model_column,
        columns,
    )
end

# must specify a model column if no other columns
function Rows(; model_column)
    Rows{Tuple{}, ndims(model_column), typeof(model_column), Tuple{}}(model_column, ())
end

function Base.axes(rows::Rows)
    axes(rows.model_column)
end
function Base.size(rows::Rows)
    size(rows.model_column)
end

@inline @propagate_inbounds function Base.getindex(rows::Rows, index...)
    map(let index = index
        @inline @propagate_inbounds function (column)
            column[index...]
        end
    end, rows.columns)
end

@inline @propagate_inbounds function Base.setindex!(rows::Rows, row, index...)
    map(let index = index
        @inline @propagate_inbounds function (column, value)
            column[index...] = value
        end
    end, rows.columns, row)
    nothing
end

function default_similar(rows, ::Type{ARow}, dimensions) where {ARow}
    @inbounds Rows(
        map(
            let model = rows.model_column, dimensions = dimensions
                function (::Val{Value},) where {Value}
                    similar(model, Value, dimensions)
                end
            end,
            get_val_fieldtypes(ARow),
        )...;
        model_column = similar(rows.model_column, Nothing, dimensions),
    )
end

function Base.similar(rows::Rows, ::Type{ARow}, dimensions) where {ARow}
    default_similar(rows, ARow, dimensions)
end

# disambiguation methods
const SomeOf{AType} = Tuple{AType, Vararg{AType}} where {AType}

function Base.similar(
    rows::Rows,
    ::Type{ARow},
    dimensions::Union{Integer, AbstractUnitRange},
) where {ARow}
    default_similar(rows, ARow, dimensions)
end

function Base.similar(rows::Rows, ::Type{ARow}, dimensions::SomeOf{Int64}) where {ARow}
    default_similar(rows, ARow, dimensions)
end

function Base.similar(
    rows::Rows,
    ::Type{ARow},
    dimensions::SomeOf{Union{Integer, OneTo}},
) where {ARow}
    default_similar(rows, ARow, dimensions)
end
function Base.similar(
    rows::Rows,
    ::Type{ARow},
    dimensions::SomeOf{Union{Integer, AbstractUnitRange}},
) where {ARow}
    default_similar(rows, ARow, dimensions)
end

function zip_missing(::Tuple{}, ::Tuple{})
    ()
end
function zip_missing(::Tuple{}, longer)
    map(function (second_one)
        (missing, second_one)
    end, longer)
end
function zip_missing(longer, ::Tuple{})
    map(function (first_one)
        (first_one, missing)
    end, longer)
end
function zip_missing(tuple1, tuple2)
    (first(tuple1), first(tuple2)), zip_missing(tail(tuple1), tail(tuple2))...
end

function widen_column(
    _,
    next_index,
    column::Array{OldItem},
    item::Item,
) where {OldItem, Item <: OldItem}
    @inbounds column[next_index] = item
    column
end
function widen_column(_, next_index, column::Array, item)
    setindex_widen_up_to(column, item, next_index)
end
function widen_column(rows, next_index, ::Missing, item::Item) where {Item}
    new_column = similar(rows.model_column, Union{Missing, Item})
    @inbounds new_column[next_index] = item
    new_column
end
function widen_column(rows, __, ::Missing, ::Missing)
    similar(rows.model_column, Missing)
end

function Base.setindex_widen_up_to(rows::Rows, row, next_index)
    @inbounds Rows(
        map(
            let rows = rows, next_index = next_index
                function (column_item,)
                    widen_column(rows, next_index, column_item...)
                end
            end,
            zip_missing(rows.columns, row),
        )...,
    )
end

function push_widen_column(
    _,
    column::Array{OldItem},
    item::Item,
) where {OldItem, Item <: OldItem}
    push!(column, item)
    column
end
function push_widen_column(_, column::Array, item)
    push_widen(column, item)
end
function push_widen_column(rows, ::Missing, item::Item) where {Item}
    new_index = length(rows) + 1
    new_column = Array{Union{Missing, Item}}(missing, new_index)
    @inbounds new_column[new_index] = item
    new_column
end
function push_widen_column(rows, ::Missing, ::Missing)
    Array{Missing}(missing, length(rows) + 1)
end

function Base.push_widen(rows::Rows, row)
    model_column = rows.model_column
    # do this before we push into the model column
    columns = map(let rows = rows
        function (column_item,)
            push_widen_column(rows, column_item...)
        end
    end, zip_missing(rows.columns, row))
    model_column = rows.model_column
    push!(model_column, nothing)
    @inbounds Rows(columns...; model_column = model_column)
end

"""
    unzip(rows)

Collect into columns.

Will be most performant if each row is a tuple.
If each row is not a tuple, consider using `unzip(Iterators.map(Tuple, rows))`.

```jldoctest
julia> using Unzip

julia> using Test: @inferred

julia> stable(x) = (x, x + 0.0, x, x + 0.0, x, x + 0.0);

julia> @inferred unzip(Iterators.map(stable, 1:4))
([1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0], [1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0], [1, 2, 3, 4], [1.0, 2.0, 3.0, 4.0])

julia> unstable(x) =
           if x == 2
               (x, x + 0.0, x, x + 0.0)
           else
               (x, x + 0.0)
           end;

julia> unzip(Iterators.map(unstable, 1:3))
([1, 2, 3], [1.0, 2.0, 3.0], Union{Missing, Int64}[missing, 2, missing], Union{Missing, Float64}[missing, 2.0, missing])
```
"""
function unzip(row_iterator)
    (
        collect_rows(
            row_iterator,
            IteratorEltype(row_iterator),
            IteratorSize(row_iterator),
        )::Rows
    ).columns
end

# add can guess typetypes to dispatch
function collect_rows(row_iterator, iterator_eltype::EltypeUnknown, iterator_size)
    Item = @default_eltype(row_iterator)
    collect_rows(
        row_iterator,
        iterator_eltype,
        iterator_size,
        Item,
        can_guess_fieldtypes(Item),
    )
end

function collect_rows(row_iterator, iterator_eltype::HasEltype, iterator_size)
    Item = eltype(row_iterator)
    collect_rows(
        row_iterator,
        iterator_eltype,
        iterator_size,
        Item,
        can_guess_fieldtypes(Item),
    )
end

# we can fall back to base if we can guess the fieldtypes
function collect_rows(row_iterator, iterator_eltype, iterator_size, _, ::Val{true})
    # don't want to allocate Nothing[]
    # invalid model column, but that's ok, because this dummy rows won't get used
    _collect(Rows(; model_column = 1:0), row_iterator, iterator_eltype, iterator_size)
end

# otherwise, we need to make sure that the eltype never gets used
function eltype_error(Item)
    throw(
        ArgumentError(
            "Cannot guess the fieldtypes from eltype $Item and the iterator is empty",
        ),
    )
end

function collect_rows(row_iterator, _, iterator_size::SizeUnknown, Item, ::Val{false})
    row_state = iterate(row_iterator)
    if row_state === nothing
        eltype_error(Item)
    else
        row, state = row_state
        grow_to!(
            (@inbounds Rows(map(vect, row)...; model_column = [nothing])),
            row_iterator,
            state,
        )
    end
end

function collect_rows(
    row_iterator,
    _,
    iterator_size::Union{HasLength, HasShape},
    Item,
    ::Val{false},
)
    shape = _similar_shape(row_iterator, iterator_size)
    row_state = iterate(row_iterator)
    if row_state === nothing
        eltype_error(Item)
    else
        row, state = row_state
        collect_to_with_first!(
            (@inbounds Rows(
                map(
                    let iterator_size = iterator_size, shape = shape
                        function (item::Item) where {Item}
                            _similar_for(1:0, Item, row_iterator, iterator_size, shape)
                        end
                    end,
                    row,
                )...;
                model_column = _similar_for(
                    1:0,
                    Nothing,
                    row_iterator,
                    iterator_size,
                    shape,
                ),
            )),
            row,
            row_iterator,
            state,
        )
    end
end

export unzip

end
