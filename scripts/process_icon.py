import os
from PIL import Image

def main():
    img_path = "/home/rsbrandao/.gemini/antigravity-ide/brain/37a5381e-343a-4186-973a-89d54a5db9b0/liahona_logo_1782567819585.png"
    if not os.path.exists(img_path):
        print(f"Error: image not found at {img_path}")
        return

    img = Image.open(img_path)
    width, height = img.size
    print(f"Original size: {width}x{height}")

    # Let's crop the white borders.
    # The blue rounded square is centered.
    # Let's detect the bounding box of non-white colors.
    # White is typically (255, 255, 255) or close to it.
    bg = Image.new(img.mode, img.size, (255, 255, 255))
    diff = Image.new("L", img.size, 0)
    for x in range(width):
        for y in range(height):
            pixel = img.getpixel((x, y))
            # If pixel is not white (e.g. red, green, or blue is less than 240)
            if pixel[0] < 240 or pixel[1] < 240 or pixel[2] < 240:
                diff.putpixel((x, y), 255)
    
    bbox = diff.getbbox()
    if bbox:
        print(f"Detected bounding box: {bbox}")
        # Crop to the bounding box
        cropped_img = img.crop(bbox)
    else:
        print("Could not detect bounding box, using original image.")
        cropped_img = img

    # Ensure it's square
    w, h = cropped_img.size
    size = min(w, h)
    left = (w - size) // 2
    top = (h - size) // 2
    cropped_img = cropped_img.crop((left, top, left + size, top + size))

    target_dir = "/home/rsbrandao/quiz_sud/web"
    icons_dir = os.path.join(target_dir, "icons")
    os.makedirs(icons_dir, exist_ok=True)

    # Save outputs
    sizes = {
        "favicon.png": (32, 32),
        "icons/Icon-192.png": (192, 192),
        "icons/Icon-512.png": (512, 512),
        "icons/Icon-maskable-192.png": (192, 192),
        "icons/Icon-maskable-512.png": (512, 512),
    }

    for name, sz in sizes.items():
        out_path = os.path.join(target_dir, name)
        resized = cropped_img.resize(sz, Image.Resampling.LANCZOS)
        resized.save(out_path)
        print(f"Saved {out_path} ({sz[0]}x{sz[1]})")

if __name__ == "__main__":
    main()
