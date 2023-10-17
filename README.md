# CSGDeformTest

Test project for a CSG deforming node/tool for Godot 4. Made as a proof of concept for a proposal: https://github.com/godotengine/godot-proposals/issues/8149

The addon under the addons folder implements a node extending from CSGShape3D that modifies its own mesh according to a displacement lattice. There's also an editor plugin for editing this displacement lattice, with a workflow similar to sculpting tools.

Limitations: Collision doesn't get modified (because it's not exposed), also everything is relatively slow because it's implemented in pure gdscript.

MIT license.

The following screenshot contains geometry made entirely within the Godot editor using this node.

![Godot_v4 1 1-stable_win64_2023-10-16_09-09-49](https://github.com/wareya/CSGDeformTest/assets/585488/7ed2179c-e05e-42d6-a193-5c1e6d585dfe)
