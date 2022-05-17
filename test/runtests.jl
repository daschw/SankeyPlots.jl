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
    "Heat Demand",
]
src = [1, 1, 1, 1, 2, 2, 2, 3, 4, 5]
dst = [6, 3, 7, 4, 3, 7, 4, 7, 8, 8]
weights = [0.1, 0.3, 0.5, 0.5, 0.2, 2.8, 1, 0.45, 4.5, 3.3]
# labels = ["", "", "0.5", "0.5", "", "2.8", "1", "", "4.5", "3.3"]
energy_colors = palette(:seaborn_colorblind)[[9, 10, 3, 5, 2, 8, 1, 4]]


@testset "SankeyPlots.jl" begin
    @testset "readme" begin
        @test_reference "refs/readme.png" sankey(src, dst, weights; force_order=[5=>1])
        @test_reference "refs/readme_kwargs.png" sankey(
            src, dst, weights;
            node_labels=names,
            node_colors=energy_colors,
            edge_color=:gradient,
            label_position=:bottom,
            label_size=7,
            compact=true,
            force_layer=[6=>3],
            force_order=[5=>1]
        )
    end

    @testset "edge_color" begin
        for c in (:src, :dst, "#789")
            @test_reference "refs/edge_color_$c.png" sankey(src, dst, weights; edge_color=c, force_order=[5=>1])
        end
        c = Dict(
            (1, 6)=>"#945",
            (1, 3)=>"#575",
            (1, 7)=>"#a85",
            (1, 4)=>"#479",
            (2, 3)=>"#758",
            (2, 7)=>"#388",
            (2, 4)=>"#855",
            (3, 7)=>"#673",
            (4, 8)=>"#555",
            (5, 8)=>"#aaa",
        )
        @test_reference "refs/edge_color_manual.png" sankey(src, dst, weights; edge_color=c)
    end

    @testset "label_position" begin
        for p in (:node, :legend, :top, :bottom, :left, :right)
            @test_reference "refs/label_position_$p.png" sankey(
                src, dst, weights; label_position=p, force_order=[5=>1]
            )
        end
    end

    @testset "force_layer" begin
        @test_reference "refs/force_layer.png" sankey(
            src, dst, weights; force_layer=[6=>3], force_order=[5=>1]  # move node 6 to layer 3
        )
    end

    @testset "force_order" begin
        @test_reference "refs/force_order.png" sankey(
            src, dst, weights; force_order=[1=>5]  # node 1 shall come before node 5
        )
    end
end
