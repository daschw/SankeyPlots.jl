module SankeyPlots

using LayeredLayouts
using LightGraphs
using Plots
using RecipesBase
using SimpleWeightedGraphs
using SparseArrays

export sankey, sankey!

"""
    sankey(src, dst, weights; kwargs..., plotattributes...)
    sankey(g::SimpleWeightedDiGraph; kwargs..., plotattributes...)

Plot a sankey diagram.

In addition to [Plots.jl attributes](http://docs.juliaplots.org/latest/attributes/) the following keyword arguments are supported.

| Keyword argument | Default value | Options |
|---|---|----|
| `node_labels` | `nothing` | `AbstractVector{<:String}` |
| `node_colors` | `nothing` | Vector of [color specifications supported by Plots.jl](http://docs.juliaplots.org/latest/colors/) or [color palette](http://docs.juliaplots.org/latest/generated/colorschemes/#ColorPalette) |
| `edge_color` | `:gray` | Plots.jl supported [color](http://docs.juliaplots.org/latest/colors/) or color selection from connected nodes with `:src`, `:dst` or `:gradient` |
| `label_position` | `:inside` | `:legend`, `:node`, `:left`, `:right`, `:top` or `:bottom` |
| `label_size` | `8` | `Int` |
| `compact` | `false` | `Bool` |
"""
@userplot Sankey


@recipe function sankey(
    s::Sankey;
    node_labels=nothing,
    node_colors=nothing,
    edge_color=:gray,
    label_position=:inside,
    label_size=8,
    compact=false,
)
    g = sankey_graph(s.args...)
    names = sankey_names(g, node_labels)
    if node_colors === nothing
        node_colors = palette(get(plotattributes, :color_palette, :default))
    end

    x, y, mask = sankey_layout!(g)
    perm = sortperm(y, rev=true)

    vw = vertex_weight.(Ref(g), vertices(g))
    m = maximum(vw)

    if compact == true
        y = make_compact(x, y, vw / m)
    end

    src_offsets = get_src_offsets(g, perm) ./ m
    dst_offsets = get_dst_offsets(g, perm) ./ m

    if label_position ∉ (:inside, :left, :right, :top, :bottom, :node, :legend)
        error("label_position :$label_position not supported")
    elseif label_position !== :legend
        xlabs = Float64[]
        ylabs = Float64[]
        lab_orientations = Symbol[]
    end

    for (i, v) in enumerate(vertices(g))
        h = vw[i] / (2m)

        if !(mask[i])
            @series begin
                seriestype := :shape
                label := label_position === :legend ? names[i] : ""
                fillcolor --> node_colors[mod1(i, end)]
                [x[i]-0.1, x[i]+0.1, x[i]+0.1, x[i]-0.1], [y[i]-h, y[i]-h, y[i]+h, y[i]+h]
            end

            for (j, w) in enumerate(vertices(g))
                if has_edge(g, v, w)
                    y_src = y[i] + h - src_offsets[i, j]
                    h_edge = g.weights[j, i] / (2m)


                    sankey_y = Float64[]
                    x_start = x[i] + 0.1
                    k = j
                    l = i
                    while mask[k]
                        y_dst = y[k] + vw[k] / (2m) - dst_offsets[k, l]
                        x_coords = range(0, 1, length=length(x_start:0.01:x[k]))
                        y_coords =
                            remap(1 ./ (1 .+ exp.(6 .* (1 .- 2 .* x_coords))), y_src, y_dst)

                        append!(sankey_y, y_coords)

                        x_start = x[k] + 0.01
                        y_src = y_dst
                        l = k
                        k = findfirst(==(first(outneighbors(g, k))), vertices(g))
                    end

                    y_dst = y[k] + vw[k] / (2m) - dst_offsets[k, l]
                    x_coords = range(0, 1, length=length(x_start:0.01:x[k]-0.1))
                    y_coords = remap(1 ./ (1 .+ exp.(6 .* (1 .- 2 .* x_coords))), y_src, y_dst)
                    append!(sankey_y, y_coords)
                    sankey_x = range(x[i]+0.1, x[k]-0.1, step=0.01)

                    @series begin
                        seriestype := :path
                        primary := false
                        linecolor := nothing
                        linewidth := false
                        fillrange := sankey_y .- 2h_edge
                        fillalpha --> 0.5
                        if edge_color === :gradient
                            fillcolor := getindex(
                                cgrad(node_colors[[i, k]]),
                                range(0, 1, length=length(sankey_x)),
                            )
                        elseif edge_color === :src
                            fillcolor := node_colors[i]
                        elseif edge_color === :dst
                            fillcolor := node_colors[k]
                        else
                            fillcolor := edge_color
                        end
                        sankey_x, sankey_y
                    end
                end
            end

            if label_position !== :legend
                xlab, orientation = if label_position in (:node, :top, :bottom)
                    olab = if label_position === :top
                        :bottom
                    elseif label_position === :bottom
                        :top
                    else
                        :center
                    end
                    x[i], olab
                elseif label_position === :right ||
                        (label_position === :inside && x[i] < maximum(x))
                    x[i] + 0.15, :left
                elseif label_position === :left ||
                        (label_position === :inside && x[i] == maximum(x))
                    x[i] - 0.15, :right
                else
                    error("label_position :$label_position not supported")
                end
                ylab = if label_position === :top
                    y[i] + h + 0.02
                elseif label_position === :bottom
                    y[i] - h - 0.0025 * label_size
                else
                    y[i]
                end
                push!(xlabs, xlab)
                push!(ylabs, ylab)
                push!(lab_orientations, orientation)
            end
        end
    end

    if label_position !== :legend
        @series begin
            primary := :false
            seriestype := :scatter
            markeralpha := 0
            series_annotations := text.(names, lab_orientations, label_size)
            xlabs, ylabs
        end

        # extend axes for labels
        if label_position in (:left, :right)
            x_extra = label_position === :left ? minimum(xlabs) - 0.4 : maximum(xlabs) + 0.5
            @series begin
                primary := false
                seriestype := :scatter
                markeralfa := 0
                [x_extra], [ylabs[1]]
            end
        end
    end

    primary := false
    framestyle --> :none
    legend --> label_position === :legend ? :outertopright : false
    ()
