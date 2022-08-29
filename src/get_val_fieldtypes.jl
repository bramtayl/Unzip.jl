macro fieldtypes_method(item_count)
    item_symbols = map(function (index)
        Symbol(string("Item", index))
    end, 1:item_count)
    esc(
        Expr(
            :function,
            Expr(
                :where,
                Expr(
                    :call,
                    :get_val_fieldtypes,
                    Expr(:(::), Expr(:curly, Type, Expr(:curly, Tuple, item_symbols...))),
                ),
                item_symbols...,
            ),
            Expr(
                :block,
                __source__,
                Expr(
                    :tuple,
                    map(function (item_symbol)
                        Expr(:call, Expr(:curly, Val, item_symbol))
                    end, item_symbols)...,
                ),
            ),
        ),
    )
end

@fieldtypes_method(0)
@fieldtypes_method(1)
@fieldtypes_method(2)
@fieldtypes_method(3)
@fieldtypes_method(4)
@fieldtypes_method(5)
@fieldtypes_method(6)
@fieldtypes_method(7)
@fieldtypes_method(8)
@fieldtypes_method(9)
@fieldtypes_method(10)
@fieldtypes_method(11)
@fieldtypes_method(12)
@fieldtypes_method(13)
@fieldtypes_method(14)
@fieldtypes_method(15)
@fieldtypes_method(16)

macro guess_method(item_count)
    esc(
        Expr(
            :function,
            Expr(
                :call,
                :can_guess_fieldtypes,
                Expr(
                    :(::),
                    Expr(:curly, Type, Expr(:<:, Expr(:curly, NTuple, item_count, Any))),
                ),
            ),
            Expr(:block, __source__, Val{true}()),
        ),
    )
end

@guess_method(0)
@guess_method(1)
@guess_method(2)
@guess_method(3)
@guess_method(4)
@guess_method(5)
@guess_method(6)
@guess_method(7)
@guess_method(8)
@guess_method(9)
@guess_method(10)
@guess_method(11)
@guess_method(12)
@guess_method(13)
@guess_method(14)
@guess_method(15)
@guess_method(16)

function can_guess_fieldtypes(_)
    Val{false}()
end
# have to be explicit cause this is the subtype of everything
function can_guess_fieldtypes(::Type{Union{}})
    Val{false}()
end
