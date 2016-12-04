(in-package :cl-bodge.assets)


(define-shader-library lighting-library
    :name "lighting"
    :header "lighting.h"
    :source "lighting.glsl"
    :uniforms ("dLight.ambient"
               "dLight.diffuse"
               "dLight.direction"))
