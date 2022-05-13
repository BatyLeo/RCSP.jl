using ConstrainedShortestPaths
using Graphs
using SparseArrays

@testset "Path digraph" begin
    m = 5
    nb_vertices = 10

    graph = path_digraph(nb_vertices)
    nb_edges = ne(graph)
    I = [src(e) for e in edges(graph)]
    J = [dst(e) for e in edges(graph)]

    @testset "No delays" begin
        slacks = [0.0 for _ in 1:nb_edges]
        slacks[end] = Inf
        delays = [0.0 for _ in 1:nb_vertices, _ in 1:m]
        slack_matrix = sparse(I, J, slacks)
        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)
        @test c_star == 0.0
    end

    @testset "No slack" begin
        slacks = [0.0 for _ in 1:nb_edges]
        slacks[end] = Inf
        delays = [1.0 for _ in 1:nb_vertices, _ in 1:m]
        slack_matrix = sparse(I, J, slacks)
        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)
        @test c_star == 45
    end

    @testset "With slack" begin
        slacks = [1.0 for _ in 1:nb_edges]
        slacks[end] = Inf
        delays = [1.0 for _ in 1:nb_vertices, _ in 1:m]
        slack_matrix = sparse(I, J, slacks)
        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)
        @test c_star == 9
    end
end

@testset "Custom graph" begin
    m = 1

    nb_vertices = 5
    graph = SimpleDiGraph(nb_vertices)
    edge_list = [(1, 2), (1, 3), (2, 3), (2, 4), (3, 4), (4, 5)]
    for (i, j) in edge_list
        add_edge!(graph, i, j)
    end

    nb_edges = ne(graph)
    I = [src(e) for e in edges(graph)]
    J = [dst(e) for e in edges(graph)]
    λ = ones(nb_vertices)
    λ[1] = 0
    λ[end] = 0

    @testset "No delays" begin
        delays = reshape([0, 0, 0, 0, 0], nb_vertices, 1)
        slacks_theory = [0.0 for _ in 1:nb_edges]
        slacks_theory[end] = Inf
        slacks = [s + delays[v] for ((u, v), s) in zip(edge_list, slacks_theory)]
        slack_matrix = sparse(I, J, slacks)

        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)
        @test c_star == 0.0
        @test p_star == [1, 2, 4, 5]
        @test path_cost(p_star, slack_matrix, delays) == c_star

        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays, λ)
        @test c_star == -3
        @test p_star == [1, 2, 3, 4, 5]
    end

    @testset "No slack" begin
        delays = reshape([0, 2, 1, 0, 0], nb_vertices, 1)
        slacks_theory = [0.0 for _ in 1:nb_edges]
        slacks_theory[end] = Inf
        slacks = [s + delays[v] for ((u, v), s) in zip(edge_list, slacks_theory)]
        slack_matrix = sparse(I, J, slacks)

        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)
        @test c_star == 2
        @test p_star == [1, 3, 4, 5]
        @test path_cost(p_star, slack_matrix, delays) == c_star

        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays, λ)
        @test c_star == 0
        @test p_star == [1, 3, 4, 5]
    end

    @testset "With slack" begin
        delays = reshape([0, 3, 4, 0, 0], nb_vertices, 1)
        slacks_theory = [0, 0, 0, 0, 3, Inf]
        slacks = [s + delays[v] for ((u, v), s) in zip(edge_list, slacks_theory)]
        slack_matrix = sparse(I, J, slacks)
        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)
        @test c_star == 5
        @test p_star == [1, 3, 4, 5]
        @test path_cost(p_star, slack_matrix, delays) == c_star
    end

    @testset "Detour with slack" begin
        delays = reshape([10, 1, 0, 0, 0], nb_vertices, 1)
        slacks_theory = [5, 0, 5, 0, 0, Inf]
        slacks = [s + delays[v] for ((u, v), s) in zip(edge_list, slacks_theory)]
        slack_matrix = sparse(I, J, slacks)
        (; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)
        @test c_star == 5
        @test p_star == [1, 2, 3, 4, 5]
        @test path_cost(p_star, slack_matrix, delays) == c_star
    end
end

@testset "Random graphs one scenario" begin
    n = 5
    nb_vertices = 10
    m = 1
    for nb_vertices in 10:50
        for i in 1:n
            Random.seed!(i)
            graph = random_acyclic_digraph(nb_vertices; all_connected_to_source_and_destination=true)

            nb_edges = ne(graph)
            I = [src(e) for e in edges(graph)]
            J = [dst(e) for e in edges(graph)]

            delays = reshape([rand() * 10 for _ in 1:nb_vertices], nb_vertices, 1)
            delays[end] = 0
            slacks_theory = [e.dst == nb_vertices ? Inf : rand() * 10 for e in edges(graph)]
            slacks = [s + delays[e.dst] for (e, s) in zip(edges(graph), slacks_theory)]
            slack_matrix = sparse(I, J, slacks)
            #(; c_star, p_star) = stochastic_routing_shortest_path(graph, slack_matrix, delays)

            obj, sol = solve_scenario(graph, slack_matrix, delays)

            initial_paths = [[1, v, nb_vertices] for v in 2:nb_vertices-1]
            # push!(initial_paths, [1, 2, 3, 10])
            # push!(initial_paths, [1, 4, 5, 10])
            # push!(initial_paths, [1, 6, 8, 10])
            # push!(initial_paths, [1, 7, 9, 10])

            value, obj2, paths, dual, dual_new = stochastic_PLNE(graph, slack_matrix, delays, initial_paths)

            # @info "cost" path_cost([1, 7, 9, 10], slack_matrix, delays) - sum(value[v] for v in [1, 7, 9, 10])
            # @info "cost" path_cost([1, 2, 3, 10], slack_matrix, delays) - sum(value[v] for v in [1, 2, 3, 10])
            # @info "cost" path_cost([1, 4, 5, 10], slack_matrix, delays) - sum(value[v] for v in [1, 4, 5, 10])
            # @info "cost" path_cost([1, 6, 8, 10], slack_matrix, delays) - sum(value[v] for v in [1, 6, 8, 10])

            # @info "Exact solution" obj sol sum(path_cost(p, slack_matrix, delays) for p in sol)
            # @info "Column generation (inferior bound)" obj2 paths value
            # @info "" [dual[p] for p in initial_paths] dual_new

            # a, b = column_generation(graph, slack_matrix, delays, cat(initial_paths, paths, dims=1), bin=false)
            # @info "" a

            # a, b = column_generation(graph, slack_matrix, delays, sol, bin=true)
            # @info "" a

            #@info "$nb_vertices $i" obj obj2 obj-obj2

            @test obj ≈ obj2

            #@test_broken c_star == c
            #@test_broken p_star == p
        end
    end
end