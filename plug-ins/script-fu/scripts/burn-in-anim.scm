;
;  burn-in-anim.scm V2.1  -  script-fu for GIMP 1.1 and higher
;
;  Copyright (C) 9/2000  Roland Berger
;  roland@fuchur.leute.server.de
;  http://fuchur.leute.server.de
;
;  Let text appear and fade out with a "burn-in" like SFX.
;  Works on an image with a text and a background layer
;
;  Copying Policy:  GNU Public License http://www.gnu.org
;

(define (script-fu-burn-in-anim org-img
                                org-layers
                                glow-color
                                fadeout
                                bl-width
                                corona-width
                                after-glow
                                show-glow
                                optimize
                                speed)

  (let* (
        ;--- main variable: "bl-x" runs from 0 to layer-width
        (bl-x 0)
        (frame-nr 0)
        (img 0)
        (source-layer 0)
        (bg-source-layer 0)
        (source-layer-width 0)
        (bg-layer 0)
        (bg-layer-name 0)
        (bl-layer 0)
        (bl-layer-name 0)
        (bl-mask 0)
        (bl-layer-width 0)
        (bl-height 0)
        (bl-x-off 0)
        (bl-y-off 0)
        (nofadeout-bl-x-off 0)
        (nofadeout-bl-width 0)
        (blended-layer 0)
        (img-display 0)
        )

    (if (< speed 1)
        (set! speed (* -1 speed)) )

    ;--- check image and work on a copy
    (if (and (= (vector-length (car (gimp-image-get-layers org-img))) 2)
             (= (car (gimp-image-get-floating-sel org-img)) -1))

        ;--- main program structure starts here, begin of "if-1"
        (begin
          (gimp-context-push)
          (gimp-context-set-defaults)

          (set! img (car (gimp-image-duplicate org-img)))
          (gimp-image-undo-disable img)
          (if (> (car (gimp-drawable-type (vector-ref org-layers 0))) 1 )
              (gimp-image-convert-rgb img))
          (set! source-layer    (vector-ref (car (gimp-image-get-layers img)) 0 ))
          (set! bg-source-layer (vector-ref (car (gimp-image-get-layers img)) 1 ))
          (set! source-layer-width (car (gimp-drawable-get-width  source-layer)))

          ;--- hide layers, cause we want to "merge visible layers" later
          (gimp-item-set-visible source-layer FALSE)
          (gimp-item-set-visible bg-source-layer     FALSE)

          ;--- process image horizontal with pixel-speed
          (while (< bl-x (+ source-layer-width bl-width))
              (set! bl-layer (car (gimp-layer-copy source-layer)))
              (set! bl-layer-name (string-append "fr-nr"
                                                 (number->string frame-nr 10) ) )

              (gimp-layer-add-alpha bl-layer)
              (gimp-image-insert-layer img bl-layer 0 -2)
              (gimp-item-set-name bl-layer bl-layer-name)
              (gimp-item-set-visible bl-layer TRUE)
              (gimp-layer-set-lock-alpha bl-layer TRUE)
              (gimp-layer-add-alpha bl-layer)

              ;--- add an alpha mask for blending and select it
              (gimp-image-select-item img CHANNEL-OP-REPLACE bl-layer)
              (set! bl-mask (car (gimp-layer-create-mask bl-layer ADD-MASK-BLACK)))
              (gimp-layer-add-mask bl-layer bl-mask)

              ;--- handle layer geometry
              (set! bl-layer-width source-layer-width)
              (set! bl-height      (car (gimp-drawable-get-height bl-layer)))
              (set! bl-x-off (- bl-x     bl-width))
              (set! bl-x-off (+ bl-x-off (car  (gimp-drawable-get-offsets bl-layer))))
              (set! bl-y-off             (cadr (gimp-drawable-get-offsets bl-layer)))

              ;--- select a rectangular area to blend
              (gimp-image-select-rectangle img CHANNEL-OP-REPLACE bl-x-off bl-y-off bl-width bl-height)
              ;--- select at least 1 pixel!
              (gimp-image-select-rectangle img CHANNEL-OP-ADD bl-x-off bl-y-off (+ bl-width 1) bl-height)

              (if (= fadeout FALSE)
                  (begin
                    (set! nofadeout-bl-x-off (car (gimp-drawable-get-offsets bl-layer)))
                    (set! nofadeout-bl-width (+ nofadeout-bl-x-off bl-x))
                    (set! nofadeout-bl-width (max nofadeout-bl-width 1))
                    (gimp-image-select-rectangle img CHANNEL-OP-REPLACE
                                                 nofadeout-bl-x-off bl-y-off
                                                 nofadeout-bl-width bl-height)
                  )
              )

              ;--- alpha blending text to trans (fadeout)
              (gimp-context-set-foreground '(255 255 255))
              (gimp-context-set-background '(  0   0   0))
              (if (= fadeout TRUE)
                  (begin
                    ; blend with 20% offset to get less transparency in the front
		    (gimp-context-set-gradient-fg-bg-rgb)
                    (gimp-drawable-edit-gradient-fill bl-mask
						      GRADIENT-LINEAR 20
						      FALSE 1 0
						      TRUE
						      (+ bl-x-off bl-width) 0
						      bl-x-off 0)
                  )
              )

              (if (= fadeout FALSE)
                  (begin
                    (gimp-context-set-foreground '(255 255 255))
                    (gimp-drawable-edit-fill bl-mask FILL-FOREGROUND)
                  )
              )

              (gimp-layer-remove-mask bl-layer MASK-APPLY)

              ;--- add bright glow in front
              (if (= show-glow TRUE)
                  (begin
                    ;--- add some brightness to whole text
                    (if (= fadeout TRUE)
                        (gimp-drawable-brightness-contrast bl-layer 0.787 0)
                    )

		    ;--- blend glow color inside the letters
		    (gimp-context-set-foreground glow-color)
		    (gimp-context-set-gradient-fg-transparent)
		    (gimp-drawable-edit-gradient-fill bl-layer
						      GRADIENT-LINEAR 0
						      FALSE 1 0
						      TRUE
						      (+ bl-x-off bl-width) 0
						      (- (+ bl-x-off bl-width) after-glow) 0)

                    ;--- add corona effect
		    (gimp-image-select-item img CHANNEL-OP-REPLACE bl-layer)
		    (gimp-selection-sharpen img)
		    (gimp-selection-grow img corona-width)
		    (gimp-layer-set-lock-alpha bl-layer FALSE)
		    (gimp-selection-feather img corona-width)
		    (gimp-context-set-foreground glow-color)
		    (gimp-drawable-edit-gradient-fill bl-layer
						      GRADIENT-LINEAR 0
						      FALSE 1 0
						      TRUE
						      (- (+ bl-x-off bl-width) corona-width) 0
						      (- (+ bl-x-off bl-width) after-glow) 0)
		    )
		  )

              ;--- merge with bg layer
              (set! bg-layer (car (gimp-layer-copy bg-source-layer)))
              (gimp-image-insert-layer img bg-layer 0 -1)
              (gimp-image-lower-item img bg-layer)
              (set! bg-layer-name (string-append "bg-"
                                                 (number->string frame-nr 10)))
              (gimp-item-set-name bg-layer bg-layer-name)
              (gimp-item-set-visible bg-layer TRUE)
              (set! blended-layer (car (gimp-image-merge-visible-layers img
                                        CLIP-TO-IMAGE)))
              ;(set! blended-layer bl-layer)
              (gimp-item-set-visible blended-layer FALSE)

              ;--- end of "while" loop
              (set! frame-nr (+ frame-nr 1))
              (set! bl-x     (+ bl-x speed))
          )

          ;--- finalize the job
          (gimp-selection-none img)
          (gimp-image-remove-layer img    source-layer)
          (gimp-image-remove-layer img bg-source-layer)

          (gimp-image-set-file img "burn-in.xcf")

          (if (= optimize TRUE)
              (begin
                (gimp-image-convert-indexed img CONVERT-DITHER-FS CONVERT-PALETTE-WEB 250 FALSE TRUE "")
                (set! img (car (plug-in-animationoptimize #:run-mode  RUN-NONINTERACTIVE
                                                          #:image     img
                                                          #:drawables (vector blended-layer))))
              )
          )

          (gimp-item-set-visible (vector-ref (car (gimp-image-get-layers img)) 0)
                                  TRUE)
          (gimp-image-undo-enable img)
          (gimp-image-clean-all img)
          (set! img-display (car (gimp-display-new img)))

          (gimp-displays-flush)

          (gimp-context-pop)
        )

        ;--- false form of "if-1"
        (gimp-message _"The Burn-In script needs two layers in total. A foreground layer with transparency and a background layer.")
    )
  )
)


(script-fu-register-filter "script-fu-burn-in-anim"
    _"B_urn-In..."
    _"Create intermediate layers to produce an animated 'burn-in' transition between two layers"
    "Roland Berger roland@fuchur.leute.server.de"
    "Roland Berger"
    "January 2001"
    "RGBA GRAYA INDEXEDA"
    SF-ONE-OR-MORE-DRAWABLE
    SF-COLOR        _"Glow color"           "white"
    SF-TOGGLE       _"Fadeout"              FALSE
    SF-ADJUSTMENT   _"Fadeout width"        '(100 1 3000 1 10 0 SF-SPINNER)
    SF-ADJUSTMENT   _"Corona width"         '(7 1 2342 1 10 0 SF-SPINNER)
    SF-ADJUSTMENT   _"After glow"           '(50 1 1024 1 10 0 SF-SPINNER)
    SF-TOGGLE       _"Add glowing"          TRUE
    SF-TOGGLE       _"Prepare for GIF"      FALSE
    SF-ADJUSTMENT   _"Speed (pixels/frame)" '(50 1 1024 1 10 0 SF-SPINNER)
)

(script-fu-menu-register "script-fu-burn-in-anim"
                         "<Image>/Filters/Animation/")
