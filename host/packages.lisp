(in-package :cl-bodge.asdf)


(defpackage :cl-bodge.host
  (:nicknames :ge.host)
  (:use :cl-bodge.engine :cl-bodge.utils :cl-bodge.event
        :cl :bordeaux-threads :cl-muth :trivial-main-thread)
  (:export host-system
           host

           bind-rendering-context
           swap-buffers
           viewport-title
           viewport-size
           cursor-position
           mouse-button-state
           fullscreen-viewport-p
           lock-cursor
           unlock-cursor

           state-from
           keyboard-event
           key-from
           character-input-event
           character-from
           mouse-event
           button-from
           cursor-event
           x-from
           y-from
           scroll-event
           x-offset-from
           y-offset-from
           viewport-size-change-event
           width-from
           height-from
           viewport-hiding-event))
