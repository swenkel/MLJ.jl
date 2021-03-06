# this file defines *and* loads one module

#> This interface for the DecisionTree package is annotated so that it
#> may serve as a template for other interfaces introducing new
#> Supervised subtypes. The annotations, which begin with "#>", should
#> be removed (but copy this file first!). See also the model
#> interface specification at "doc/adding_new_models.md". The
#> assumption is that this interface is to be lazy loaded and live in
#> "src/interfaces/".

#> model API implementation code goes in a module, whose name is the
#> package name with trailing underscore "_":
module DecisionTree_

#> export the new models you're going to define (and nothing else):
export DecisionTreeClassifier, DecisionTreeRegressor

import MLJBase

#> for all classifiers:
using CategoricalArrays

#> import package:
import DecisionTree

DecisionTreeClassifierFitResultType{T} =
    Tuple{Union{DecisionTree.Node{Float64,T}, DecisionTree.Leaf{T}}, MLJBase.CategoricalDecoder{UInt32,T,1,UInt32}}

"""
    DecisionTreeClassifer(; kwargs...)

[https://github.com/bensadeghi/DecisionTree.jl/blob/master/README.md](https://github.com/bensadeghi/DecisionTree.jl/blob/master/README.md)

"""
mutable struct DecisionTreeClassifier{T} <: MLJBase.Deterministic{DecisionTreeClassifierFitResultType{T}}
    target_type::Type{T}  # target is CategoricalArray{target_type}
    pruning_purity::Float64
    max_depth::Int
    min_samples_leaf::Int
    min_samples_split::Int
    min_purity_increase::Float64
    n_subfeatures::Float64
    display_depth::Int
    post_prune::Bool
    merge_purity_threshold::Float64
end

# constructor:
#> all arguments are kwargs with a default value
function DecisionTreeClassifier(
    ; target_type=Int
    , pruning_purity=1.0
    , max_depth=-1
    , min_samples_leaf=1
    , min_samples_split=2
    , min_purity_increase=0.0
    , n_subfeatures=0
    , display_depth=5
    , post_prune=false
    , merge_purity_threshold=0.9)

    model = DecisionTreeClassifier{target_type}(
        target_type
        , pruning_purity
        , max_depth
        , min_samples_leaf
        , min_samples_split
        , min_purity_increase
        , n_subfeatures
        , display_depth
        , post_prune
        , merge_purity_threshold)

    message = MLJBase.clean!(model)       #> future proof by including these
    isempty(message) || @warn message #> two lines even if no clean! defined below

    return model
end

#> The following optional method (the fallback does nothing, returns
#> empty warning) is called by the constructor above but also by the
#> fit methods below:
function MLJBase.clean!(model::DecisionTreeClassifier)
    warning = ""
    if  model.pruning_purity > 1
        warning *= "Need pruning_purity < 1. Resetting pruning_purity=1.0.\n"
        model.pruning_purity = 1.0
    end
    if model.min_samples_split < 2
        warning *= "Need min_samples_split < 2. Resetting min_samples_slit=2.\n"
        model.min_samples_split = 2
    end
    return warning
end

#> A required `fit` method returns `fitresult, cache, report`. (Return
#> `cache=nothing` unless you are overloading `update`)
function MLJBase.fit(model::DecisionTreeClassifier{T2}
             , verbosity::Int   #> must be here (and typed!!) even if not used (as here)
             , X
             , y::CategoricalVector{T}) where {T,T2}

    T == T2 || throw(ErrorException("Type, $T, of target incompatible "*
                                    "with type, $T2, of $model."))

    Xmatrix = MLJBase.matrix(X)
    
    decoder = MLJBase.CategoricalDecoder(y)
    y_plain = MLJBase.transform(decoder, y)

    tree = DecisionTree.build_tree(y_plain
                                   , Xmatrix
                                   , model.n_subfeatures
                                   , model.max_depth
                                   , model.min_samples_leaf
                                   , model.min_samples_split
                                   , model.min_purity_increase)
    if model.post_prune
        tree = DecisionTree.prune_tree(tree, model.merge_purity_threshold)
    end

    verbosity < 3 || DecisionTree.print_tree(tree, model.display_depth)

    fitresult = (tree, decoder)

    #> return package-specific statistics (eg, feature rankings,
    #> internal estimates of generalization error) in `report`, which
    #> should be `nothing` or a dictionary keyed on symbols.

    cache = nothing
    report = nothing

    return fitresult, cache, report

end

function MLJBase.predict(model::DecisionTreeClassifier{T}
                     , fitresult
                     , Xnew) where T
    Xmatrix = MLJBase.matrix(Xnew)
    tree, decoder = fitresult
    return MLJBase.inverse_transform(decoder, DecisionTree.apply_tree(tree, Xmatrix))
end

# metadata:
MLJBase.load_path(::Type{<:DecisionTreeClassifier}) = "MLJ.DecisionTreeClassifier" # lazy-loaded from MLJ
MLJBase.package_name(::Type{<:DecisionTreeClassifier}) = "DecisionTree"
MLJBase.package_uuid(::Type{<:DecisionTreeClassifier}) = "7806a523-6efd-50cb-b5f6-3fa6f1930dbb"
MLJBase.package_url(::Type{<:DecisionTreeClassifier}) = "https://github.com/bensadeghi/DecisionTree.jl"
MLJBase.is_pure_julia(::Type{<:DecisionTreeClassifier}) = :yes
MLJBase.input_kinds(::Type{<:DecisionTreeClassifier}) = [:continuous, ]
MLJBase.output_kind(::Type{<:DecisionTreeClassifier}) = :multiclass
MLJBase.output_quantity(::Type{<:DecisionTreeClassifier}) = :univariate

end # module


## EXPOSE THE INTERFACE

using .DecisionTree_
export DecisionTreeClassifier