end

sankey_graph(src, dst, w) = SimpleWeightedDiGraph(src, dst, w)
sankey_graph(g::SimpleWeightedDiGraph) = copy(g)
sankey_graph(args...) = error("Check `?sankey` for supported signatures.")

sankey_names(g, names) = names
sankey_names(g, ::Nothing) = string.("Node", eachindex(vertices(g)))

function sankey_layout!(g)
    xs, ys, paths = solve_positions(Zarate(), g)
    mask = falses(length(xs))
    for (edge, path) in paths
        s = edge.src
        px, py = path
        if length(px) > 2
            for i in 2:length(px)-1
                add_vertex!(g)
                v = last(vertices(g))
                add_edge!(g, s, v, edge.weight)
                push!(xs, px[i])
                push!(ys, py[i])
                push!(mask, true)
                s = v
            end
            add_edge!(g, s, edge.dst, edge.weight)
            rem_edge!(g, edge)
        end
    end
    return xs, ys, mask
end

function vertex_weight(g, v)
    max(
        sum0(weight, Iterators.filter(e -> src(e) == v, edges(g))),
        sum0(weight, Iterators.filter(e -> dst(e) == v, edges(g))),
    )
end
sum0(f, x) = isempty(x) ? 0.0 : sum(f, x)

in_edges(g, v) = Iterators.filter(e -> dst(e) == v, edges(g))
out_edges(g, v) = Iterators.filter(e -> src(e) == v, edges(g))

function get_src_offsets(g, perm)
    verts = vertices(g)
    n = nv(g)
    p = spzeros(n, n)
    for (i, v) in enumerate(verts)
        offset = 0.0
        for j in perm
            if has_edge(g, v, verts[j])
                if offset > 0
                    p[i, j] = offset
                end
                offset += g.weights[j, i]
            end
        end
    end
    return p
end

function get_dst_offsets(g, perm)
    verts = vertices(g)
    n = nv(g)
    p = spzeros(n, n)
    for (i, v) in enumerate(verts)
        offset = 0.0
        for j in perm
            if has_edge(g, verts[j], i)
                if offset > 0
                    p[i, j] = offset
                end
                offset += g.weights[i, j]
            end
        end
    end
    return p
end

function remap(x, lo, hi)
    xlo, xhi = extrema(x)
    lo .+ (x .- xlo) / (xhi - xlo) * (hi - lo)
end

function make_compact(x, y, w)
    x = round.(Int, x)
    ux = unique(x)
    heights = zeros(length(ux))
    uinds = [findall(==(uxi), x) for uxi in ux]
    for (i, inds) in enumerate(uinds)
        perm = sortperm(view(y, inds))
        start = 0
        for j in inds[perm]
            y[j] = start + w[j] / 2
            start += 0.1 + w[j]
        end
        heights[i] = start - 0.1
    end
    maxh = maximum(heights)
    for (i, inds) in enumerate(uinds)
        y[inds] .+= (maxh - heights[i]) / 2
    end
    return y
end

end
