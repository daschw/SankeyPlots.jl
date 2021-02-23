using Plots
using SankeyPlots
using ReferenceTests
using Test

names = [
    "PV",
    "Electricity Buy",
    "Battery",
    "Heat pump",
    "Biomass",
    "Electricity Sell",
    "Electricity Demand",
    "Heat demand",
]
src = [1, 1, 1, 1, 2, 2, 2, 3, 4, 5]
dst = [6, 3, 7, 4, 3, 7, 4, 7, 8, 8]
weights = [0.1, 0.3, 0.5, 0.5, 0.2, 2.8, 1, 0.45, 4.5, 3.3]
# labels = ["", "", "0.5", "0.5", "", "2.8", "1", "", "4.5", "3.3"]
energy_colors = palette(:seaborn_colorblind)[[9, 10, 3, 5, 2, 8, 1, 4]]

@testset "SankeyPlots.jl" begin
    @test_reference "refs/energy_gray.png" sankey(src, dst, weights)
    @test_reference "refs/energy_kwargs.png" sankey(
        src, dst, weights;
        node_labels=names,
        node_colors=energy_colors,
        edge_color="#789",
        legend=:outerright,
        fillalpha=1,
    )
    @test_reference "refs/energy_src.png" sankey(
        src, dst, weights;
        node_labels=names,
        node_colors=energy_colors,
        edge_color=:src,
        legend=:outerright,
    )
    @test_reference "refs/energy_dst.png" sankey(
        src, dst, weights;
        node_labels=names,
        node_colors=energy_colors,
        edge_color=:dst,
        legend=:outerright,
    )
    @test_reference "refs/energy_grad.png" sankey(
        src, dst, weights;
        node_labels=names,
        node_colors=energy_colors,
        edge_color=:gradient,
        legend=:outerright,
    )
end
