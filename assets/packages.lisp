(in-package :cl-bodge.asdf)


(defpackage :cl-bodge.assets
  (:nicknames :ge.as)
  (:use :cl :cl-bodge.utils :cl-bodge.engine)
  (:export asset-system
           asset-registry-of
           assets
           copy-assets

           engine-asset-id

           register-asset-loader
           release-assets
           get-asset

           asset-names
           load-asset
           release-asset
           path-to

           assets-root

           pixel-format
           pixel-format-p

           pixel-format-of
           image->array
           size-of

           pcm-data
           sample-depth
           channel-format

           pcm-audio-data-of
           audio-channel-format-of
           audio-sample-depth-of
           audio-sampling-rate-of))
