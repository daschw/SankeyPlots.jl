
# Most of this function is copied from `solve_positions` in LayeredLayouts.jl.
# However, we need the dummy nodes too for sankey plots
function sankey_layout(original_graph)
    layout = LayeredLayouts.Zarate()
    graph = copy(original_graph)

    # 1. Layer Assigment
    layer2nodes = LayeredLayouts.layer_by_longest_path_to_source(graph)
    is_dummy_mask = LayeredLayouts.add_dummy_nodes!(graph, layer2nodes)

    # 2. Layer Ordering
    start_time = LayeredLayouts.Dates.now()
    min_total_distance = Inf
    min_num_crossing = Inf
    local best_pos
    ordering_model, is_before = LayeredLayouts.ordering_problem(layout, graph, layer2nodes)
    for round in 1:typemax(Int)
        round > 1 && LayeredLayouts.forbid_solution!(ordering_model, is_before)

        LayeredLayouts.optimize!(ordering_model)
        # No need to keep banning solutions if not finding optimal ones anymore
        round > 1 && LayeredLayouts.termination_status(ordering_model) != MOI.OPTIMAL && break
        num_crossings = LayeredLayouts.objective_value(ordering_model)
        # we are not interested in arrangements that have more crossings, only in
        # alternatives with same number of crossings.
        num_crossings > min_num_crossing && break
        min_num_crossing = num_crossings
        LayeredLayouts.order_layers!(layer2nodes, is_before)

        # 3. Node Arrangement
        xs, ys, total_distance = LayeredLayouts.assign_coordinates(layout, graph, layer2nodes)
        if total_distance < min_total_distance
            min_total_distance = total_distance
            best_pos = (xs, ys)
        end
        LayeredLayouts.Dates.now() - start_time > layout.time_limit && break
    end
    xs, ys = best_pos
    return graph, xs, ys, is_dummy_mask
end
