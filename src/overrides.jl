##### OVERRIDES FOR EFFICIENCY / CORRECTNESS

function add_vertices!(g::AbstractSimpleWeightedGraph, n::Integer)
    T = eltype(g)
    U = weighttype(g)
    (nv(g) + one(T) <= nv(g)) && return false       # test for overflow
    emptycols = spzeros(U, nv(g) + n, n)
    g.weights = hcat(g.weights, emptycols[1:nv(g), :])
    g.weights = vcat(g.weights, emptycols')
    return true
end

function adjacency_matrix(g::AbstractSimpleWeightedGraph, T::DataType=Int; dir::Symbol=:out)
    if dir == :out
        return T.(spones(g.weights))'
    else
        return T.(spones(g.weights))
    end
end

function pagerank(g::SimpleWeightedDiGraph, α=0.85, n=100::Integer, ϵ=1.0e-6)
    A = weights(g)
    S = vec(sum(A, 1))
    S = 1 ./ S
    S[find(S .== Inf)] = 0.0
    M = A'  # need a separate line due to bug #17456 in julia
    # scaling the adjmat to stochastic adjacency matrix
    M = (Diagonal(S) * M)'
    N = Int(nv(g))
    # solution vector
    x = fill(1.0 / N, N)
    # personalization vector
    p = fill(1.0 / N, N)
    # temporary to hold the results of SpMV
    y = zeros(Float64, N)
    # adjustment for leaf nodes in digraph
    dangling_weights = p
    is_dangling = find(S .== 0)
    # save some flops by precomputing this
    pscaled = (1 .- α) .* p
    for _ in 1:n
        xlast = x
        # in place SpMV to conserve memory
        A_mul_B!(y, M, x)
        # using broadcast to avoid temporaries
        x = α .* (y .+ sum(x[is_dangling]) .* dangling_weights) .+ pscaled
        # l1 change in solution convergence criterion
        err = sum(abs, (x .- xlast))
        if (err < N * ϵ)
            return x
        end
    end
    error("Pagerank did not converge after $n iterations.")
end

savegraph(fn::AbstractString, g::AbstractSimpleWeightedGraph, gname::AbstractString="graph"; compress=true) =
    savegraph(fn, g, gname, SWGFormat(), compress=compress)

savegraph(fn::AbstractString, d::Dict{T, U}; compress=true) where T <: AbstractString where U <: AbstractSimpleWeightedGraph = 
    savegraph(fn, d, SWGFormat(), compress=compress)