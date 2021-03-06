(in-package :cl-bodge.asdf)


(ge.util:define-package :cl-bodge.memory
  (:nicknames :ge.mem)
  (:use :cl :cl-bodge.utils :trivial-garbage :static-vectors)
  (:export define-destructor
           dispose
           disposable
           disposable-container
           with-disposable

           make-foreign-array
           simple-array-of
           foreign-pointer-of))


(defpackage :cl-bodge.concurrency
  (:nicknames :ge.mt)
  (:use :cl-bodge.utils :cl-bodge.memory
        :cl :bordeaux-threads :cl-muth :cl-flow)
  (:export make-task-queue
           push-task
           push-body-into
           drain
           clearup

           execute
           make-single-threaded-executor
           make-pooled-executor

           in-new-thread
           in-new-thread-waiting

           ->
           >>
           *>
           ~>
           ->>
           dispatch
           define-flow

           lockable
           with-instance-lock-held))


(defpackage :cl-bodge.math
  (:nicknames :ge.math)
  (:use :cl :cl-bodge.utils)
  (:export lerp
           nlerp
           mult
           add
           div
           subt
           cross
           dot
           normalize
           inverse

           transform-of

           vec
           vec2
           vec3
           vec4
           vec->array
           sequence->vec2
           sequence->vec3
           sequence->vec4
           vref
           make-vec3
           make-vec4
           x
           y
           z
           w
           vector-length

           mat
           square-mat
           mat2
           mat3
           mat4
           square-matrix-size
           mref
           mat->array
           make-mat3
           identity-mat3
           identity-mat4
           sequence->mat4
           sequence->rotation-mat4
           mat->rotation-mat4
           euler-axis->mat4
           angle->mat2
           euler-angles->mat4
           euler-angles->mat3
           rotation-translation->mat4
           translation-mat4
           sequence->translation-mat4
           vec->translation-mat4
           scaling-mat4
           vec->scaling-mat4
           mat4->mat3
           mat3->mat4
           basis->mat4
           perspective-projection-mat
           orthographic-projection-mat

           quat
           identity-quat
           sequence->quat
           euler-axis->quat
           euler-angles->quat
           quat->rotation-mat3
           quat->rotation-mat4
           rotate))


(defpackage :cl-bodge.engine.resources
  (:nicknames :ge.ng.rsc)
  (:use :cl :cl-bodge.utils)
  (:export pixel-format
           pixel-format-p

           pixel-format-of
           foreign-array-of
           width-of
           height-of

           pcm-data
           sample-depth
           channel-format

           pcm-audio-data-of
           audio-channel-format-of
           audio-sample-depth-of
           audio-sampling-rate-of))


(ge.util:define-package :cl-bodge.engine
  (:nicknames :ge.ng)
  (:use :cl-bodge.utils :cl :bordeaux-threads :cl-muth)
  (:use-reexport :cl-bodge.concurrency :cl-bodge.memory :cl-bodge.math
                 :cl-bodge.engine.resources)
  (:export system
           enable
           disable
           enabledp
           notify-system
           acquire-executor
           release-executor
           working-directory
           merge-working-pathname

           dispatcher
           instantly
           concurrently
           value-flow
           null-flow
           assembly-flow
           initialization-flow
           run

           system-object
           system-of
           enableable

           handle-value-of
           defhandle
           *handle-value*

           foreign-object
           system-foreign-object

           generic-system
           with-system-lock-held
           initialize-system
           discard-system

           thread-bound-system
           make-system-context
           destroy-system-context
           *system-context*
           *system*
           define-system-function
           acquire-system-executor
           release-system-executor

           *engine-startup-hooks*
           after-system-startup
           before-system-shutdown
           engine-system
           engine
           property
           startup
           shutdown))
