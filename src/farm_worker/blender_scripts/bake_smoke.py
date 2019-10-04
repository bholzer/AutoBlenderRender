import bpy

for scene in bpy.data.scenes:
  for object in scene.objects:
    for modifier in object.modifiers:
      if modifier.type == 'SMOKE':
        if modifier.smoke_type == 'DOMAIN':
          override = {'scene': scene, 'active_object': object, 'point_cache': modifier.domain_settings.point_cache}
          bpy.ops.ptcache.free_bake(override)
          bpy.ops.ptcache.bake(override, bake=True)
          break