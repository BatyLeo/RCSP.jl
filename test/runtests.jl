using ConstrainedShortestPaths
using Test

using Cbc
using Graphs
using Random
using SparseArrays
using UnicodePlots
using JuMP
using GLPK

const SHOW_PLOTS = false
const vehicle_cost = 0.0
const eps = 1e-10

include("utils.jl")

@testset verbose=true "RCSP.jl" begin
    @testset "PiecewiseLinear" begin
        @info "Running piecewise linear tests..."
        include("piecewise_linear.jl")
    end

    @testset "Examples" verbose=true begin
        @testset "Basic Shortest Path" begin
            @info "Running basic shortest path tests..."
            include("examples/basic_shortest_path.jl")
        end

        @testset "Resource Shortest Path" begin
            @info "Running resource constrained shortest path tests..."
            include("examples/resource_shortest_path.jl")
        end

        @testset "Stochastic routing" begin
            @info "Running stochastic routing tests..."
            include("examples/stochastic_routing.jl")
        end
    end
end
