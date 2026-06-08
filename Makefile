# LilCleo - common tasks. Run `make help` for the list.

BLENDER ?= /Applications/Blender.app/Contents/MacOS/Blender
SHELL   := /bin/zsh
B       := tools/blender

.PHONY: help build run app dmg gallery gif brick brick-build brick-walk brick-render brick-contact clean

help:
	@echo "LilCleo tasks:"
	@echo "  make build         - swift build"
	@echo "  make run           - build + launch the app (Brick walks the dock)"
	@echo "  make app           - package a runnable dist/LilCleo.app"
	@echo "  make dmg           - package a drag-install dist/LilCleo.dmg"
	@echo "  make gallery       - render the vector-fallback gallery PNG (no GUI)"
	@echo "  make gif           - render showcase walk/celebrate/... GIFs (no GUI)"
	@echo ""
	@echo "  make brick         - rebuild Brick end-to-end: model+rig -> mocap walk -> sprites"
	@echo "  make brick-build   - (re)build the rig+actions     -> $(B)/brick.blend"
	@echo "  make brick-walk    - retarget the CMU mocap walk    -> brick.blend 'walk' action"
	@echo "  make brick-render  - render every state to sprites  -> Resources/characters/brick/"
	@echo "  make brick-contact - montage every pose for review  -> /tmp/brick_contact.png"
	@echo "  make clean         - remove build artifacts"
	@echo ""
	@echo "Blender: $(BLENDER)"

build:
	swift build

run: build
	pkill -x LilCleo 2>/dev/null; ./.build/debug/LilCleo &

app:
	./tools/package.sh app

dmg:
	./tools/package.sh

gallery: build
	CLEO_RENDER=/tmp/cleo_gallery.png ./.build/debug/LilCleo

gif: build
	mkdir -p /tmp/cleogifs && CLEO_GIF=/tmp/cleogifs ./.build/debug/LilCleo

# --- Brick 3D character pipeline (self-contained, all assets in tools/blender) ---

# Full rebuild: rig + 58 actions, then graft the mocap walk, then render sprites.
brick: brick-build brick-walk brick-render
	@echo "Brick rebuilt -> Sources/LilCleo/Resources/characters/brick/"

brick-build:
	"$(BLENDER)" -b -P $(B)/build_brick.py
	@echo "built $(B)/brick.blend"

# Retarget the bundled CMU walk cycle onto the rig as the looping 'walk' action.
brick-walk:
	"$(BLENDER)" -b $(B)/brick.blend -P $(B)/import_bvh.py -- \
	  --bvh $(B)/mocap/cmu_07_01.bvh --name walk --loop 8 --save

brick-render:
	"$(BLENDER)" -b $(B)/brick.blend -P $(B)/render_states.py -- --id brick
	@echo "sprites in Sources/LilCleo/Resources/characters/brick/"

brick-contact:
	"$(BLENDER)" -b $(B)/brick.blend -P $(B)/contact_sheet.py -- --out /tmp/brick_contact.png
	@echo "montage in /tmp/brick_contact.png"

clean:
	rm -rf .build
