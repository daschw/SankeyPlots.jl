module SankeyPlots

using LayeredLayouts
using LightGraphs
using PlotUtils
using RecipesBase
using SimpleWeightedGraphs
using SparseArrays

include("sankey_layout.jl")

export sankey, sankey!

"""
    sankey(src, dst, weights; kwargs..., plotattributes...)
    sankey(g::SimpleWeightedDiGraph; kwargs..., plotattributes...)

Plot a sankey diagram.
Supported keyword arguments are:
- `node_labels`: A vector of labels for each node
- `node_colors`: A vector of colors or a color palette
- `edge_color`: `:src`, `:dst`, `:gradient` or a color
"""
@userplot Sankey


@recipe function sankey(
    s::Sankey;
    node_labels=nothing,
    node_colors=nothing,
    edge_color=:gray,
)
    g = sankey_graph(s.args...)
    names = sankey_names(g, node_labels)
    if node_colors === nothing
        node_colors = palette(get(plotattributes, :color_palette, :default))
    end
    
    g, x, y, mask = sankey_layout(g)
    perm = sortperm(y, rev=true)
    
    vw = vertex_weight.(Ref(g), vertices(g))
    m = maximum(vw)
    
    src_offsets = get_src_offsets(g, perm) ./ m
    dst_offsets = get_dst_offsets(g, perm) ./ m
    
    for (i, v) in enumerate(vertices(g))
        h = vw[i] / (2m)
        
        if !(mask[i])
            @series begin
                seriestype := :shape
                label := names[i]
                fillcolor := node_colors[mod1(i, end)]
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
        end
    end

    primary := false
    framestyle --> :none
    legend --> :outertopright
    ()
end

sankey_graph(src, dst, w) = SimpleWeightedDiGraph(src, dst, w)
sankey_graph(g::SimpleWeightedDiGraph) = g
sankey_graph(args...) = error("Check `?sankey` for supported signatures.")

sankey_names(g, names) = names
sankey_names(g, ::Nothing) = string.("Node", eachindex(vertices(g)))

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

end
