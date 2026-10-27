"""Opens a frog's .blend for looking at, bare: every clothing option hidden, the body in solid
shading with its colours, the view framed on it. Run (with Blender's window, not --background):
    blender tools/frog_round.blend --python tools/inspect_frog.py
"""
import bpy

for obj in bpy.data.objects:
    if "__" in obj.name:
        obj.hide_set(True)
        obj.hide_render = True
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        for space in area.spaces:
            if space.type == "VIEW_3D":
                space.shading.type = "SOLID"
                space.shading.color_type = "MATERIAL"
                space.shading.show_cavity = True
                space.overlay.show_bones = False
        with bpy.context.temp_override(area=area, region=area.regions[-1]):
            bpy.ops.view3d.view_all(center=False)
